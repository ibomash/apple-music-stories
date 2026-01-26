import Foundation

public struct LastPlayedAlbumState: Codable, Equatable {
    public let mediaKey: String
    public let appleMusicId: String
    public let title: String
    public let artist: String
    public let artworkURL: URL?
    public let savedAt: Date
}

public protocol LastPlayedAlbumStoring {
    func load() -> LastPlayedAlbumState?
    func save(_ state: LastPlayedAlbumState)
    func clear()
}

public struct UserDefaultsLastPlayedAlbumStore: LastPlayedAlbumStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "last-played-album") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> LastPlayedAlbumState? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(LastPlayedAlbumState.self, from: data)
        } catch {
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    public func save(_ state: LastPlayedAlbumState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
