import Combine
import Foundation
import MediaPlayer
@preconcurrency import MusicKit
import os

@MainActor
final class AppleMusicPlaybackController: ObservableObject {
    @Published private(set) var queueState = PlaybackQueueState()
    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var authorizationStatus: PlaybackAuthorizationStatus = .notDetermined
    @Published private(set) var needsAuthorizationPrompt = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var nowPlayingMetadata: PlaybackNowPlayingMetadata?
    @Published private(set) var playlistCreationStatus: PlaylistCreationStatus = .idle
    @Published private(set) var playlistCreationProgress: PlaylistCreationProgress = .idle
    @Published private(set) var playlistCreationCounts: PlaylistCreationCounts = .empty
    private let applicationPlayer: ApplicationMusicPlayer
    private let systemPlayer: SystemMusicPlayer
    private let playbackEnabled: Bool
    private var pendingAction: PendingAction?
    private var isRequestingAuthorization = false
    private var playbackStatusObserver: AnyCancellable?
    private var queueObserver: AnyCancellable?
    private var activePlayer: ActivePlayer = .application
    private var playlistCreationStoryID: String?
    private var playlistCreationTask: Task<Void, Never>?
    private let playlistLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MusicStoryRenderer", category: "PlaylistCreation")

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
        guard let rawIdentifier = sanitizedAppleMusicID(media.appleMusicId) else {
            throw PlaybackError.missingAppleMusicID
        }
        let identifier = MusicItemID(rawIdentifier)
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
        guard let identifier = sanitizedAppleMusicID(target.appleMusicId) else {
            lastErrorMessage = "Missing Apple Music identifier for this item."
            return
        }
        let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: [identifier])
        MPMusicPlayerController.systemMusicPlayer.openToPlay(descriptor)
    }

    func createPlaylist(from document: StoryDocument) {
        playlistCreationStoryID = document.id
        guard playlistCreationStatus != .creating else {
            return
        }
        guard document.media.isEmpty == false else {
            playlistCreationStatus = .failed(message: "No Apple Music items found in this story.")
            playlistCreationProgress = .idle
            return
        }
        guard authorizationStatus.allowsPlayback else {
            needsAuthorizationPrompt = true
            playlistCreationStatus = .failed(message: "Sign in to Apple Music to create playlists.")
            playlistCreationProgress = .idle
            playlistCreationCounts = .empty
            return
        }

        playlistCreationStatus = .creating
        playlistCreationProgress = .collectingItems
        playlistCreationCounts = .empty
        playlistLogger.info("Starting playlist creation for story \(document.id, privacy: .public)")
        playlistCreationTask?.cancel()
        playlistCreationTask = Task { @MainActor in
            await createStoryPlaylist(for: document)
        }
    }

    func cancelPlaylistCreation() {
        guard playlistCreationStatus == .creating else {
            return
        }
        playlistLogger.info("Cancelling playlist creation")
        playlistCreationTask?.cancel()
        playlistCreationTask = nil
        playlistCreationStatus = .failed(message: "Playlist creation cancelled.")
        playlistCreationProgress = .idle
        playlistCreationCounts = .empty
    }

    func playlistStatus(for document: StoryDocument) -> PlaylistCreationStatus {
        guard playlistCreationStoryID == document.id else {
            return .idle
        }
        return playlistCreationStatus
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
        case missingAppleMusicID

        var errorDescription: String? {
            switch self {
            case .missingCatalogItem:
                "Unable to load the Apple Music item for playback."
            case .missingApplicationQueue:
                "Unable to start playback using the application music player."
            case .musicVideoExternalOnly:
                "Music videos can only be played in the Music app."
            case .missingAppleMusicID:
                "Missing Apple Music identifier for this item."
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

    private func sanitizedAppleMusicID(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    private func createStoryPlaylist(for document: StoryDocument) async {
        defer {
            playlistCreationTask = nil
        }
        do {
            let items = try await buildPlaylistItems(from: document.media)
            guard items.isEmpty == false else {
                playlistCreationStatus = .failed(message: "No playable tracks or videos found for this story.")
                playlistCreationProgress = .idle
                playlistCreationCounts = .empty
                return
            }
            playlistLogger.info("Resolved playlist items: \(items.songs.count) songs, \(items.musicVideos.count) videos")

            let playlistName = playlistName(for: document)
            let description = "Created from the story \"\(document.title)\"."
            playlistCreationProgress = .creatingPlaylist
            let playlist = try await MusicLibrary.shared.createPlaylist(
                name: playlistName,
                description: description,
                authorDisplayName: nil
            )
            playlistLogger.info("Created playlist \(playlistName, privacy: .public)")

            playlistCreationProgress = .addingItems
            playlistCreationCounts = PlaylistCreationCounts(total: items.totalCount, added: 0, failed: 0)
            let outcome = try await addItems(items, to: playlist)
            playlistLogger.info("Finished adding items to playlist")
            playlistCreationStatus = .created(name: playlistName, url: playlist.url)
            playlistCreationProgress = .idle
            playlistCreationCounts = PlaylistCreationCounts(total: items.totalCount, added: outcome.added, failed: outcome.failed)
        } catch is CancellationError {
            playlistCreationStatus = .failed(message: "Playlist creation cancelled.")
            playlistCreationProgress = .idle
        } catch {
            playlistCreationStatus = .failed(message: error.localizedDescription)
            playlistCreationProgress = .idle
            playlistCreationCounts = .empty
        }
    }

    private func buildPlaylistItems(from media: [StoryMediaReference]) async throws -> PlaylistCreationItems {
        var songs: [Song] = []
        var musicVideos: [MusicVideo] = []
        var seenSongIDs = Set<MusicItemID>()
        var seenVideoIDs = Set<MusicItemID>()
        var skippedItems = 0

        for reference in media {
            try Task.checkCancellation()
            guard let rawIdentifier = sanitizedAppleMusicID(reference.appleMusicId) else {
                skippedItems += 1
                continue
            }
            let identifier = MusicItemID(rawIdentifier)
            do {
                switch reference.type {
                case .track:
                    playlistLogger.info("Fetching track \(rawIdentifier, privacy: .public)")
                    let song = try await fetchSong(matching: identifier)
                    playlistLogger.info("Fetched track \(rawIdentifier, privacy: .public)")
                    if seenSongIDs.insert(song.id).inserted {
                        songs.append(song)
                    }
                case .album:
                    playlistLogger.info("Fetching album \(rawIdentifier, privacy: .public)")
                    let album = try await fetchAlbumWithTracks(matching: identifier)
                    playlistLogger.info("Fetched album \(rawIdentifier, privacy: .public)")
                    if let tracks = album.tracks {
                        for track in tracks {
                            switch track {
                            case let .song(song):
                                if seenSongIDs.insert(song.id).inserted {
                                    songs.append(song)
                                }
                            case let .musicVideo(video):
                                if seenVideoIDs.insert(video.id).inserted {
                                    musicVideos.append(video)
                                }
                            @unknown default:
                                break
                            }
                        }
                    }
                case .playlist:
                    playlistLogger.info("Fetching playlist \(rawIdentifier, privacy: .public)")
                    let playlist = try await fetchPlaylistWithEntries(matching: identifier)
                    playlistLogger.info("Fetched playlist \(rawIdentifier, privacy: .public)")
                    if let entries = playlist.entries {
                        for entry in entries {
                            switch entry.item {
                            case let .song(song):
                                if seenSongIDs.insert(song.id).inserted {
                                    songs.append(song)
                                }
                            case let .musicVideo(video):
                                if seenVideoIDs.insert(video.id).inserted {
                                    musicVideos.append(video)
                                }
                            case .none:
                                break
                            @unknown default:
                                break
                            }
                        }
                    }
                case .musicVideo:
                    playlistLogger.info("Fetching music video \(rawIdentifier, privacy: .public)")
                    let video = try await fetchMusicVideo(matching: identifier)
                    playlistLogger.info("Fetched music video \(rawIdentifier, privacy: .public)")
                    if seenVideoIDs.insert(video.id).inserted {
                        musicVideos.append(video)
                    }
                }
            } catch {
                playlistLogger.error("Failed to fetch \(reference.type.displayName, privacy: .public) \(rawIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                skippedItems += 1
                continue
            }
        }

        if skippedItems > 0 {
            playlistLogger.info("Skipped \(skippedItems) media entries during playlist build")
        }

        return PlaylistCreationItems(songs: songs, musicVideos: musicVideos)
    }

    private func addItems(_ items: PlaylistCreationItems, to playlist: Playlist) async throws -> PlaylistCreationOutcome {
        var added = 0
        var failed = 0
        let total = items.totalCount

        for song in items.songs {
            try Task.checkCancellation()
            do {
                playlistLogger.info("Adding song \(song.id.rawValue, privacy: .public)")
                try await MusicLibrary.shared.add(song, to: playlist)
                playlistLogger.info("Added song \(song.id.rawValue, privacy: .public)")
                added += 1
            } catch {
                playlistLogger.error("Failed to add song \(song.id.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
                failed += 1
            }
            playlistCreationCounts = PlaylistCreationCounts(total: total, added: added, failed: failed)
        }

        for video in items.musicVideos {
            try Task.checkCancellation()
            do {
                playlistLogger.info("Adding music video \(video.id.rawValue, privacy: .public)")
                try await MusicLibrary.shared.add(video, to: playlist)
                playlistLogger.info("Added music video \(video.id.rawValue, privacy: .public)")
                added += 1
            } catch {
                playlistLogger.error("Failed to add music video \(video.id.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
                failed += 1
            }
            playlistCreationCounts = PlaylistCreationCounts(total: total, added: added, failed: failed)
        }

        return PlaylistCreationOutcome(added: added, failed: failed)
    }

    private func playlistName(for document: StoryDocument) -> String {
        "\(document.title) Story Playlist"
    }

    private func fetchAlbumWithTracks(matching identifier: MusicItemID) async throws -> Album {
        var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: identifier)
        request.properties = [.tracks]
        let response = try await request.response()
        guard let item = response.items.first else {
            throw PlaybackError.missingCatalogItem
        }
        return item
    }

    private func fetchPlaylistWithEntries(matching identifier: MusicItemID) async throws -> Playlist {
        var request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: identifier)
        request.properties = [.entries]
        let response = try await request.response()
        guard let item = response.items.first else {
            throw PlaybackError.missingCatalogItem
        }
        return item
    }

}

enum PlaylistCreationStatus: Hashable {
    case idle
    case creating
    case created(name: String, url: URL?)
    case failed(message: String)
}

struct PlaylistCreationProgress: Hashable {
    let value: Double
    let label: String

    static let idle = PlaylistCreationProgress(value: 0, label: "")
    static let collectingItems = PlaylistCreationProgress(value: 0.2, label: "Collecting story items")
    static let creatingPlaylist = PlaylistCreationProgress(value: 0.5, label: "Creating playlist")
    static let addingItems = PlaylistCreationProgress(value: 0.8, label: "Adding tracks")
}

private struct PlaylistCreationItems {
    let songs: [Song]
    let musicVideos: [MusicVideo]

    var isEmpty: Bool {
        songs.isEmpty && musicVideos.isEmpty
    }

    var totalCount: Int {
        songs.count + musicVideos.count
    }
}

private struct PlaylistCreationOutcome: Hashable {
    let added: Int
    let failed: Int
}

struct PlaylistCreationCounts: Hashable {
    let total: Int
    let added: Int
    let failed: Int

    static let empty = PlaylistCreationCounts(total: 0, added: 0, failed: 0)

    var completed: Int {
        added + failed
    }
}
