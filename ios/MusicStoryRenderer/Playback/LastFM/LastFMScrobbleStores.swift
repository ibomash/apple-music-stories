import Foundation

protocol LastFMScrobbleLogStoring {
    func load() -> [LastFMScrobbleLogEntry]
    func save(_ entries: [LastFMScrobbleLogEntry])
}

protocol LastFMPendingScrobbleStoring {
    func load() -> [LastFMPendingScrobble]
    func save(_ entries: [LastFMPendingScrobble])
}

protocol LastFMDedupLedgerStoring {
    func load() -> [LastFMDedupLedgerEntry]
    func save(_ entries: [LastFMDedupLedgerEntry])
    func clear()
}

protocol LastFMScrobbleCandidateStoring {
    func load() -> LastFMScrobbleCandidate?
    func save(_ candidate: LastFMScrobbleCandidate?)
}

struct UserDefaultsLastFMScrobbleLogStore: LastFMScrobbleLogStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "lastfm-scrobble-log") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [LastFMScrobbleLogEntry] {
        decode([LastFMScrobbleLogEntry].self) ?? []
    }

    func save(_ entries: [LastFMScrobbleLogEntry]) {
        encode(entries)
    }

    private func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct UserDefaultsLastFMPendingScrobbleStore: LastFMPendingScrobbleStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "lastfm-scrobble-pending") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [LastFMPendingScrobble] {
        decode([LastFMPendingScrobble].self) ?? []
    }

    func save(_ entries: [LastFMPendingScrobble]) {
        encode(entries)
    }

    private func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct UserDefaultsLastFMDedupLedgerStore: LastFMDedupLedgerStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "lastfm-scrobble-ledger") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [LastFMDedupLedgerEntry] {
        decode([LastFMDedupLedgerEntry].self) ?? []
    }

    func save(_ entries: [LastFMDedupLedgerEntry]) {
        encode(entries)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct UserDefaultsLastFMScrobbleCandidateStore: LastFMScrobbleCandidateStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "lastfm-scrobble-candidate") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> LastFMScrobbleCandidate? {
        decode(LastFMScrobbleCandidate.self)
    }

    func save(_ candidate: LastFMScrobbleCandidate?) {
        guard let candidate else {
            defaults.removeObject(forKey: key)
            return
        }
        encode(candidate)
    }

    private func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
