@testable import MusicStoryRenderer
import XCTest

final class LastFMStoreTests: XCTestCase {
    func testPendingStoreRoundTrip() {
        let context = makeDefaults()
        let defaults = context.defaults
        let store = UserDefaultsLastFMPendingScrobbleStore(defaults: defaults, key: "lastfm-pending-test")
        let track = LastFMTrack(identifier: "1", title: "Track", artist: "Artist", album: nil, duration: 180)
        let entry = LastFMPendingScrobble(id: UUID(), track: track, startedAt: Date(), attempts: 1, lastAttemptAt: Date())

        store.save([entry])
        let loaded = store.load()

        XCTAssertEqual(loaded, [entry])
        clearDefaults(context)
    }

    func testLedgerStoreClearRemovesEntries() {
        let context = makeDefaults()
        let defaults = context.defaults
        let store = UserDefaultsLastFMDedupLedgerStore(defaults: defaults, key: "lastfm-ledger-test")
        let entry = LastFMDedupLedgerEntry(key: "key", scrobbledAt: Date())
        store.save([entry])

        store.clear()
        XCTAssertTrue(store.load().isEmpty)
        clearDefaults(context)
    }

    private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "lastfm-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return (defaults, suiteName)
    }

    private func clearDefaults(_ context: (defaults: UserDefaults, suiteName: String)) {
        context.defaults.removePersistentDomain(forName: context.suiteName)
    }
}
