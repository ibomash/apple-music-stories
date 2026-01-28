@testable import MusicStoryRenderer
import Foundation

final class InMemoryLastFMSessionStore: LastFMSessionStoring {
    private var session: LastFMSession?

    func load() -> LastFMSession? {
        session
    }

    func save(_ session: LastFMSession) {
        self.session = session
    }

    func clear() {
        session = nil
    }
}

final class InMemoryLastFMScrobbleLogStore: LastFMScrobbleLogStoring {
    private var entries: [LastFMScrobbleLogEntry] = []

    func load() -> [LastFMScrobbleLogEntry] {
        entries
    }

    func save(_ entries: [LastFMScrobbleLogEntry]) {
        self.entries = entries
    }
}

final class InMemoryLastFMPendingScrobbleStore: LastFMPendingScrobbleStoring {
    private var entries: [LastFMPendingScrobble] = []

    func load() -> [LastFMPendingScrobble] {
        entries
    }

    func save(_ entries: [LastFMPendingScrobble]) {
        self.entries = entries
    }
}

final class InMemoryLastFMDedupLedgerStore: LastFMDedupLedgerStoring {
    private var entries: [LastFMDedupLedgerEntry] = []

    func load() -> [LastFMDedupLedgerEntry] {
        entries
    }

    func save(_ entries: [LastFMDedupLedgerEntry]) {
        self.entries = entries
    }

    func clear() {
        entries = []
    }
}

final class InMemoryLastFMScrobbleCandidateStore: LastFMScrobbleCandidateStoring {
    private var candidate: LastFMScrobbleCandidate?

    func load() -> LastFMScrobbleCandidate? {
        candidate
    }

    func save(_ candidate: LastFMScrobbleCandidate?) {
        self.candidate = candidate
    }
}
