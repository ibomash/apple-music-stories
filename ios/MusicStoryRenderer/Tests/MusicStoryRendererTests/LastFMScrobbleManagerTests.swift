@testable import MusicStoryRenderer
import XCTest

@MainActor
final class LastFMScrobbleManagerTests: XCTestCase {
    func testInitLoadsExistingSession() {
        let sessionStore = InMemoryLastFMSessionStore()
        sessionStore.save(LastFMSession(username: "tester", key: "session"))

        let manager = makeManager(sessionStore: sessionStore)

        XCTAssertTrue(manager.authState.isSignedIn)
        XCTAssertEqual(manager.username, "tester")
    }

    func testSignOutClearsSession() {
        let sessionStore = InMemoryLastFMSessionStore()
        sessionStore.save(LastFMSession(username: "tester", key: "session"))
        let manager = makeManager(sessionStore: sessionStore)

        manager.signOut()

        XCTAssertEqual(manager.authState, .signedOut)
        XCTAssertNil(sessionStore.load())
    }

    private func makeManager(sessionStore: InMemoryLastFMSessionStore) -> LastFMScrobbleManager {
        LastFMScrobbleManager(
            configuration: LastFMConfiguration(apiKey: "key", apiSecret: "secret", callbackScheme: "musicstories-lastfm"),
            sessionStore: sessionStore,
            logStore: InMemoryLastFMScrobbleLogStore(),
            pendingStore: InMemoryLastFMPendingScrobbleStore(),
            ledgerStore: InMemoryLastFMDedupLedgerStore(),
            candidateStore: InMemoryLastFMScrobbleCandidateStore()
        )
    }
}
