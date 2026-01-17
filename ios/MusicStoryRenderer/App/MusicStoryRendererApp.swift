import SwiftUI

@main
struct MusicStoryRendererApp: App {
    var body: some Scene {
        WindowGroup {
            StoryRendererView(document: .sample())
        }
    }
}
