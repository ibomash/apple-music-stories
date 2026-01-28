import Foundation

struct LastFMSession: Codable, Hashable {
    let username: String
    let key: String
}

enum LastFMAuthState: Hashable {
    case signedOut
    case authorizing
    case exchanging
    case signedIn(LastFMSession)

    var session: LastFMSession? {
        switch self {
        case .signedIn(let session):
            return session
        case .signedOut, .authorizing, .exchanging:
            return nil
        }
    }

    var isSignedIn: Bool {
        session != nil
    }
}

struct LastFMTrack: Codable, Hashable {
    let identifier: String?
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval?

    var displayName: String {
        "\(artist) - \(title)"
    }
}

struct LastFMScrobbleCandidate: Codable, Hashable {
    let track: LastFMTrack
    let startedAt: Date
    var lastPlaybackTime: TimeInterval
    var lastUpdatedAt: Date
    var didSendNowPlaying: Bool
}

struct LastFMPendingScrobble: Codable, Hashable, Identifiable {
    let id: UUID
    let track: LastFMTrack
    let startedAt: Date
    var attempts: Int
    var lastAttemptAt: Date?
}

struct LastFMDedupLedgerEntry: Codable, Hashable {
    let key: String
    let scrobbledAt: Date
}

enum LastFMScrobbleStatus: String, Codable, Hashable {
    case pending
    case scrobbled
    case failed
    case skipped

    var displayLabel: String {
        switch self {
        case .pending:
            return "Queued"
        case .scrobbled:
            return "Scrobbled"
        case .failed:
            return "Failed"
        case .skipped:
            return "Skipped"
        }
    }
}

struct LastFMScrobbleLogEntry: Codable, Hashable, Identifiable {
    let id: UUID
    let timestamp: Date
    let trackTitle: String
    let artist: String
    let album: String?
    let status: LastFMScrobbleStatus
    let message: String?
}
