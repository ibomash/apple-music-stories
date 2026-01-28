@testable import MusicStoryRenderer
import XCTest

final class LastFMScrobblePolicyTests: XCTestCase {
    func testScrobbleRequiresCompletionThresholdForKnownDuration() {
        let policy = LastFMScrobblePolicy(completionFraction: 0.9, completionGraceSeconds: 8, fallbackMinimumSeconds: 30)
        let track = LastFMTrack(identifier: "123", title: "Track", artist: "Artist", album: "Album", duration: 300)
        let candidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: Date(),
            lastPlaybackTime: 260,
            lastUpdatedAt: Date(),
            didSendNowPlaying: false
        )
        XCTAssertFalse(policy.shouldScrobble(candidate: candidate))

        var updated = candidate
        updated.lastPlaybackTime = 295
        XCTAssertTrue(policy.shouldScrobble(candidate: updated))
    }

    func testScrobbleUsesFallbackWhenDurationMissing() {
        let policy = LastFMScrobblePolicy(completionFraction: 0.9, completionGraceSeconds: 8, fallbackMinimumSeconds: 30)
        let track = LastFMTrack(identifier: nil, title: "Track", artist: "Artist", album: nil, duration: nil)
        let candidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: Date(),
            lastPlaybackTime: 25,
            lastUpdatedAt: Date(),
            didSendNowPlaying: false
        )
        XCTAssertFalse(policy.shouldScrobble(candidate: candidate))

        var updated = candidate
        updated.lastPlaybackTime = 35
        XCTAssertTrue(policy.shouldScrobble(candidate: updated))
    }
}
