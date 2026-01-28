@testable import MusicStoryRenderer
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class StorySnapshotTests: XCTestCase {
    private let isRecording = ProcessInfo.processInfo.environment["SNAPSHOT_RECORDING"] == "1"
    private let snapshotLocale = Locale(identifier: "en_US")
    private let snapshotTimeZone = TimeZone(secondsFromGMT: 0) ?? .current
    private let snapshotSizeCategory: ContentSizeCategory = .medium
    private var previousTimeZone: TimeZone?
    private var previousLocale: String?
    private var previousLanguages: [String]?

    override func setUp() {
        super.setUp()
        SnapshotTesting.isRecording = isRecording
        previousTimeZone = NSTimeZone.default
        previousLocale = UserDefaults.standard.string(forKey: "AppleLocale")
        previousLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        NSTimeZone.default = snapshotTimeZone
        UserDefaults.standard.set(snapshotLocale.identifier, forKey: "AppleLocale")
        UserDefaults.standard.set([snapshotLocale.identifier], forKey: "AppleLanguages")
    }

    override func tearDown() {
        if let previousTimeZone {
            NSTimeZone.default = previousTimeZone
        }
        if let previousLocale {
            UserDefaults.standard.set(previousLocale, forKey: "AppleLocale")
        }
        if let previousLanguages {
            UserDefaults.standard.set(previousLanguages, forKey: "AppleLanguages")
        }
        super.tearDown()
    }

    func testStoryRendererView() {
        let controller = AppleMusicPlaybackController(playbackEnabled: false)
        controller.updateAuthorizationStatus(.authorized)
        controller.queue(media: makeTrack(), intent: .full)

        let view = StoryRendererView(document: makeStoryDocument(), playbackController: controller)
        assertSnapshot(for: view, named: "story-renderer")
    }

    func testMediaCard() {
        let controller = AppleMusicPlaybackController(playbackEnabled: false)
        controller.updateAuthorizationStatus(.authorized)

        let view = MediaReferenceView(media: makeTrack(), intent: .full, playbackController: controller)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))

        assertSnapshot(for: view, named: "media-card")
    }

    func testMediaVideoCard() {
        let controller = AppleMusicPlaybackController(playbackEnabled: false)
        controller.updateAuthorizationStatus(.authorized)

        let view = MediaReferenceView(media: makeVideo(), intent: .full, playbackController: controller)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))

        assertSnapshot(for: view, named: "media-video-card")
    }

    func testPlaybackBar() {
        let controller = AppleMusicPlaybackController(playbackEnabled: false)
        controller.updateAuthorizationStatus(.authorized)
        controller.queue(media: makeTrack(), intent: .full)

        let view = PlaybackBarView(controller: controller, onExpand: {})
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))

        assertSnapshot(for: view, named: "playback-bar")
    }

    func testNowPlayingSheet() {
        let controller = AppleMusicPlaybackController(playbackEnabled: false)
        controller.updateAuthorizationStatus(.authorized)
        controller.play(media: makeTrack(), intent: .full)
        controller.queue(media: makeAlternateTrack(), intent: .full)

        let view = NowPlayingSheetView(controller: controller)
        assertSnapshot(for: view, named: "now-playing-sheet")
    }

    func testNowPlayingSheetLongTitles() {
        let controller = AppleMusicPlaybackController(playbackEnabled: false)
        controller.updateAuthorizationStatus(.authorized)
        controller.play(media: makeLongTrack(), intent: .full)
        controller.queue(media: makeAlternateTrack(), intent: .full)

        let view = NowPlayingSheetView(controller: controller)
        assertSnapshot(for: view, named: "now-playing-sheet-long-titles")
    }

    func testLaunchDiagnostics() {
        let store = StoryDocumentStore(
            persistedStoryStore: MemoryPersistedRemoteStoryStore(),
            recentLocalStoryStore: MemoryRecentLocalStoryStore(),
            recencyStore: MemoryStoryRecencyStore(),
            bundleResourceURL: nil
        )
        store.loadBundledSampleIfAvailable(name: "missing-sample")

        let view = StoryLaunchView(
            store: store,
            scrobbleManager: makeScrobbleManager(),
            diagnosticLogger: makeDiagnosticLogger(),
            availableStories: store.availableStories,
            onOpenStory: {},
            onSelectStory: { _ in },
            onPickStory: {},
            onLoadStoryURL: {},
            onDeleteStory: {},
            onDeleteCatalogStory: { _ in }
        )
        assertSnapshot(for: view, named: "launch-diagnostics")
    }

    private func makeScrobbleManager() -> LastFMScrobbleManager {
        LastFMScrobbleManager(
            configuration: nil,
            sessionStore: InMemoryLastFMSessionStore(),
            logStore: InMemoryLastFMScrobbleLogStore(),
            pendingStore: InMemoryLastFMPendingScrobbleStore(),
            ledgerStore: InMemoryLastFMDedupLedgerStore(),
            candidateStore: InMemoryLastFMScrobbleCandidateStore()
        )
    }

    private func makeDiagnosticLogger() -> DiagnosticLogManager {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "StorySnapshotTests.\(UUID().uuidString)") ?? .standard
        return DiagnosticLogManager(
            store: DiagnosticLogStore(baseDirectoryURL: tempRoot),
            defaults: defaults
        )
    }

    private func assertSnapshot<V: View>(for view: V, named name: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshotTimeZone
        let normalizedView = view
            .environment(\.locale, snapshotLocale)
            .environment(\.timeZone, snapshotTimeZone)
            .environment(\.calendar, calendar)
            .environment(\.layoutDirection, .leftToRight)
            .environment(\.sizeCategory, snapshotSizeCategory)
            .environment(\.colorScheme, .light)
        let controller = UIHostingController(rootView: normalizedView)
        controller.view.backgroundColor = .systemBackground
        SnapshotTesting.assertSnapshot(
            matching: controller,
            as: .image(on: .iPhone13),
            named: name,
            record: isRecording
        )
    }

    private func makeStoryDocument() -> StoryDocument {
        StoryDocument(
            schemaVersion: "0.1",
            id: "snapshot-story",
            title: "Snapshots in Motion",
            subtitle: "A visual regression story",
            deck: nil,
            authors: ["Music Stories"],
            editors: [],
            publishDate: Date(timeIntervalSince1970: 1_737_484_800),
            tags: ["ui", "snapshot"],
            locale: "en-US",
            accentColor: nil,
            heroGradient: [],
            typeRamp: nil,
            heroImage: nil,
            leadArt: nil,
            sections: [
                StorySection(
                    id: "intro",
                    title: "Opening",
                    layout: "lede",
                    leadMediaKey: "trk-01",
                    blocks: [
                        .paragraph(
                            id: "intro-paragraph",
                            text: "Snapshot tests lock in layout and typography for each story scene.",
                        ),
                        .media(
                            id: "intro-media",
                            referenceKey: "trk-01",
                            intent: .full,
                        ),
                    ],
                ),
                StorySection(
                    id: "closing",
                    title: "Wrap",
                    layout: nil,
                    leadMediaKey: nil,
                    blocks: [
                        .paragraph(
                            id: "closing-paragraph",
                            text: "Keep visual regressions on a short leash by updating snapshots intentionally.",
                        ),
                    ],
                ),
            ],
            media: [makeTrack()],
        )
    }

    private func makeTrack() -> StoryMediaReference {
        StoryMediaReference(
            key: "trk-01",
            type: .track,
            appleMusicId: "123456789",
            title: "Night Drive",
            artist: "Signal Bloom",
            artworkURL: nil,
            durationMilliseconds: 192_000,
        )
    }

    private func makeAlternateTrack() -> StoryMediaReference {
        StoryMediaReference(
            key: "trk-02",
            type: .track,
            appleMusicId: "987654321",
            title: "City Lights",
            artist: "Signal Bloom",
            artworkURL: nil,
            durationMilliseconds: 204_000,
        )
    }

    private func makeLongTrack() -> StoryMediaReference {
        StoryMediaReference(
            key: "trk-03",
            type: .track,
            appleMusicId: "222222222",
            title: "Roman's Revenge (feat. Eminem) - Expanded Edition Bonus Track",
            artist: "Nicki Minaj and Friends Featuring Special Guests",
            artworkURL: nil,
            durationMilliseconds: 198_000,
        )
    }

    private func makeVideo() -> StoryMediaReference {
        StoryMediaReference(
            key: "vid-01",
            type: .musicVideo,
            appleMusicId: "555555555",
            title: "Midnight Cut",
            artist: "Signal Bloom",
            artworkURL: nil,
            durationMilliseconds: nil,
        )
    }
}

private final class MemoryPersistedRemoteStoryStore: PersistedRemoteStoryStoring {
    private var story: PersistedRemoteStory?

    init(story: PersistedRemoteStory? = nil) {
        self.story = story
    }

    func load() throws -> PersistedRemoteStory? {
        story
    }

    func save(_ story: PersistedRemoteStory) throws {
        self.story = story
    }

    func delete() throws {
        story = nil
    }

    func hasStory() -> Bool {
        story != nil
    }
}

private final class MemoryRecentLocalStoryStore: RecentLocalStoryStoring {
    private var stories: [RecentLocalStory]

    init(stories: [RecentLocalStory] = []) {
        self.stories = stories
    }

    func load() throws -> [RecentLocalStory] {
        stories
    }

    func save(_ stories: [RecentLocalStory]) throws {
        self.stories = stories
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
