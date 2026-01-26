@testable import MusicStoryRenderer
import MusicKit
import XCTest

@MainActor
final class AppleMusicPlaybackControllerRestoreTests: XCTestCase {
    func testRestoreLastPlayedAlbumWhenSystemMatches() async {
        let stored = LastPlayedAlbumState(
            mediaKey: "persisted-album-123",
            appleMusicId: "123",
            title: "Future Days",
            artist: "Can",
            artworkURL: nil,
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let store = TestLastPlayedAlbumStore(state: stored)
        let snapshot = AppleMusicPlaybackController.SystemPlaybackSnapshot(
            playbackStatus: .playing,
            playbackTime: 42,
            albumTitle: stored.title,
            artistName: stored.artist,
            currentEntry: nil
        )
        let controller = AppleMusicPlaybackController(
            playbackEnabled: false,
            lastPlayedAlbumStore: store,
            systemSnapshotProvider: { snapshot }
        )
        controller.updateAuthorizationStatus(.authorized)

        await controller.restoreLastPlayedAlbumIfRelevant()

        XCTAssertEqual(controller.queueState.nowPlaying?.media.appleMusicId, stored.appleMusicId)
        XCTAssertEqual(controller.queueState.nowPlaying?.media.title, stored.title)
        XCTAssertEqual(controller.nowPlayingMetadata?.title, stored.title)
        XCTAssertEqual(controller.playbackState, .playing)
        XCTAssertFalse(store.didClear)
    }

    func testRestoreLastPlayedAlbumClearsStateWhenSystemChanged() async {
        let stored = LastPlayedAlbumState(
            mediaKey: "persisted-album-456",
            appleMusicId: "456",
            title: "Low",
            artist: "David Bowie",
            artworkURL: nil,
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let store = TestLastPlayedAlbumStore(state: stored)
        let snapshot = AppleMusicPlaybackController.SystemPlaybackSnapshot(
            playbackStatus: .paused,
            playbackTime: 0,
            albumTitle: "Another Green World",
            artistName: "Brian Eno",
            currentEntry: nil
        )
        let controller = AppleMusicPlaybackController(
            playbackEnabled: false,
            lastPlayedAlbumStore: store,
            systemSnapshotProvider: { snapshot }
        )
        controller.updateAuthorizationStatus(.authorized)

        await controller.restoreLastPlayedAlbumIfRelevant()

        XCTAssertNil(controller.queueState.nowPlaying)
        XCTAssertNil(controller.nowPlayingMetadata)
        XCTAssertEqual(controller.playbackState, .stopped)
        XCTAssertTrue(store.didClear)
    }
}

private final class TestLastPlayedAlbumStore: LastPlayedAlbumStoring {
    private(set) var didClear = false
    private var state: LastPlayedAlbumState?

    init(state: LastPlayedAlbumState? = nil) {
        self.state = state
    }

    func load() -> LastPlayedAlbumState? {
        state
    }

    func save(_ state: LastPlayedAlbumState) {
        self.state = state
    }

    func clear() {
        didClear = true
        state = nil
    }
}
