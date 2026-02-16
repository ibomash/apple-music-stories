@testable import MusicStoryRenderer
import XCTest

final class PlaybackResumeStoreTests: XCTestCase {
    private let suiteName = "PlaybackResumeStoreTests"

    func testSaveAndLoadPlaybackResumeState() {
        let defaults = makeDefaults()
        let store = UserDefaultsPlaybackResumeStore(defaults: defaults, key: "playback-resume-test")
        let state = PlaybackResumeState(
            mediaKey: "persisted-album-123",
            mediaType: "album",
            appleMusicId: "123",
            title: "Across The Universe",
            artist: "The Beatles",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            intentUsePreview: false,
            currentTrackAppleMusicId: "track-1",
            currentTrackTitle: "Across The Universe",
            currentTrackArtist: "The Beatles",
            currentTrackAlbumTitle: "Let It Be",
            playbackTime: 87,
            savedAt: Date()
        )

        store.save(state)

        let loaded = store.load()
        XCTAssertEqual(loaded, state)
    }

    func testClearRemovesPlaybackResumeState() {
        let defaults = makeDefaults()
        let store = UserDefaultsPlaybackResumeStore(defaults: defaults, key: "playback-resume-test")
        let state = PlaybackResumeState(
            mediaKey: "persisted-album-456",
            mediaType: "album",
            appleMusicId: "456",
            title: "Selected Ambient Works 85-92",
            artist: "Aphex Twin",
            artworkURL: nil,
            intentUsePreview: false,
            currentTrackAppleMusicId: nil,
            currentTrackTitle: nil,
            currentTrackArtist: nil,
            currentTrackAlbumTitle: nil,
            playbackTime: nil,
            savedAt: Date()
        )

        store.save(state)
        store.clear()

        XCTAssertNil(store.load())
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
