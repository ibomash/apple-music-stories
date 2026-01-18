import SwiftUI

@main
struct MusicStoryRendererApp: App {
    var body: some Scene {
        WindowGroup {
            StoryRootView()
        }
    }
}

struct StoryRootView: View {
    @StateObject private var store = StoryDocumentStore()

    var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                ProgressView("Loading Story…")
            case let .loaded(document):
                StoryRendererView(document: document)
            case let .failed(message):
                ContentUnavailableView(
                    "Unable to Load Story",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .task {
            store.loadBundledSampleIfAvailable()
        }
    }
}
