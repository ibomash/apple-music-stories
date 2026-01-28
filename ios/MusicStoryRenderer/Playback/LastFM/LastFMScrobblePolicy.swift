import Foundation

struct LastFMScrobblePolicy: Hashable {
    let completionFraction: Double
    let completionGraceSeconds: TimeInterval
    let fallbackMinimumSeconds: TimeInterval
    let longTrackMinimumSeconds: TimeInterval

    init(
        completionFraction: Double = 0.8,
        completionGraceSeconds: TimeInterval = 30,
        fallbackMinimumSeconds: TimeInterval = 30,
        longTrackMinimumSeconds: TimeInterval = 60
    ) {
        self.completionFraction = completionFraction
        self.completionGraceSeconds = completionGraceSeconds
        self.fallbackMinimumSeconds = fallbackMinimumSeconds
        self.longTrackMinimumSeconds = longTrackMinimumSeconds
    }

    func shouldScrobble(candidate: LastFMScrobbleCandidate) -> Bool {
        let playedSeconds = max(0, candidate.lastPlaybackTime)
        if let duration = candidate.track.duration, duration > 0 {
            if duration >= longTrackMinimumSeconds {
                let minCompletion = max(0, duration - completionGraceSeconds)
                return playedSeconds >= minCompletion
            }
            return playedSeconds >= duration * completionFraction
        }
        return playedSeconds >= fallbackMinimumSeconds
    }
}
