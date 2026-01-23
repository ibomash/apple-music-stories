@testable import MusicStoryRenderer
import XCTest

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
        let store = await MainActor.run {
            StoryDocumentStore(remoteLoader: MockRemoteLoader { _ in package })
        }

        await store.loadRemoteStory(from: url)

        let state = await store.state
        guard case let .loaded(document) = state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(document.id, "sample-story")
        let diagnostics = await store.diagnostics
        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testLoadRemoteStoryPersistsStory() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let storyText = makeStory(body: "<Section id=\"intro\" title=\"Intro\">Hello.</Section>")
        let package = StoryPackage(
            storyURL: url,
            storyText: storyText,
            assetBaseURL: url.deletingLastPathComponent(),
        )
        let persistence = MemoryPersistedStoryStore()
        let store = await MainActor.run {
            StoryDocumentStore(
                remoteLoader: MockRemoteLoader { _ in package },
                persistedStoryStore: persistence,
            )
        }

        await store.loadRemoteStory(from: url)

        XCTAssertTrue(persistence.hasStory())
        XCTAssertEqual(persistence.savedStory?.sourceURL, url)
        let persistedStoryURL = await store.persistedStoryURL
        XCTAssertEqual(persistedStoryURL, url)
    }

    func testLoadRemoteStoryFailure() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let store = await MainActor.run {
            StoryDocumentStore(
                remoteLoader: MockRemoteLoader { _ in throw RemoteStoryLoadError.invalidScheme }
            )
        }

        await store.loadRemoteStory(from: url)

        let state = await store.state
        guard case let .failed(message) = state else {
            return XCTFail("Expected failed state")
        }
        XCTAssertEqual(message, RemoteStoryLoadError.invalidScheme.localizedDescription)
        let diagnostics = await store.diagnostics
        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testLoadPersistedStoryIfAvailable() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let persistedStory = PersistedRemoteStory(
            sourceURL: url,
            storyText: makeStory(body: "<Section id=\"intro\" title=\"Intro\">Hello.</Section>"),
            savedAt: Date(),
        )
        let persistence = MemoryPersistedStoryStore(savedStory: persistedStory)
        let store = await MainActor.run {
            StoryDocumentStore(persistedStoryStore: persistence)
        }

        let didLoad = await store.loadPersistedStoryIfAvailable()

        XCTAssertTrue(didLoad)
        let persistedStoryURL = await store.persistedStoryURL
        XCTAssertEqual(persistedStoryURL, url)
        let state = await store.state
        guard case let .loaded(document) = state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(document.id, "sample-story")
    }

    func testDeletePersistedStoryClearsState() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let persistedStory = PersistedRemoteStory(
            sourceURL: url,
            storyText: makeStory(body: "<Section id=\"intro\" title=\"Intro\">Hello.</Section>"),
            savedAt: Date(),
        )
        let persistence = MemoryPersistedStoryStore(savedStory: persistedStory)
        let store = await MainActor.run {
            StoryDocumentStore(persistedStoryStore: persistence)
        }
        _ = await store.loadPersistedStoryIfAvailable()

        await store.deletePersistedStory()

        XCTAssertFalse(persistence.hasStory())
        let hasPersistedStory = await store.hasPersistedStory
        XCTAssertFalse(hasPersistedStory)
        let state = await store.state
        guard case .idle = state else {
            return XCTFail("Expected idle state")
        }
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

private final class MemoryPersistedStoryStore: PersistedRemoteStoryStoring, @unchecked Sendable {
    private(set) var savedStory: PersistedRemoteStory?

    init(savedStory: PersistedRemoteStory? = nil) {
        self.savedStory = savedStory
    }

    func load() throws -> PersistedRemoteStory? {
        savedStory
    }

    func save(_ story: PersistedRemoteStory) throws {
        savedStory = story
    }

    func delete() throws {
        savedStory = nil
    }

    func hasStory() -> Bool {
        savedStory != nil
    }
}
