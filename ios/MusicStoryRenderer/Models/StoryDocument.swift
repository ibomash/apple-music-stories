import Foundation

struct StoryDocument: Identifiable {
    let schemaVersion: String
    let id: String
    let title: String
    let subtitle: String?
    let authors: [String]
    let editors: [String]
    let publishDate: Date
    let tags: [String]
    let locale: String?
    let heroImage: StoryHeroImage?
    let sections: [StorySection]
    let media: [StoryMediaReference]

    var mediaByKey: [String: StoryMediaReference] {
        Dictionary(media.map { reference in
            (reference.key, reference)
        }, uniquingKeysWith: { existing, _ in existing })
    }

    static func sample() -> StoryDocument {
        let publishDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 12)) ?? Date()
        let heroImage = StoryHeroImage(
            source: "https://example.com/hero.jpg",
            altText: "Alt text",
            credit: "Photographer",
        )
        let mediaReference = StoryMediaReference(
            key: "trk-01",
            type: .track,
            appleMusicId: "123456789",
            title: "Song Name",
            artist: "Artist Name",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            durationMilliseconds: 210_000,
        )
        let section = StorySection(
            id: "intro",
            title: "Opening",
            layout: "lede",
            leadMediaKey: "trk-01",
            blocks: [
                .paragraph(
                    id: "intro-paragraph",
                    text: "Welcome to a music story that blends narrative with playback.",
                ),
                .media(
                    id: "intro-media",
                    referenceKey: "trk-01",
                    intent: PlaybackIntent(autoplay: true, usePreview: false, loop: false),
                ),
            ],
        )
        return StoryDocument(
            schemaVersion: "0.1",
            id: "story-001",
            title: "Story Title",
            subtitle: "Optional dek",
            authors: ["Author Name"],
            editors: ["Editor Name"],
            publishDate: publishDate,
            tags: ["genre", "theme"],
            locale: "en-US",
            heroImage: heroImage,
            sections: [section],
            media: [mediaReference],
        )
    }
}

struct StoryHeroImage: Hashable {
    let source: String
    let altText: String
    let credit: String?
}

struct StorySection: Identifiable, Hashable {
    let id: String
    let title: String?
    let layout: String?
    let leadMediaKey: String?
    let blocks: [StoryBlock]
}

enum StoryBlock: Identifiable, Hashable {
    case paragraph(id: String, text: String)
    case media(id: String, referenceKey: String, intent: PlaybackIntent?)

    var id: String {
        switch self {
        case let .paragraph(identifier, _):
            identifier
        case let .media(identifier, _, _):
            identifier
        }
    }
}

struct StoryMediaReference: Identifiable, Hashable {
    let key: String
    let type: StoryMediaType
    let appleMusicId: String
    let title: String
    let artist: String
    let artworkURL: URL?
    let durationMilliseconds: Int?

    var id: String { key }
}

enum StoryMediaType: String, Hashable {
    case track
    case album
    case playlist
    case musicVideo

    var displayName: String {
        switch self {
        case .track:
            "Track"
        case .album:
            "Album"
        case .playlist:
            "Playlist"
        case .musicVideo:
            "Music Video"
        }
    }

    init?(storageValue: String) {
        switch storageValue.lowercased() {
        case "track":
            self = .track
        case "album":
            self = .album
        case "playlist":
            self = .playlist
        case "music-video", "musicvideo", "music_video":
            self = .musicVideo
        default:
            return nil
        }
    }
}

struct PlaybackIntent: Hashable {
    let autoplay: Bool
    let usePreview: Bool
    let loop: Bool
}

extension PlaybackIntent {
    static let preview = PlaybackIntent(autoplay: false, usePreview: true, loop: false)
    static let full = PlaybackIntent(autoplay: false, usePreview: false, loop: false)
    static let autoplay = PlaybackIntent(autoplay: true, usePreview: false, loop: false)
}

enum PlaybackAuthorizationStatus: String, Hashable {
    case notDetermined
    case denied
    case restricted
    case authorized

    var allowsPlayback: Bool {
        self == .authorized
    }

    var requiresAuthorization: Bool {
        self != .authorized
    }

    var actionTitle: String {
        switch self {
        case .authorized:
            "Apple Music Ready"
        case .restricted:
            "Apple Music Restricted"
        case .denied, .notDetermined:
            "Sign in to Apple Music"
        }
    }
}

enum PlaybackState: String, Hashable {
    case stopped
    case playing
    case paused
    case loading

    var actionSymbolName: String {
        switch self {
        case .playing, .loading:
            "pause.fill"
        case .stopped, .paused:
            "play.fill"
        }
    }

    var actionLabel: String {
        switch self {
        case .playing:
            "Pause"
        case .loading:
            "Loading"
        case .stopped, .paused:
            "Play"
        }
    }

    var statusLabel: String {
        switch self {
        case .playing:
            "Playing"
        case .paused:
            "Paused"
        case .loading:
            "Loading"
        case .stopped:
            "Stopped"
        }
    }
}

struct PlaybackNowPlayingMetadata: Hashable {
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let appleMusicId: String?
    let type: StoryMediaType?

    init(title: String, subtitle: String, artworkURL: URL?, appleMusicId: String?, type: StoryMediaType?) {
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.appleMusicId = appleMusicId
        self.type = type
    }

    init(media: StoryMediaReference) {
        title = media.title
        subtitle = media.artist
        artworkURL = media.artworkURL
        appleMusicId = media.appleMusicId
        type = media.type
    }
}

struct PlaybackQueueEntry: Identifiable, Hashable {
    let media: StoryMediaReference
    let intent: PlaybackIntent

    var id: String { media.key }
}

enum PlaybackQueueStatus: String, Hashable {
    case idle
    case queued
    case playing

    var label: String {
        switch self {
        case .idle:
            ""
        case .queued:
            "Queued"
        case .playing:
            "Now Playing"
        }
    }
}

struct PlaybackQueueState: Hashable {
    private(set) var nowPlaying: PlaybackQueueEntry?
    private(set) var upNext: [PlaybackQueueEntry]

    init(nowPlaying: PlaybackQueueEntry? = nil, upNext: [PlaybackQueueEntry] = []) {
        self.nowPlaying = nowPlaying
        self.upNext = upNext
    }

    func status(for media: StoryMediaReference) -> PlaybackQueueStatus {
        if nowPlaying?.media.key == media.key {
            return .playing
        }
        if upNext.contains(where: { $0.media.key == media.key }) {
            return .queued
        }
        return .idle
    }

    mutating func play(media: StoryMediaReference, intent: PlaybackIntent?) {
        let entry = PlaybackQueueEntry(media: media, intent: resolvedIntent(intent))
        nowPlaying = entry
        upNext.removeAll { $0.media.key == media.key }
    }

    mutating func enqueue(media: StoryMediaReference, intent: PlaybackIntent?) {
        if nowPlaying?.media.key == media.key {
            return
        }
        if upNext.contains(where: { $0.media.key == media.key }) {
            return
        }
        upNext.append(PlaybackQueueEntry(media: media, intent: resolvedIntent(intent)))
    }

    private func resolvedIntent(_ intent: PlaybackIntent?) -> PlaybackIntent {
        intent ?? .preview
    }
}
