@testable import MusicStoryRenderer
import XCTest

final class LastFMScrobblePolicyTests: XCTestCase {
    func testScrobbleRequiresMinimumPlaybackForLongTracks() {
        let policy = LastFMScrobblePolicy(
            completionFraction: 0.8,
            completionGraceSeconds: 30,
            fallbackMinimumSeconds: 30,
            minimumPlaybackSeconds: 120
        )
        let track = LastFMTrack(identifier: "123", title: "Track", artist: "Artist", album: "Album", duration: 300)
        let candidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: Date(),
            lastPlaybackTime: 119,
            lastUpdatedAt: Date(),
            didSendNowPlaying: false
        )
        XCTAssertFalse(policy.shouldScrobble(candidate: candidate))

        var updated = candidate
        updated.lastPlaybackTime = 120
        XCTAssertTrue(policy.shouldScrobble(candidate: updated))
    }

    func testScrobbleUsesNearEndWindowForShortTracks() {
        let policy = LastFMScrobblePolicy(
            completionFraction: 0.8,
            completionGraceSeconds: 30,
            fallbackMinimumSeconds: 30,
            minimumPlaybackSeconds: 120
        )
        let track = LastFMTrack(identifier: "456", title: "Shorter", artist: "Artist", album: "Album", duration: 60)
        let candidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: Date(),
            lastPlaybackTime: 47,
            lastUpdatedAt: Date(),
            didSendNowPlaying: false
        )
        XCTAssertFalse(policy.shouldScrobble(candidate: candidate))

        var updated = candidate
        updated.lastPlaybackTime = 48
        XCTAssertTrue(policy.shouldScrobble(candidate: updated))
    }

    func testScrobbleUsesNearEndWindowForMidLengthTracks() {
        let policy = LastFMScrobblePolicy(
            completionFraction: 0.8,
            completionGraceSeconds: 30,
            fallbackMinimumSeconds: 30,
            minimumPlaybackSeconds: 120
        )
        let track = LastFMTrack(identifier: "789", title: "Mini", artist: "Artist", album: "Album", duration: 110)
        let candidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: Date(),
            lastPlaybackTime: 87,
            lastUpdatedAt: Date(),
            didSendNowPlaying: false
        )
        XCTAssertFalse(policy.shouldScrobble(candidate: candidate))

        var updated = candidate
        updated.lastPlaybackTime = 88
        XCTAssertTrue(policy.shouldScrobble(candidate: updated))
    }

    func testScrobbleUsesFallbackWhenDurationMissing() {
        let policy = LastFMScrobblePolicy(
            completionFraction: 0.8,
            completionGraceSeconds: 30,
            fallbackMinimumSeconds: 30,
            minimumPlaybackSeconds: 120
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
