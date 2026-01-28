import Foundation

struct PlaybackTrack: Hashable {
    let identifier: String?
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval?
}

struct PlaybackSnapshot: Hashable {
    let track: PlaybackTrack?
    let playbackState: PlaybackState
    let playbackTime: TimeInterval
    let timestamp: Date
    let intent: PlaybackIntent?
}

@MainActor
protocol PlaybackScrobbleHandling: AnyObject {
    func handlePlaybackSnapshot(_ snapshot: PlaybackSnapshot)
}
