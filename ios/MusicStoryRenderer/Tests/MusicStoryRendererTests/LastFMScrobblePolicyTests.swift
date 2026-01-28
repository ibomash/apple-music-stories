@testable import MusicStoryRenderer
import XCTest

final class LastFMScrobblePolicyTests: XCTestCase {
    func testScrobbleRequiresNearEndWindowForLongTracks() {
        let policy = LastFMScrobblePolicy(
            completionFraction: 0.8,
            completionGraceSeconds: 30,
            fallbackMinimumSeconds: 30,
            longTrackMinimumSeconds: 60
        )
        let track = LastFMTrack(identifier: "123", title: "Track", artist: "Artist", album: "Album", duration: 300)
        let candidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: Date(),
            lastPlaybackTime: 269,
            lastUpdatedAt: Date(),
            didSendNowPlaying: false
        )
        XCTAssertFalse(policy.shouldScrobble(candidate: candidate))

        var updated = candidate
        updated.lastPlaybackTime = 270
        XCTAssertTrue(policy.shouldScrobble(candidate: updated))
    }

    func testScrobbleUsesNearEndWindowAtLongTrackThreshold() {
        let policy = LastFMScrobblePolicy(
            completionFraction: 0.8,
            completionGraceSeconds: 30,
            fallbackMinimumSeconds: 30,
            longTrackMinimumSeconds: 60
        )
        let track = LastFMTrack(identifier: "456", title: "Shorter", artist: "Artist", album: "Album", duration: 60)
        let candidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: Date(),
            lastPlaybackTime: 29,
            lastUpdatedAt: Date(),
            didSendNowPlaying: false
        )
        XCTAssertFalse(policy.shouldScrobble(candidate: candidate))

        var updated = candidate
        updated.lastPlaybackTime = 40
        XCTAssertTrue(policy.shouldScrobble(candidate: updated))
    }

    func testScrobbleUsesFractionForShortTracks() {
        let policy = LastFMScrobblePolicy(
            completionFraction: 0.8,
            completionGraceSeconds: 30,
            fallbackMinimumSeconds: 30,
            longTrackMinimumSeconds: 60
        )
        let track = LastFMTrack(identifier: "789", title: "Mini", artist: "Artist", album: "Album", duration: 50)
        let candidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: Date(),
            lastPlaybackTime: 39,
            lastUpdatedAt: Date(),
            didSendNowPlaying: false
        )
        XCTAssertFalse(policy.shouldScrobble(candidate: candidate))

        var updated = candidate
        updated.lastPlaybackTime = 40
        XCTAssertTrue(policy.shouldScrobble(candidate: updated))
    }

    func testScrobbleUsesFallbackWhenDurationMissing() {
        let policy = LastFMScrobblePolicy(
            completionFraction: 0.8,
            completionGraceSeconds: 30,
            fallbackMinimumSeconds: 30,
            longTrackMinimumSeconds: 60
        )
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
