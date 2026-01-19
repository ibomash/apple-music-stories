import Combine
import Foundation

enum StoryLoadState {
    case idle
    case loading
    case loaded(StoryDocument)
    case failed(String)
}

@MainActor
final class StoryDocumentStore: ObservableObject {
    @Published private(set) var state: StoryLoadState = .idle
    @Published private(set) var diagnostics: [ValidationDiagnostic] = []

    private let loader: StoryPackageLoading
    private let parser: StoryParser
    private var hasLoadedSample = false
    private var activeSecurityScopedURL: URL?
    private var hasSecurityScopedAccess = false

    init(loader: StoryPackageLoading = StoryPackageLoader(), parser: StoryParser = StoryParser()) {
        self.loader = loader
        self.parser = parser
    }

    deinit {
        clearSecurityScopedAccess()
    }

    func loadStory(from url: URL) {
        state = .loading
        startSecurityScopedAccess(for: url)
        do {
            let package = try loader.loadStory(at: url)
            let parsed = parser.parse(package: package)
            diagnostics = parsed.diagnostics
            if let document = parsed.document {
                state = .loaded(document)
            } else {
                handleLoadError("Story parsing failed.")
            }
        } catch {
            handleLoadError(error.localizedDescription)
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
                    message: "Bundled \(name).mdx not found; using built-in sample story."
                )
            ]
            state = .loaded(.sample())
        }
    }

    func handleLoadError(_ message: String) {
        diagnostics = []
        state = .failed(message)
        clearSecurityScopedAccess()
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
