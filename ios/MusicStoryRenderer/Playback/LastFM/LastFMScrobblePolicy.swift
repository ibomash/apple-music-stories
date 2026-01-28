import Foundation

struct LastFMScrobblePolicy: Hashable {
    let completionFraction: Double
    let completionGraceSeconds: TimeInterval
    let fallbackMinimumSeconds: TimeInterval

    init(
        completionFraction: Double = 0.9,
        completionGraceSeconds: TimeInterval = 8,
        fallbackMinimumSeconds: TimeInterval = 30
    ) {
        self.completionFraction = completionFraction
        self.completionGraceSeconds = completionGraceSeconds
        self.fallbackMinimumSeconds = fallbackMinimumSeconds
    }

    func shouldScrobble(candidate: LastFMScrobbleCandidate) -> Bool {
        let playedSeconds = max(0, candidate.lastPlaybackTime)
        if let duration = candidate.track.duration, duration > 0 {
            let minCompletion = max(duration * completionFraction, duration - completionGraceSeconds)
            return playedSeconds >= minCompletion
        }
        return playedSeconds >= fallbackMinimumSeconds
    }
}
