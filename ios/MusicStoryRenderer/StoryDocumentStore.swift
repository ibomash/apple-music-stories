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
    @Published private(set) var availableStories: [StoryLaunchItem] = []

    private let loader: StoryPackageLoading
    private let parser: StoryParser
    private let remoteLoader: RemoteStoryPackageLoading
    private let persistedStoryStore: PersistedRemoteStoryStoring
    private let recentLocalStoryStore: RecentLocalStoryStoring
    private let recencyStore: StoryRecencyStoring
    private let bundleResourceURL: URL?
    private var hasLoadedSample = false
    private var activeSecurityScopedURL: URL?
    private var hasSecurityScopedAccess = false

    init(
        loader: StoryPackageLoading = StoryPackageLoader(),
        parser: StoryParser = StoryParser(),
        remoteLoader: RemoteStoryPackageLoading = RemoteStoryPackageLoader(),
        persistedStoryStore: PersistedRemoteStoryStoring = FilePersistedRemoteStoryStore(),
        recentLocalStoryStore: RecentLocalStoryStoring = FileRecentLocalStoryStore(),
        recencyStore: StoryRecencyStoring = FileStoryRecencyStore(),
        bundleResourceURL: URL? = Bundle.main.resourceURL,
    ) {
        self.loader = loader
        self.parser = parser
        self.remoteLoader = remoteLoader
        self.persistedStoryStore = persistedStoryStore
        self.recentLocalStoryStore = recentLocalStoryStore
        self.recencyStore = recencyStore
        self.bundleResourceURL = bundleResourceURL
        availableStories = loadAvailableStories()
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
                recordStoryOpened(document: document, sourceURL: package.storyURL)
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
                recordStoryOpened(document: document, sourceURL: package.storyURL)
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
        refreshAvailableStories()
    }

    func deleteStory(_ item: StoryLaunchItem) {
        switch item.source {
        case .bundled:
            return
        case .savedRemote:
            deletePersistedStory()
        case .recentLocal:
            deleteRecentLocalStory(item)
        }
    }

    func loadBundledSampleIfAvailable(name: String = "sample-story") {
        guard hasLoadedSample == false else {
            return
        }
        hasLoadedSample = true
        if let sampleStoryURL = bundledStoryURL(named: name) {
            loadStory(from: sampleStoryURL)
            return
        }
        if let bundledPackageURL = bundledStoryPackageURLs().sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first {
            loadStory(from: bundledPackageURL)
            return
        }
        diagnostics = [
            .warning(
                code: "missing_bundle_sample",
                message: "Bundled story not found; using built-in sample story.",
            ),
        ]
        state = .loaded(.sample())
        isPersistedStoryActive = false
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
            recordStoryOpened(document: document, sourceURL: story.sourceURL)
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

    func refreshAvailableStories() {
        availableStories = loadAvailableStories()
    }

    func loadStory(from item: StoryLaunchItem) {
        switch item.source {
        case .savedRemote:
            guard loadPersistedStoryIfAvailable() else {
                handleLoadError("Saved story could not be loaded.")
                return
            }
        case .bundled:
            guard let url = item.sourceURL else {
                handleLoadError("Bundled story could not be loaded.")
                return
            }
            loadStory(from: url)
        case .recentLocal:
            guard let resolvedURL = resolveBookmarkURL(sourceURL: item.sourceURL, bookmarkData: item.bookmarkData) else {
                handleLoadError("Recent story could not be accessed.")
                return
            }
            loadStory(from: resolvedURL)
        }
    }

    func isCurrentStory(_ item: StoryLaunchItem) -> Bool {
        guard case let .loaded(document) = state else {
            return false
        }
        return document.id == item.metadata.id
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

    private func loadAvailableStories() -> [StoryLaunchItem] {
        var items: [StoryLaunchItem] = []
        items.append(contentsOf: loadBundledStoryItems())
        items.append(contentsOf: loadSavedRemoteStoryItems())
        items.append(contentsOf: loadRecentLocalStoryItems())
        return sortStoryItems(items)
    }

    private func loadBundledStoryItems() -> [StoryLaunchItem] {
        let storyURLs = bundledStoryFileURLs()
        return storyURLs.compactMap { url in
            guard let package = try? loader.loadStory(at: url) else {
                return nil
            }
            let parsed = parser.parse(package: package)
            guard let document = parsed.document else {
                return nil
            }
            let metadata = StoryMetadataSnapshot(document: document)
            let recencyKey = recencyKey(for: .bundled, url: package.storyURL)
            return StoryLaunchItem(
                id: recencyKey,
                metadata: metadata,
                source: .bundled,
                sourceURL: package.storyURL,
                bookmarkData: nil,
                lastOpened: recencyStore.lastOpened(for: recencyKey),
            )
        }
    }

    private func loadSavedRemoteStoryItems() -> [StoryLaunchItem] {
        let storedStory = (try? persistedStoryStore.load()) ?? nil
        guard let savedStory = storedStory else {
            return []
        }
        let parsed = parser.parse(storyText: savedStory.storyText, assetBaseURL: savedStory.assetBaseURL)
        guard let document = parsed.document else {
            return []
        }
        let metadata = StoryMetadataSnapshot(document: document)
        let recencyKey = recencyKey(for: .savedRemote, url: savedStory.sourceURL)
        let lastOpened = recencyStore.lastOpened(for: recencyKey) ?? savedStory.savedAt
        return [
            StoryLaunchItem(
                id: recencyKey,
                metadata: metadata,
                source: .savedRemote,
                sourceURL: savedStory.sourceURL,
                bookmarkData: nil,
                lastOpened: lastOpened,
            ),
        ]
    }

    private func loadRecentLocalStoryItems() -> [StoryLaunchItem] {
        guard let recentStories = try? recentLocalStoryStore.load() else {
            return []
        }
        return recentStories.map { entry in
            let recencyKey = recencyKey(for: .recentLocal, url: entry.sourceURL)
            return StoryLaunchItem(
                id: recencyKey,
                metadata: entry.metadata,
                source: .recentLocal,
                sourceURL: entry.sourceURL,
                bookmarkData: entry.bookmarkData,
                lastOpened: entry.lastOpened,
            )
        }
    }

    private func sortStoryItems(_ items: [StoryLaunchItem]) -> [StoryLaunchItem] {
        items.sorted { lhs, rhs in
            switch (lhs.lastOpened, rhs.lastOpened) {
            case let (left?, right?):
                if left == right {
                    return lhs.metadata.title.localizedCaseInsensitiveCompare(rhs.metadata.title) == .orderedAscending
                }
                return left > right
            case (nil, nil):
                return lhs.metadata.title.localizedCaseInsensitiveCompare(rhs.metadata.title) == .orderedAscending
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            }
        }
    }

    private func recordStoryOpened(document: StoryDocument, sourceURL: URL) {
        let source: StoryLaunchSource = isBundledStoryURL(sourceURL) ? .bundled : (sourceURL.isFileURL ? .recentLocal : .savedRemote)
        let recencyKey = recencyKey(for: source, url: sourceURL)
        do {
            try recencyStore.update(key: recencyKey, lastOpened: Date())
        } catch {
            diagnostics.append(
                .warning(
                    code: "story_recency_save_failed",
                    message: "Story opened, but it could not be saved to recents.",
                )
            )
        }
        if source == .recentLocal {
            saveRecentLocalStory(document: document, sourceURL: sourceURL)
        }
        refreshAvailableStories()
    }

    private func saveRecentLocalStory(document: StoryDocument, sourceURL: URL) {
        guard let bookmarkData = bookmarkDataForURL(sourceURL) else {
            return
        }
        let metadata = StoryMetadataSnapshot(document: document)
        let entry = RecentLocalStory(
            sourceURL: sourceURL,
            bookmarkData: bookmarkData,
            metadata: metadata,
            lastOpened: Date(),
        )
        let maxEntries = 10
        var entries = (try? recentLocalStoryStore.load()) ?? []
        entries.removeAll { $0.sourceURL == sourceURL }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        try? recentLocalStoryStore.save(entries)
    }

    private func deleteRecentLocalStory(_ item: StoryLaunchItem) {
        guard let sourceURL = item.sourceURL else {
            diagnostics = [
                .warning(
                    code: "recent_story_delete_failed",
                    message: "Unable to delete the recent story. Try again.",
                ),
            ]
            return
        }
        do {
            var entries = try recentLocalStoryStore.load()
            entries.removeAll { $0.sourceURL == sourceURL }
            try recentLocalStoryStore.save(entries)
        } catch {
            diagnostics = [
                .warning(
                    code: "recent_story_delete_failed",
                    message: "Unable to delete the recent story. Try again.",
                ),
            ]
            return
        }
        refreshAvailableStories()
    }

    private func resolveBookmarkURL(sourceURL: URL?, bookmarkData: Data?) -> URL? {
        guard let sourceURL, let bookmarkData else {
            return sourceURL
        }
        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: bookmarkResolutionOptions,
            bookmarkDataIsStale: &isStale
        ) else {
            return sourceURL
        }
        if isStale, let refreshed = bookmarkDataForURL(resolvedURL) {
            var entries = (try? recentLocalStoryStore.load()) ?? []
            if let index = entries.firstIndex(where: { $0.sourceURL == sourceURL }) {
                let updated = RecentLocalStory(
                    sourceURL: resolvedURL,
                    bookmarkData: refreshed,
                    metadata: entries[index].metadata,
                    lastOpened: entries[index].lastOpened,
                )
                entries[index] = updated
                try? recentLocalStoryStore.save(entries)
            }
        }
        return resolvedURL
    }

    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
            return [.withSecurityScope, .withoutUI]
        #else
            return [.withoutUI]
        #endif
    }

    private func bookmarkDataForURL(_ url: URL) -> Data? {
        #if os(macOS)
            return try? url.bookmarkData(options: .withSecurityScope)
        #else
            return try? url.bookmarkData()
        #endif
    }

    private func recencyKey(for source: StoryLaunchSource, url: URL) -> String {
        switch source {
        case .bundled:
            return "bundled:\(url.path)"
        case .savedRemote:
            return "saved:\(url.absoluteString)"
        case .recentLocal:
            return "local:\(url.absoluteString)"
        }
    }

    private func bundledStoryURL(named name: String) -> URL? {
        guard let bundleResourceURL else {
            return nil
        }
        let url = bundleResourceURL.appendingPathComponent("\(name).mdx")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private func bundledStoryFileURLs() -> [URL] {
        var urls: [URL] = []
        if let sampleURL = bundledStoryURL(named: "sample-story") {
            urls.append(sampleURL)
        }
        urls.append(contentsOf: bundledStoryPackageURLs())
        return urls
    }

    private func bundledStoryPackageURLs() -> [URL] {
        guard let bundleResourceURL else {
            return []
        }
        let storiesURL = bundleResourceURL.appendingPathComponent("stories", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: storiesURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: storiesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
        ) else {
            return []
        }
        return entries.filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else {
                return false
            }
            let storyURL = url.appendingPathComponent("story.mdx")
            return FileManager.default.fileExists(atPath: storyURL.path)
        }
    }

    private func isBundledStoryURL(_ url: URL) -> Bool {
        guard let bundleResourceURL else {
            return false
        }
        return url.path.hasPrefix(bundleResourceURL.path)
    }
}
