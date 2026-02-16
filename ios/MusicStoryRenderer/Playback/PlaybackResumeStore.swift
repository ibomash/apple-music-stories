import Foundation

public struct PlaybackResumeState: Codable, Equatable {
    public let mediaKey: String
    public let mediaType: String
    public let appleMusicId: String
    public let title: String
    public let artist: String
    public let artworkURL: URL?
    public let intentUsePreview: Bool

    // When the user starts playback from an album/playlist reference, the actual playing item
    // is typically a track. Persisting the current track + playback time makes resume resilient
    // even if the system player is not active at launch.
    public let currentTrackAppleMusicId: String?
    public let currentTrackTitle: String?
    public let currentTrackArtist: String?
    public let currentTrackAlbumTitle: String?
    public let playbackTime: TimeInterval?

    public let savedAt: Date

    public init(
        mediaKey: String,
        mediaType: String,
        appleMusicId: String,
        title: String,
        artist: String,
        artworkURL: URL?,
        intentUsePreview: Bool,
        currentTrackAppleMusicId: String?,
        currentTrackTitle: String?,
        currentTrackArtist: String?,
        currentTrackAlbumTitle: String?,
        playbackTime: TimeInterval?,
        savedAt: Date
    ) {
        self.mediaKey = mediaKey
        self.mediaType = mediaType
        self.appleMusicId = appleMusicId
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.intentUsePreview = intentUsePreview
        self.currentTrackAppleMusicId = currentTrackAppleMusicId
        self.currentTrackTitle = currentTrackTitle
        self.currentTrackArtist = currentTrackArtist
        self.currentTrackAlbumTitle = currentTrackAlbumTitle
        self.playbackTime = playbackTime
        self.savedAt = savedAt
    }
}

public protocol PlaybackResumeStoring {
    func load() -> PlaybackResumeState?
    func save(_ state: PlaybackResumeState)
    func clear()
}

public struct UserDefaultsPlaybackResumeStore: PlaybackResumeStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "playback-resume") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> PlaybackResumeState? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(PlaybackResumeState.self, from: data)
        } catch {
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    public func save(_ state: PlaybackResumeState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
