import Combine
import Foundation

enum StoryLoadState {
    case idle
    case loading
    case loaded(StoryDocument)
    case failed(String)
}

enum RemoteStoryLoadError: LocalizedError {
    case invalidScheme
    case invalidExtension
    case invalidResponse
    case invalidStatusCode(Int)
    case emptyResponse
    case unreadableStory

    var errorDescription: String? {
        switch self {
        case .invalidScheme:
            "Story URLs must use http or https."
        case .invalidExtension:
            "Story URLs must point to a .mdx file."
        case .invalidResponse:
            "The server response was invalid."
        case let .invalidStatusCode(code):
            "The server returned status code \(code)."
        case .emptyResponse:
            "The story download was empty."
        case .unreadableStory:
            "Unable to read the downloaded story."
        }
    }
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

    @MainActor
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

    func loadRemoteStory(from url: URL) async {
        state = .loading
        diagnostics = []
        clearSecurityScopedAccess()
        do {
            let package = try await fetchRemotePackage(from: url)
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
                    message: "Bundled \(name).mdx not found; using built-in sample story.",
                ),
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

    private func fetchRemotePackage(from url: URL) async throws -> StoryPackage {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw RemoteStoryLoadError.invalidScheme
        }
        guard url.pathExtension.lowercased() == "mdx" else {
            throw RemoteStoryLoadError.invalidExtension
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteStoryLoadError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw RemoteStoryLoadError.invalidStatusCode(httpResponse.statusCode)
        }
        guard data.isEmpty == false else {
            throw RemoteStoryLoadError.emptyResponse
        }
        guard let storyText = String(data: data, encoding: .utf8) else {
            throw RemoteStoryLoadError.unreadableStory
        }
        let assetBaseURL = url.deletingLastPathComponent()
        return StoryPackage(storyURL: url, storyText: storyText, assetBaseURL: assetBaseURL)
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
