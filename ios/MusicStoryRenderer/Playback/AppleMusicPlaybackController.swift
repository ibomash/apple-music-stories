import Combine
import Foundation
import MediaPlayer
@preconcurrency import MusicKit

@MainActor
final class AppleMusicPlaybackController: ObservableObject {
    @Published private(set) var queueState = PlaybackQueueState()
    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var authorizationStatus: PlaybackAuthorizationStatus = .notDetermined
    @Published private(set) var needsAuthorizationPrompt = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var nowPlayingMetadata: PlaybackNowPlayingMetadata?
    private let applicationPlayer: ApplicationMusicPlayer
    private let systemPlayer: SystemMusicPlayer
    private let playbackEnabled: Bool
    private var pendingAction: PendingAction?
    private var isRequestingAuthorization = false
    private var playbackStatusObserver: AnyCancellable?
    private var queueObserver: AnyCancellable?
    private var activePlayer: ActivePlayer = .application

    init(
        playbackEnabled: Bool = true,
        applicationPlayer: ApplicationMusicPlayer = .shared,
        systemPlayer: SystemMusicPlayer = .shared
    ) {
        self.playbackEnabled = playbackEnabled
        self.applicationPlayer = applicationPlayer
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
        if media.type == .musicVideo {
            openInMusic(for: media)
            return
        }
        let resolvedIntent = resolveIntent(for: media, intent: intent)
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
        if media.type == .musicVideo {
            return
        }
        let resolvedIntent = resolveIntent(for: media, intent: intent)
        var state = queueState
        state.enqueue(media: media, intent: resolvedIntent)
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
        if nextEntry.media.type == .musicVideo {
            openInMusic(for: nextEntry.media)
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

    private func startPlayback(for media: StoryMediaReference, intent: PlaybackIntent) async {
        playbackState = .loading
        do {
            let queues = try await makePlaybackTarget(for: media, intent: intent)
            try await startMusicKitPlayback(with: queues)
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
        case .application:
            do {
                try await applicationPlayer.play()
                playbackState = .playing
            } catch {
                playbackState = .stopped
                lastErrorMessage = error.localizedDescription
            }
        case .system:
            do {
                try await systemPlayer.play()
                playbackState = .playing
            } catch {
                playbackState = .stopped
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func pausePlayback() {
        switch activePlayer {
        case .application:
            applicationPlayer.pause()
        case .system:
            systemPlayer.pause()
        }
        playbackState = .paused
    }

    private func startObservingPlayerState() {
        playbackStatusObserver?.cancel()
        queueObserver?.cancel()
        let playerState: MusicKit.MusicPlayer.State
        let playerQueue: MusicKit.MusicPlayer.Queue
        switch activePlayer {
        case .application:
            playerState = applicationPlayer.state
            playerQueue = applicationPlayer.queue
        case .system:
            playerState = systemPlayer.state
            playerQueue = systemPlayer.queue
        }
        playbackStatusObserver = playerState.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            Task { @MainActor in
                self.playbackState = self.mapPlaybackState(playerState.playbackStatus)
            }
        }
        queueObserver = playerQueue.objectWillChange.sink { [weak self] in
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

    private func makePlaybackTarget(for media: StoryMediaReference, intent: PlaybackIntent) async throws -> MusicKitQueues {
        let identifier = MusicItemID(media.appleMusicId)
        switch media.type {
        case .track:
            let song = try await fetchSong(matching: identifier)
            return MusicKitQueues(
                applicationQueue: ApplicationMusicPlayer.Queue(for: [song]),
                systemQueue: MusicKit.MusicPlayer.Queue(for: [song])
            )
        case .album:
            let album = try await fetchAlbum(matching: identifier)
            return MusicKitQueues(
                applicationQueue: ApplicationMusicPlayer.Queue(for: [album]),
                systemQueue: MusicKit.MusicPlayer.Queue(for: [album])
            )
        case .playlist:
            let playlist = try await fetchPlaylist(matching: identifier)
            return MusicKitQueues(
                applicationQueue: ApplicationMusicPlayer.Queue(for: [playlist]),
                systemQueue: MusicKit.MusicPlayer.Queue(for: [playlist])
            )
        case .musicVideo:
            throw PlaybackError.musicVideoExternalOnly
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

    private func startMusicKitPlayback(with queues: MusicKitQueues) async throws {
        do {
            guard let applicationQueue = queues.applicationQueue else {
                throw PlaybackError.missingApplicationQueue
            }
            try await startApplicationPlayback(with: applicationQueue)
        } catch {
            try await startSystemPlayback(with: queues.systemQueue)
        }
    }

    private func startApplicationPlayback(with queue: ApplicationMusicPlayer.Queue) async throws {
        updateActivePlayer(.application)
        applicationPlayer.queue = queue
        try await applicationPlayer.play()
    }

    private func startSystemPlayback(with queue: MusicKit.MusicPlayer.Queue) async throws {
        updateActivePlayer(.system)
        systemPlayer.queue = queue
        try await systemPlayer.play()
    }

    func openInMusic(for media: StoryMediaReference? = nil) {
        guard let target = media ?? displayEntry?.media else {
            return
        }
        let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: [target.appleMusicId])
        MPMusicPlayerController.systemMusicPlayer.openToPlay(descriptor)
    }

    private enum PendingAction {
        case play(PlaybackQueueEntry)
    }

    private enum ActivePlayer {
        case application
        case system
    }

    private enum PlaybackError: LocalizedError {
        case missingCatalogItem
        case missingApplicationQueue
        case musicVideoExternalOnly

        var errorDescription: String? {
            switch self {
            case .missingCatalogItem:
                "Unable to load the Apple Music item for playback."
            case .missingApplicationQueue:
                "Unable to start playback using the application music player."
            case .musicVideoExternalOnly:
                "Music videos can only be played in the Music app."
            }
        }
    }

    private struct MusicKitQueues {
        let applicationQueue: ApplicationMusicPlayer.Queue?
        let systemQueue: MusicKit.MusicPlayer.Queue
    }

    private func resolveIntent(for media: StoryMediaReference, intent: PlaybackIntent?) -> PlaybackIntent {
        return intent ?? .preview
    }

}
