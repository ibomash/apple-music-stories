@testable import MusicStoryRenderer
import XCTest

final class StoryDocumentStoreTests: XCTestCase {
    func testStoryMetadataSnapshotIncludesAccentColor() {
        let document = StoryDocument.sample()

        let snapshot = StoryMetadataSnapshot(document: document)

        XCTAssertEqual(snapshot.accentColor, document.accentColor)
    }

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

    func testIsCurrentStoryMatchesLoadedStory() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let storyText = makeStory(body: "<Section id=\"intro\" title=\"Intro\">Hello.</Section>")
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
        let item = StoryLaunchItem(
            id: "saved:\(url.absoluteString)",
            metadata: StoryMetadataSnapshot(document: document),
            source: .savedRemote,
            sourceURL: url,
            bookmarkData: nil,
            lastOpened: nil,
        )

        let isCurrent = await store.isCurrentStory(item)
        XCTAssertTrue(isCurrent)
    }

    func testIsCurrentStoryRejectsDifferentStory() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let storyText = makeStory(body: "<Section id=\"intro\" title=\"Intro\">Hello.</Section>")
        let package = StoryPackage(
            storyURL: url,
            storyText: storyText,
            assetBaseURL: url.deletingLastPathComponent(),
        )
        let store = await MainActor.run {
            StoryDocumentStore(remoteLoader: MockRemoteLoader { _ in package })
        }

        await store.loadRemoteStory(from: url)

        let otherDocument = StoryDocument.sample()
        let otherItem = StoryLaunchItem(
            id: "saved:other",
            metadata: StoryMetadataSnapshot(document: otherDocument),
            source: .savedRemote,
            sourceURL: URL(string: "https://example.com/other.mdx"),
            bookmarkData: nil,
            lastOpened: nil,
        )

        let isCurrent = await store.isCurrentStory(otherItem)
        XCTAssertFalse(isCurrent)
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

    func testLoadBundledSampleUsesRootStoryFile() async {
        let bundleRoot = makeTemporaryBundleRoot()
        defer { try? FileManager.default.removeItem(at: bundleRoot) }
        let storyURL = bundleRoot.appendingPathComponent("sample-story.mdx")
        XCTAssertNoThrow(try makeStoryFile(at: storyURL))
        let store = await MainActor.run {
            StoryDocumentStore(bundleResourceURL: bundleRoot)
        }

        await MainActor.run {
            store.loadBundledSampleIfAvailable()
        }

        let state = await store.state
        guard case let .loaded(document) = state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(document.id, "sample-story")
    }

    func testLoadBundledSampleFallsBackToBundledStoryPackage() async {
        let bundleRoot = makeTemporaryBundleRoot()
        defer { try? FileManager.default.removeItem(at: bundleRoot) }
        let storiesRoot = bundleRoot.appendingPathComponent("stories", isDirectory: true)
        let packageURL = storiesRoot.appendingPathComponent("alpha-story", isDirectory: true)
        XCTAssertNoThrow(try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true))
        let storyURL = packageURL.appendingPathComponent("story.mdx")
        XCTAssertNoThrow(try makeStoryFile(at: storyURL, id: "alpha-story"))
        let store = await MainActor.run {
            StoryDocumentStore(bundleResourceURL: bundleRoot)
        }

        await MainActor.run {
            store.loadBundledSampleIfAvailable()
        }

        let state = await store.state
        guard case let .loaded(document) = state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(document.id, "alpha-story")
    }

    func testAvailableStoriesSortedByRecency() async {
        let bundleRoot = makeTemporaryBundleRoot()
        defer { try? FileManager.default.removeItem(at: bundleRoot) }
        let storiesRoot = bundleRoot.appendingPathComponent("stories", isDirectory: true)
        let bundledPackageURL = storiesRoot.appendingPathComponent("bundled-story", isDirectory: true)
        XCTAssertNoThrow(try FileManager.default.createDirectory(at: bundledPackageURL, withIntermediateDirectories: true))
        let bundledStoryURL = bundledPackageURL.appendingPathComponent("story.mdx")
        XCTAssertNoThrow(try makeStoryFile(at: bundledStoryURL, id: "bundled-story"))

        let localURL = bundleRoot.appendingPathComponent("local-story.mdx")
        XCTAssertNoThrow(try makeStoryFile(at: localURL, id: "local-story"))
        let localStoryText = try? String(contentsOf: localURL, encoding: .utf8)
        let localParsed = StoryParser().parse(storyText: localStoryText ?? "", assetBaseURL: bundleRoot)
        guard let localDocument = localParsed.document else {
            return XCTFail("Expected local story document")
        }
        let localBookmark = try? localURL.bookmarkData()
        XCTAssertNotNil(localBookmark)
        let localEntry = RecentLocalStory(
            sourceURL: localURL,
            bookmarkData: localBookmark ?? Data(),
            metadata: StoryMetadataSnapshot(document: localDocument),
            lastOpened: Date(timeIntervalSince1970: 300),
        )

        let remoteURL = URL(string: "https://example.com/story.mdx")!
        let remoteStory = PersistedRemoteStory(
            sourceURL: remoteURL,
            storyText: makeStory(id: "remote-story", body: "<Section id=\"intro\" title=\"Intro\">Hello.</Section>"),
            savedAt: Date(timeIntervalSince1970: 200),
        )
        let persistedStore = MemoryPersistedStoryStore(savedStory: remoteStory)

        let recentStore = MemoryRecentLocalStoryStore(entries: [localEntry])
        let recencyStore = MemoryStoryRecencyStore(entries: [
            "bundled:\(bundledStoryURL.path)": Date(timeIntervalSince1970: 100),
            "saved:\(remoteURL.absoluteString)": Date(timeIntervalSince1970: 200),
        ])

        let store = await MainActor.run {
            StoryDocumentStore(
                persistedStoryStore: persistedStore,
                recentLocalStoryStore: recentStore,
                recencyStore: recencyStore,
                bundleResourceURL: bundleRoot,
            )
        }

        let stories = await store.availableStories
        XCTAssertEqual(stories.map { $0.metadata.id }, ["local-story", "remote-story", "bundled-story"])
    }

    func testDeleteRecentLocalStoryRemovesFromAvailableStories() async {
        let bundleRoot = makeTemporaryBundleRoot()
        defer { try? FileManager.default.removeItem(at: bundleRoot) }
        let localURL = bundleRoot.appendingPathComponent("local-story.mdx")
        XCTAssertNoThrow(try makeStoryFile(at: localURL, id: "local-story"))
        let localStoryText = try? String(contentsOf: localURL, encoding: .utf8)
        let localParsed = StoryParser().parse(storyText: localStoryText ?? "", assetBaseURL: bundleRoot)
        guard let localDocument = localParsed.document else {
            return XCTFail("Expected local story document")
        }
        let localBookmark = try? localURL.bookmarkData()
        XCTAssertNotNil(localBookmark)
        let localEntry = RecentLocalStory(
            sourceURL: localURL,
            bookmarkData: localBookmark ?? Data(),
            metadata: StoryMetadataSnapshot(document: localDocument),
            lastOpened: Date(),
        )
        let recentStore = MemoryRecentLocalStoryStore(entries: [localEntry])
        let store = await MainActor.run {
            StoryDocumentStore(
                persistedStoryStore: MemoryPersistedStoryStore(),
                recentLocalStoryStore: recentStore,
                recencyStore: MemoryStoryRecencyStore(),
                bundleResourceURL: bundleRoot,
            )
        }
        let stories = await store.availableStories
        guard let storyToDelete = stories.first else {
            return XCTFail("Expected story to delete")
        }

        await MainActor.run {
            store.deleteStory(storyToDelete)
        }

        let updatedStories = await store.availableStories
        XCTAssertTrue(updatedStories.isEmpty)
    }

    private func makeStory(id: String = "sample-story", body: String) -> String {
        """
        ---
        schema_version: 0.1
        id: "\(id)"
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

    private func makeTemporaryBundleRoot() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeStoryFile(at url: URL, id: String = "sample-story") throws {
        let storyText = makeStory(id: id, body: "<Section id=\"intro\" title=\"Intro\">Hello.</Section>")
        try storyText.write(to: url, atomically: true, encoding: .utf8)
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

private final class MemoryRecentLocalStoryStore: RecentLocalStoryStoring {
    private var entries: [RecentLocalStory]

    init(entries: [RecentLocalStory]) {
        self.entries = entries
    }

    func load() throws -> [RecentLocalStory] {
        entries
    }

    func save(_ stories: [RecentLocalStory]) throws {
        entries = stories
    }
}

private final class MemoryStoryRecencyStore: StoryRecencyStoring {
    private var entries: [String: Date]

    init(entries: [String: Date] = [:]) {
        self.entries = entries
    }

    func lastOpened(for key: String) -> Date? {
        entries[key]
    }

    func update(key: String, lastOpened: Date) throws {
        entries[key] = lastOpened
    }
}
