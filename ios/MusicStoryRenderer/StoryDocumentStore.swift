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

    init(loader: StoryPackageLoading = StoryPackageLoader(), parser: StoryParser = StoryParser()) {
        self.loader = loader
        self.parser = parser
    }

    func loadStory(from url: URL) {
        state = .loading
        do {
            let package = try loader.loadStory(at: url)
            let parsed = parser.parse(package: package)
            diagnostics = parsed.diagnostics
            if let document = parsed.document {
                state = .loaded(document)
            } else {
                state = .failed("Story parsing failed.")
            }
        } catch {
            diagnostics = []
            state = .failed(error.localizedDescription)
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
}
