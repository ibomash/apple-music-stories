import Foundation

struct PlaybackTrack: Hashable {
    let identifier: String?
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval?
}

enum PlaybackSnapshotReason: String, Hashable {
    case stateChange
    case queueChange
    case tick
    case foreground
    case background
}

enum PlaybackActivePlayer: String, Hashable {
    case application
    case system
}

struct PlaybackSnapshot: Hashable {
    let track: PlaybackTrack?
    let playbackState: PlaybackState
    let playbackTime: TimeInterval
    let reason: PlaybackSnapshotReason
    let activePlayer: PlaybackActivePlayer
    let timestamp: Date
    let intent: PlaybackIntent?
}

@MainActor
protocol PlaybackScrobbleHandling: AnyObject {
    func handlePlaybackSnapshot(_ snapshot: PlaybackSnapshot)
}
