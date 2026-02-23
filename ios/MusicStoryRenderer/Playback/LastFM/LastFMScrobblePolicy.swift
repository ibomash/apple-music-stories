import Foundation

struct LastFMScrobblePolicy: Hashable {
    enum ThresholdReason: String, Hashable {
        case minimumPlayback = "minimum_playback"
        case nearEnd = "near_end"
        case fallback = "fallback"
    }

    struct Eligibility: Hashable {
        let isEligible: Bool
        let thresholdSeconds: TimeInterval
        let reason: ThresholdReason
    }

    let completionFraction: Double
    let completionGraceSeconds: TimeInterval
    let fallbackMinimumSeconds: TimeInterval
    let minimumPlaybackSeconds: TimeInterval

    init(
        completionFraction: Double = 0.8,
        completionGraceSeconds: TimeInterval = 30,
        fallbackMinimumSeconds: TimeInterval = 30,
        minimumPlaybackSeconds: TimeInterval = 120
    ) {
        self.completionFraction = completionFraction
        self.completionGraceSeconds = completionGraceSeconds
        self.fallbackMinimumSeconds = fallbackMinimumSeconds
        self.minimumPlaybackSeconds = minimumPlaybackSeconds
    }

    func shouldScrobble(candidate: LastFMScrobbleCandidate) -> Bool {
        eligibility(candidate: candidate).isEligible
    }

    func eligibility(candidate: LastFMScrobbleCandidate) -> Eligibility {
        let playedSeconds = max(0, candidate.lastPlaybackTime)
        let threshold = scrobbleThreshold(for: candidate)
        return Eligibility(
            isEligible: playedSeconds >= threshold.seconds,
            thresholdSeconds: threshold.seconds,
            reason: threshold.reason
        )
    }

    private func scrobbleThreshold(for candidate: LastFMScrobbleCandidate) -> (seconds: TimeInterval, reason: ThresholdReason) {
        if let duration = candidate.track.duration, duration > 0 {
            if duration >= minimumPlaybackSeconds {
                return (max(0, minimumPlaybackSeconds), .minimumPlayback)
            }
            let nearEndSeconds = max(0, duration - completionGraceSeconds)
            let fractionSeconds = max(0, duration * completionFraction)
            return (max(nearEndSeconds, fractionSeconds), .nearEnd)
        }
        return (max(0, fallbackMinimumSeconds), .fallback)
    }
}
