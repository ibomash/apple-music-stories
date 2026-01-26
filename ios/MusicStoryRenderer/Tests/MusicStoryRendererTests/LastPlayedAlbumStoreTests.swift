@testable import MusicStoryRenderer
import XCTest

final class LastPlayedAlbumStoreTests: XCTestCase {
    private let suiteName = "LastPlayedAlbumStoreTests"

    func testSaveAndLoadLastPlayedAlbum() {
        let defaults = makeDefaults()
        let store = UserDefaultsLastPlayedAlbumStore(defaults: defaults, key: "last-played-album-test")
        let state = LastPlayedAlbumState(
            mediaKey: "persisted-album-123",
            appleMusicId: "123",
            title: "Across The Universe",
            artist: "The Beatles",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        store.save(state)

        let loaded = store.load()
        XCTAssertEqual(loaded, state)
    }

    func testClearRemovesLastPlayedAlbum() {
        let defaults = makeDefaults()
        let store = UserDefaultsLastPlayedAlbumStore(defaults: defaults, key: "last-played-album-test")
        let state = LastPlayedAlbumState(
            mediaKey: "persisted-album-456",
            appleMusicId: "456",
            title: "Selected Ambient Works 85-92",
            artist: "Aphex Twin",
            artworkURL: nil,
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
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
