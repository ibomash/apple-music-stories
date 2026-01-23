import AVFoundation
import Combine
import Foundation
@preconcurrency import MusicKit

@MainActor
final class AppleMusicPlaybackController: ObservableObject {
    @Published private(set) var queueState = PlaybackQueueState()
    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var authorizationStatus: PlaybackAuthorizationStatus = .notDetermined
    @Published private(set) var needsAuthorizationPrompt = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var nowPlayingMetadata: PlaybackNowPlayingMetadata?
    @Published private(set) var videoPlaybackSession: VideoPlaybackSession?

    private let systemPlayer: SystemMusicPlayer
    private let playbackEnabled: Bool
    private var pendingAction: PendingAction?
    private var isRequestingAuthorization = false
    private var playbackStatusObserver: AnyCancellable?
    private var queueObserver: AnyCancellable?
    private var activePlayer: ActivePlayer = .system
    private var lastVideoPreviewURL: URL?

    init(
        playbackEnabled: Bool = true,
        systemPlayer: SystemMusicPlayer = .shared
    ) {
        self.playbackEnabled = playbackEnabled
        self.systemPlayer = systemPlayer
        refreshAuthorizationStatus()
        if playbackEnabled {
            startObservingPlayerState()
        }
    }

    @MainActor
    deinit {
        playbackStatusObserver?.cancel()
        queueObserver?.cancel()
    }

    var shouldShowPlaybackBar: Bool {
        needsAuthorizationPrompt || playbackState != .stopped || queueState.nowPlaying != nil || queueState.upNext
            .isEmpty == false
    }

    var displayEntry: PlaybackQueueEntry? {
        queueState.nowPlaying ?? queueState.upNext.first
    }

    var displayMetadata: PlaybackNowPlayingMetadata? {
        nowPlayingMetadata ?? displayEntry.map { PlaybackNowPlayingMetadata(media: $0.media) }
    }

    func play(media: StoryMediaReference, intent: PlaybackIntent?) {
        let resolvedIntent = intent ?? .preview
        var state = queueState
        state.play(media: media, intent: resolvedIntent)
        queueState = state
        pendingAction = .play(PlaybackQueueEntry(media: media, intent: resolvedIntent))
        lastErrorMessage = nil
        nowPlayingMetadata = PlaybackNowPlayingMetadata(media: media)

        guard authorizationStatus.allowsPlayback else {
            needsAuthorizationPrompt = true
            playbackState = .stopped
            return
        }

        if playbackEnabled {
            Task { @MainActor in
                await startPlayback(for: media, intent: resolvedIntent)
            }
        }
    }

    func queue(media: StoryMediaReference, intent: PlaybackIntent?) {
        var state = queueState
        state.enqueue(media: media, intent: intent)
        queueState = state

        guard authorizationStatus.allowsPlayback else {
            needsAuthorizationPrompt = true
            return
        }
    }

    func togglePlayPause() {
        guard authorizationStatus.allowsPlayback else {
            needsAuthorizationPrompt = true
            return
        }

        switch playbackState {
        case .playing, .loading:
            pausePlayback()
        case .paused, .stopped:
            if playbackEnabled {
                Task { @MainActor in
                    await resumePlayback()
                }
            }
        }
    }

    func playNextInQueue() {
        guard let nextEntry = queueState.upNext.first else {
            return
        }
        play(media: nextEntry.media, intent: nextEntry.intent)
    }

    func requestAuthorization() {
        guard isRequestingAuthorization == false else {
            return
        }
        isRequestingAuthorization = true
        Task { @MainActor in
            let status = await MusicAuthorization.request()
            updateAuthorizationStatus(status)
            isRequestingAuthorization = false
        }
    }

    private func refreshAuthorizationStatus() {
        updateAuthorizationStatus(MusicAuthorization.currentStatus)
    }

    func updateAuthorizationStatus(_ status: MusicAuthorization.Status) {
        authorizationStatus = mapAuthorizationStatus(status)
        if authorizationStatus.allowsPlayback {
            needsAuthorizationPrompt = false
            if let pendingAction {
                switch pendingAction {
                case let .play(entry):
                    if playbackEnabled {
                        Task { @MainActor in
                            await startPlayback(for: entry.media, intent: entry.intent)
                        }
                    }
                }
                self.pendingAction = nil
            }
        }
    }

    private func mapAuthorizationStatus(_ status: MusicAuthorization.Status) -> PlaybackAuthorizationStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private func startPlayback(for media: StoryMediaReference, intent _: PlaybackIntent) async {
        playbackState = .loading
        do {
            let target = try await makePlaybackTarget(for: media)
            switch target {
            case let .musicKit(queue):
                updateActivePlayer(.system)
                systemPlayer.queue = queue
                try await systemPlayer.play()
                configureVideoPlayback(for: media, previewURL: nil)
            case let .video(previewURL):
                updateActivePlayer(.video)
                configureVideoPlayback(for: media, previewURL: previewURL)
            }
            playbackState = .playing
        } catch {
            playbackState = .stopped
            lastErrorMessage = error.localizedDescription
        }
    }

    private func resumePlayback() async {
        guard queueState.nowPlaying != nil else {
            playbackState = .stopped
            return
        }
        playbackState = .loading
        switch activePlayer {
        case .system:
            do {
                try await systemPlayer.play()
                playbackState = .playing
            } catch {
                playbackState = .stopped
                lastErrorMessage = error.localizedDescription
            }
        case .video:
            videoPlaybackSession?.player.play()
            playbackState = .playing
        }
    }

    private func pausePlayback() {
        switch activePlayer {
        case .system:
            systemPlayer.pause()
        case .video:
            videoPlaybackSession?.player.pause()
        }
        playbackState = .paused
    }

    private func startObservingPlayerState() {
        playbackStatusObserver?.cancel()
        queueObserver?.cancel()
        guard activePlayer == .system else {
            return
        }
        playbackStatusObserver = systemPlayer.state.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            Task { @MainActor in
                self.playbackState = self.mapPlaybackState(self.systemPlayer.state.playbackStatus)
            }
        }
        queueObserver = systemPlayer.queue.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            Task { @MainActor in
                let metadata = self.makeMetadata()
                if metadata != self.nowPlayingMetadata {
                    self.nowPlayingMetadata = metadata
                }
            }
        }
    }

    private func mapPlaybackState(_ status: MusicKit.MusicPlayer.PlaybackStatus) -> PlaybackState {
        switch status {
        case .playing:
            return .playing
        case .paused:
            return .paused
        case .stopped:
            return .stopped
        case .interrupted:
            return .loading
        case .seekingForward, .seekingBackward:
            return .loading
        @unknown default:
            return .stopped
        }
    }

    private func makeMetadata() -> PlaybackNowPlayingMetadata? {
        displayEntry.map { PlaybackNowPlayingMetadata(media: $0.media) }
    }

    private func makePlaybackTarget(for media: StoryMediaReference) async throws -> PlaybackTarget {
        let identifier = MusicItemID(media.appleMusicId)
        switch media.type {
        case .track:
            let song = try await fetchSong(matching: identifier)
            return .musicKit(queue: MusicKit.MusicPlayer.Queue(for: [song]))
        case .album:
            let album = try await fetchAlbum(matching: identifier)
            return .musicKit(queue: MusicKit.MusicPlayer.Queue(for: [album]))
        case .playlist:
            let playlist = try await fetchPlaylist(matching: identifier)
            return .musicKit(queue: MusicKit.MusicPlayer.Queue(for: [playlist]))
        case .musicVideo:
            let video = try await fetchMusicVideo(matching: identifier)
            let previewURL = video.previewAssets?.compactMap { $0.hlsURL ?? $0.url }.first
            guard let previewURL else {
                throw PlaybackError.missingVideoPreview
            }
            return .video(previewURL: previewURL)
        }
    }

    private func fetchSong(matching identifier: MusicItemID) async throws -> Song {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: identifier)
        let response = try await request.response()
        guard let item = response.items.first else {
            throw PlaybackError.missingCatalogItem
        }
        return item
    }

    private func fetchAlbum(matching identifier: MusicItemID) async throws -> Album {
        let request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: identifier)
        let response = try await request.response()
        guard let item = response.items.first else {
            throw PlaybackError.missingCatalogItem
        }
        return item
    }

    private func fetchPlaylist(matching identifier: MusicItemID) async throws -> Playlist {
        let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: identifier)
        let response = try await request.response()
        guard let item = response.items.first else {
            throw PlaybackError.missingCatalogItem
        }
        return item
    }

    private func fetchMusicVideo(matching identifier: MusicItemID) async throws -> MusicVideo {
        let request = MusicCatalogResourceRequest<MusicVideo>(matching: \.id, equalTo: identifier)
        let response = try await request.response()
        guard let item = response.items.first else {
            throw PlaybackError.missingCatalogItem
        }
        return item
    }

    private func updateActivePlayer(_ nextPlayer: ActivePlayer) {
        guard activePlayer != nextPlayer else {
            return
        }
        activePlayer = nextPlayer
        if playbackEnabled {
            startObservingPlayerState()
        }
    }

    private func configureVideoPlayback(for media: StoryMediaReference, previewURL: URL?) {
        guard media.type == .musicVideo else {
            lastVideoPreviewURL = nil
            dismissVideoPlayback()
            return
        }
        lastVideoPreviewURL = previewURL
        guard let previewURL else {
            return
        }
        startVideoPlayback(with: previewURL)
    }

    private func startVideoPlayback(with url: URL) {
        let player = AVPlayer(url: url)
        videoPlaybackSession = VideoPlaybackSession(player: player)
    }

    func presentVideoPlayback() {
        guard let lastVideoPreviewURL else {
            return
        }
        startVideoPlayback(with: lastVideoPreviewURL)
    }

    func dismissVideoPlayback() {
        videoPlaybackSession?.player.pause()
        videoPlaybackSession = nil
    }

    private enum PlaybackTarget {
        case musicKit(queue: MusicKit.MusicPlayer.Queue)
        case video(previewURL: URL)
    }

    private enum PendingAction {
        case play(PlaybackQueueEntry)
    }

    private enum ActivePlayer {
        case system
        case video
    }

    private enum PlaybackError: LocalizedError {
        case missingCatalogItem
        case missingVideoPreview

        var errorDescription: String? {
            switch self {
            case .missingCatalogItem:
                "Unable to load the Apple Music item for playback."
            case .missingVideoPreview:
                "This music video does not provide a preview stream."
            }
        }
    }
}

final class VideoPlaybackSession: Identifiable {
    let id = UUID()
    let player: AVPlayer

    init(player: AVPlayer) {
        self.player = player
    }
}
