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

    private let player: SystemMusicPlayer
    private let playbackEnabled: Bool
    private var pendingAction: PendingAction?
    private var isRequestingAuthorization = false
    private var playbackStatusObserver: AnyCancellable?
    private var queueObserver: AnyCancellable?

    init(playbackEnabled: Bool = true, player: SystemMusicPlayer = .shared) {
        self.playbackEnabled = playbackEnabled
        self.player = player
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
            let queue = try await makeQueue(for: media)
            player.queue = queue
            try await player.play()
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
        do {
            try await player.play()
            playbackState = .playing
        } catch {
            playbackState = .stopped
            lastErrorMessage = error.localizedDescription
        }
    }

    private func pausePlayback() {
        player.pause()
        playbackState = .paused
    }

    private func startObservingPlayerState() {
        playbackStatusObserver?.cancel()
        playbackStatusObserver = player.state.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            Task { @MainActor in
                self.playbackState = self.mapPlaybackState(self.player.state.playbackStatus)
            }
        }

        queueObserver?.cancel()
        queueObserver = player.queue.objectWillChange.sink { [weak self] in
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

    private func mapPlaybackState(_ status: MusicPlayer.PlaybackStatus) -> PlaybackState {
        switch status {
        case .playing:
            return .playing
        case .paused:
            return .paused
        case .stopped:
            return .stopped
        case .interrupted:
            return .loading
        @unknown default:
            return .stopped
        }
    }

    private func makeMetadata() -> PlaybackNowPlayingMetadata? {
        displayEntry.map { PlaybackNowPlayingMetadata(media: $0.media) }
    }

    private func makeQueue(for media: StoryMediaReference) async throws -> MusicPlayer.Queue {
        let identifier = MusicItemID(media.appleMusicId)
        switch media.type {
        case .track:
            let song = try await fetchSong(matching: identifier)
            return MusicPlayer.Queue(for: [song])
        case .album:
            let album = try await fetchAlbum(matching: identifier)
            return MusicPlayer.Queue(for: [album])
        case .playlist:
            let playlist = try await fetchPlaylist(matching: identifier)
            return MusicPlayer.Queue(for: [playlist])
        case .musicVideo:
            throw PlaybackError.unsupportedMedia
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

    private enum PendingAction {
        case play(PlaybackQueueEntry)
    }

    private enum PlaybackError: LocalizedError {
        case missingCatalogItem
        case unsupportedMedia

        var errorDescription: String? {
            switch self {
            case .missingCatalogItem:
                "Unable to load the Apple Music item for playback."
            case .unsupportedMedia:
                "Music video playback is not supported yet."
            }
        }
    }
}
