import Combine
import Foundation

enum StoryLoadState: Equatable {
    case idle
    case loading
    case loaded(StoryDocument)
    case failed(String)
}

extension StoryLoadState {
    static func == (lhs: StoryLoadState, rhs: StoryLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case let (.loaded(lhsDocument), .loaded(rhsDocument)):
            return lhsDocument.id == rhsDocument.id
        case let (.failed(lhsMessage), .failed(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

@MainActor
final class StoryDocumentStore: ObservableObject {
    @Published private(set) var state: StoryLoadState = .idle
    @Published private(set) var diagnostics: [ValidationDiagnostic] = []
    private(set) var persistedStoryURL: URL?
    @Published private(set) var hasPersistedStory = false
    @Published private(set) var isPersistedStoryActive = false

    private let loader: StoryPackageLoading
    private let parser: StoryParser
    private let remoteLoader: RemoteStoryPackageLoading
    private let persistedStoryStore: PersistedRemoteStoryStoring
    private var hasLoadedSample = false
    private var activeSecurityScopedURL: URL?
    private var hasSecurityScopedAccess = false

    init(
        loader: StoryPackageLoading = StoryPackageLoader(),
        parser: StoryParser = StoryParser(),
        remoteLoader: RemoteStoryPackageLoading = RemoteStoryPackageLoader(),
        persistedStoryStore: PersistedRemoteStoryStoring = FilePersistedRemoteStoryStore(),
    ) {
        self.loader = loader
        self.parser = parser
        self.remoteLoader = remoteLoader
        self.persistedStoryStore = persistedStoryStore
    }

    @MainActor
    deinit {
        clearSecurityScopedAccess()
    }

    func loadStory(from url: URL) {
        state = .loading
        isPersistedStoryActive = false
        startSecurityScopedAccess(for: url)
        do {
            let package = try loader.loadStory(at: url)
            let parsed = parser.parse(package: package)
            diagnostics = parsed.diagnostics
            if let document = parsed.document {
                state = .loaded(document)
                isPersistedStoryActive = false
            } else {
                handleLoadError("Story parsing failed.")
            }
        } catch {
            handleLoadError(error.localizedDescription)
        }
    }

    func loadRemoteStory(from url: URL) async {
        state = .loading
        isPersistedStoryActive = false
        diagnostics = []
        clearSecurityScopedAccess()
        do {
            let package = try await remoteLoader.loadStory(from: url)
            let parsed = parser.parse(package: package)
            diagnostics = parsed.diagnostics
            if let document = parsed.document {
                state = .loaded(document)
                persistRemoteStory(package: package)
            } else {
                handleLoadError("Story parsing failed.")
            }
        } catch {
            handleLoadError(error.localizedDescription)
        }
    }

    func loadInitialStory() {
        if loadPersistedStoryIfAvailable() {
            return
        }
        loadBundledSampleIfAvailable()
    }

    func loadPersistedStoryIfAvailable() -> Bool {
        isPersistedStoryActive = false
        persistedStoryURL = nil
        hasPersistedStory = persistedStoryStore.hasStory()
        guard hasPersistedStory else {
            return false
        }
        do {
            guard let storedStory = try persistedStoryStore.load() else {
                hasPersistedStory = false
                return false
            }
            persistedStoryURL = storedStory.sourceURL
            isPersistedStoryActive = true
            _ = loadPersistedStory(storedStory)
            return true
        } catch {
            isPersistedStoryActive = true
            state = .failed("Saved story could not be loaded.")
            persistedStoryURL = nil
            diagnostics = [
                .warning(
                    code: "saved_story_load_failed",
                    message: "Unable to load saved story. Delete it and try again.",
                ),
            ]
            return true
        }
    }

    func deletePersistedStory() {
        do {
            try persistedStoryStore.delete()
        } catch {
            diagnostics = [
                .warning(
                    code: "saved_story_delete_failed",
                    message: "Unable to delete the saved story. Try again.",
                ),
            ]
            return
        }
        persistedStoryURL = nil
        hasPersistedStory = false
        let isFailureState: Bool
        switch state {
        case .failed:
            isFailureState = true
        case .idle, .loading, .loaded:
            isFailureState = false
        }
        if isPersistedStoryActive || isFailureState {
            state = .idle
            diagnostics = []
            isPersistedStoryActive = false
        }
    }

    func loadBundledSampleIfAvailable(name: String = "sample-story") {
        guard hasLoadedSample == false else {
            return
        }
        hasLoadedSample = true
        if let url = Bundle.main.url(forResource: name, withExtension: "mdx") {
            loadStory(from: url)
        } else {
            diagnostics = [
                .warning(
                    code: "missing_bundle_sample",
                    message: "Bundled \(name).mdx not found; using built-in sample story.",
                ),
            ]
            state = .loaded(.sample())
            isPersistedStoryActive = false
        }
    }

    func handleLoadError(_ message: String) {
        diagnostics = []
        state = .failed(message)
        isPersistedStoryActive = false
        clearSecurityScopedAccess()
    }

    private func loadPersistedStory(_ story: PersistedRemoteStory) -> Bool {
        let parsed = parser.parse(storyText: story.storyText, assetBaseURL: story.assetBaseURL)
        diagnostics = parsed.diagnostics
        if let document = parsed.document {
            state = .loaded(document)
            return true
        }
        state = .failed("Story parsing failed.")
        return false
    }

    private func persistRemoteStory(package: StoryPackage) {
        let persisted = PersistedRemoteStory(
            sourceURL: package.storyURL,
            storyText: package.storyText,
            savedAt: Date(),
        )
        do {
            try persistedStoryStore.save(persisted)
            persistedStoryURL = persisted.sourceURL
            hasPersistedStory = true
            isPersistedStoryActive = true
        } catch {
            diagnostics.append(
                .warning(
                    code: "saved_story_save_failed",
                    message: "Story loaded, but it could not be saved for offline use.",
                ),
            )
        }
    }

    private func startSecurityScopedAccess(for url: URL) {
        #if os(iOS) || os(macOS)
            guard url.isFileURL else {
                clearSecurityScopedAccess()
                return
            }
            if activeSecurityScopedURL != url {
                clearSecurityScopedAccess()
            }
            if hasSecurityScopedAccess == false {
                hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
            }
            activeSecurityScopedURL = url
        #endif
    }

    private func clearSecurityScopedAccess() {
        #if os(iOS) || os(macOS)
            if hasSecurityScopedAccess, let activeURL = activeSecurityScopedURL {
                activeURL.stopAccessingSecurityScopedResource()
            }
            hasSecurityScopedAccess = false
            activeSecurityScopedURL = nil
        #endif
    }
}
