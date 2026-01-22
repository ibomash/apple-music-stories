@testable import MusicStoryRenderer
import XCTest

@MainActor
final class StoryDocumentStoreTests: XCTestCase {
    func testLoadRemoteStorySuccess() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let storyText = makeStory(body: """
        <Section id=\"intro\" title=\"Intro\">
        Hello.

        <MediaRef ref=\"trk-1\" intent=\"preview\" />
        </Section>
        """)
        let package = StoryPackage(
            storyURL: url,
            storyText: storyText,
            assetBaseURL: url.deletingLastPathComponent(),
        )
        let store = StoryDocumentStore(remoteLoader: MockRemoteLoader { _ in package })

        await store.loadRemoteStory(from: url)

        guard case let .loaded(document) = store.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(document.id, "sample-story")
        XCTAssertTrue(store.diagnostics.isEmpty)
    }

    func testLoadRemoteStoryFailure() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let store = StoryDocumentStore(
            remoteLoader: MockRemoteLoader { _ in throw RemoteStoryLoadError.invalidScheme }
        )

        await store.loadRemoteStory(from: url)

        guard case let .failed(message) = store.state else {
            return XCTFail("Expected failed state")
        }
        XCTAssertEqual(message, RemoteStoryLoadError.invalidScheme.localizedDescription)
        XCTAssertTrue(store.diagnostics.isEmpty)
    }

    private func makeStory(body: String) -> String {
        """
        ---
        schema_version: 0.1
        id: "sample-story"
        title: "Sample Story"
        authors: ["Tester"]
        publish_date: "2026-01-12"
        sections:
          - id: intro
            title: "Intro"
        media:
          - key: trk-1
            type: track
            apple_music_id: "123"
            title: "Song"
            artist: "Artist"
        ---
        \(body)
        """
    }
}

private struct MockRemoteLoader: RemoteStoryPackageLoading {
    let handler: @Sendable (URL) async throws -> StoryPackage

    func loadStory(from url: URL) async throws -> StoryPackage {
        try await handler(url)
    }
}
