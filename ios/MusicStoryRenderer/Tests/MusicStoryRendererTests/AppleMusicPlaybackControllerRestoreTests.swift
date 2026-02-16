@testable import MusicStoryRenderer
import MusicKit
import XCTest

@MainActor
final class AppleMusicPlaybackControllerRestoreTests: XCTestCase {
    func testRestorePlaybackResumeStateWhenSystemMatches() async {
        let stored = PlaybackResumeState(
            mediaKey: "persisted-album-123",
            mediaType: "album",
            appleMusicId: "123",
            title: "Future Days",
            artist: "Can",
            artworkURL: nil,
            intentUsePreview: false,
            currentTrackAppleMusicId: "track-1",
            currentTrackTitle: "Future Days",
            currentTrackArtist: "Can",
            currentTrackAlbumTitle: "Future Days",
            playbackTime: 42,
            savedAt: Date()
        )
        let store = TestPlaybackResumeStore(state: stored)
        let snapshot = AppleMusicPlaybackController.SystemPlaybackSnapshot(
            playbackStatus: .playing,
            playbackTime: 42,
            albumTitle: stored.title,
            artistName: stored.artist,
            currentTrackAppleMusicId: "track-1",
            currentTrackTitle: "Future Days",
            currentTrackArtist: "Can",
            currentTrackAlbumTitle: "Future Days",
            currentEntry: nil
        )
        let controller = AppleMusicPlaybackController(
            playbackEnabled: false,
            resumeStore: store,
            systemSnapshotProvider: { snapshot }
        )
        controller.updateAuthorizationStatus(.authorized)

        await controller.restorePlaybackResumeStateIfNeeded()

        XCTAssertEqual(controller.queueState.nowPlaying?.media.appleMusicId, stored.appleMusicId)
        XCTAssertEqual(controller.queueState.nowPlaying?.media.title, stored.title)
        XCTAssertEqual(controller.nowPlayingMetadata?.title, stored.title)
        XCTAssertEqual(controller.playbackState, .playing)
        XCTAssertFalse(store.didClear)
    }

    func testRestorePlaybackResumeStateKeepsEntryWhenSystemChanged() async {
        let stored = PlaybackResumeState(
            mediaKey: "persisted-album-456",
            mediaType: "album",
            appleMusicId: "456",
            title: "Low",
            artist: "David Bowie",
            artworkURL: nil,
            intentUsePreview: false,
            currentTrackAppleMusicId: "track-2",
            currentTrackTitle: "Speed of Life",
            currentTrackArtist: "David Bowie",
            currentTrackAlbumTitle: "Low",
            playbackTime: 11,
            savedAt: Date()
        )
        let store = TestPlaybackResumeStore(state: stored)
        let snapshot = AppleMusicPlaybackController.SystemPlaybackSnapshot(
            playbackStatus: .paused,
            playbackTime: 0,
            albumTitle: "Another Green World",
            artistName: "Brian Eno",
            currentTrackAppleMusicId: "track-other",
            currentTrackTitle: "Sky Saw",
            currentTrackArtist: "Brian Eno",
            currentTrackAlbumTitle: "Another Green World",
            currentEntry: nil
        )
        let controller = AppleMusicPlaybackController(
            playbackEnabled: false,
            resumeStore: store,
            systemSnapshotProvider: { snapshot }
        )
        controller.updateAuthorizationStatus(.authorized)

        await controller.restorePlaybackResumeStateIfNeeded()

        XCTAssertEqual(controller.queueState.nowPlaying?.media.appleMusicId, stored.appleMusicId)
        XCTAssertEqual(controller.nowPlayingMetadata?.title, stored.title)
        XCTAssertEqual(controller.playbackState, .stopped)
        XCTAssertFalse(store.didClear)
    }
}

private final class TestPlaybackResumeStore: PlaybackResumeStoring {
    private(set) var didClear = false
    private var state: PlaybackResumeState?

    init(state: PlaybackResumeState? = nil) {
        self.state = state
    }

    func load() -> PlaybackResumeState? {
        state
    }

    func save(_ state: PlaybackResumeState) {
        self.state = state
    }

    func clear() {
        didClear = true
        state = nil
    }
}
