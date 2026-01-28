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
    @Published private(set) var nowPlayingTrackTitle: String?
    @Published private(set) var nowPlayingAlbumTitle: String?
    @Published private(set) var nowPlayingArtistName: String?
    @Published private(set) var nowPlayingArtworkURL: URL?
    @Published private(set) var playlistCreationStatus: PlaylistCreationStatus = .idle
    @Published private(set) var playlistCreationProgress: PlaylistCreationProgress = .idle
    @Published private(set) var playlistCreationCounts: PlaylistCreationCounts = .empty
    @Published private(set) var albumProgress: AlbumPlaybackProgress?
    private let applicationPlayer: ApplicationMusicPlayer
    private let systemPlayer: SystemMusicPlayer
    private let playbackEnabled: Bool
    private let lastPlayedAlbumStore: LastPlayedAlbumStoring
    private let systemSnapshotProvider: () -> SystemPlaybackSnapshot
    private let scrobbleHandler: PlaybackScrobbleHandling?
    private let diagnosticLogger: DiagnosticLogging?
    private var pendingAction: PendingAction?
    private var isRequestingAuthorization = false
    private var playbackStatusObserver: AnyCancellable?
    private var queueObserver: AnyCancellable?
    private var activePlayer: PlaybackActivePlayer = .application
    private var playbackTickTask: Task<Void, Never>?
    private let playbackTickInterval: TimeInterval = 2
    private var isInForeground = true
    private var playlistCreationStoryID: String?
    private var playlistCreationTask: Task<Void, Never>?
    private var albumProgressContext: AlbumPlaybackContext?
    private let playlistLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MusicStoryRenderer", category: "PlaylistCreation")

    init(
        playbackEnabled: Bool = true,
        applicationPlayer: ApplicationMusicPlayer = .shared,
        systemPlayer: SystemMusicPlayer = .shared,
        lastPlayedAlbumStore: LastPlayedAlbumStoring = UserDefaultsLastPlayedAlbumStore(),
        scrobbleHandler: PlaybackScrobbleHandling? = nil,
        diagnosticLogger: DiagnosticLogging? = nil,
        systemSnapshotProvider: (() -> SystemPlaybackSnapshot)? = nil
    ) {
        self.playbackEnabled = playbackEnabled
        self.applicationPlayer = applicationPlayer
        self.systemPlayer = systemPlayer
        self.lastPlayedAlbumStore = lastPlayedAlbumStore
        self.scrobbleHandler = scrobbleHandler
        self.diagnosticLogger = diagnosticLogger
        self.systemSnapshotProvider = systemSnapshotProvider ?? {
            let currentEntry = systemPlayer.queue.currentEntry
            let (albumTitle, artistName) = AppleMusicPlaybackController.albumTitleAndArtist(from: currentEntry)
            return SystemPlaybackSnapshot(
                playbackStatus: systemPlayer.state.playbackStatus,
                playbackTime: systemPlayer.playbackTime,
                albumTitle: albumTitle,
                artistName: artistName,
                currentEntry: currentEntry
            )
        }
        refreshAuthorizationStatus()
        if playbackEnabled {
            startObservingPlayerState()
            Task { @MainActor in
                await restoreLastPlayedAlbumIfRelevant()
            }
        }
    }

    @MainActor
    deinit {
        playbackStatusObserver?.cancel()
        queueObserver?.cancel()
        playbackTickTask?.cancel()
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

    var canSkipToPreviousTrack: Bool {
        authorizationStatus.allowsPlayback && playbackState != .stopped
    }

    var canSkipToNextTrack: Bool {
        authorizationStatus.allowsPlayback && playbackState != .stopped
    }

    func play(media: StoryMediaReference, intent: PlaybackIntent?) {
        if media.type == .musicVideo {
            openInMusic(for: media)
            return
        }
        let wasQueueEmpty = queueState.nowPlaying == nil && queueState.upNext.isEmpty
        resetAlbumProgress()
        let resolvedIntent = resolveIntent(for: media, intent: intent)
        var state = queueState
        state.play(media: media, intent: resolvedIntent)
        queueState = state
        pendingAction = .play(PlaybackQueueEntry(media: media, intent: resolvedIntent))
        lastErrorMessage = nil
        nowPlayingMetadata = PlaybackNowPlayingMetadata(media: media)
        logEvent("play_requested", metadata: mediaMetadata(for: media, intent: resolvedIntent))
        if wasQueueEmpty {
            logEvent("queue_started", metadata: mediaMetadata(for: media, intent: resolvedIntent))
        }

        guard authorizationStatus.allowsPlayback else {
            needsAuthorizationPrompt = true
            setPlaybackState(.stopped)
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
        logEvent("queue_enqueued", metadata: mediaMetadata(for: media, intent: resolvedIntent))

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

    func skipToPreviousTrack() {
        guard authorizationStatus.allowsPlayback else {
            needsAuthorizationPrompt = true
            return
        }
        guard playbackEnabled else {
            return
        }
        logEvent("playback_skip_previous")
        Task { @MainActor in
            await skipToPreviousEntry()
        }
    }

    func skipToNextTrack() {
        guard authorizationStatus.allowsPlayback else {
            needsAuthorizationPrompt = true
            return
        }
        guard playbackEnabled else {
            return
        }
        logEvent("playback_skip_next")
        Task { @MainActor in
            await skipToNextEntry()
        }
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
        setPlaybackState(.loading)
        do {
            let queues = try await makePlaybackTarget(for: media, intent: intent)
            try await startMusicKitPlayback(with: queues)
            setPlaybackState(.playing)
            persistLastPlayedAlbumIfNeeded(for: media)
            logEvent("playback_started", metadata: mediaMetadata(for: media, intent: intent))
        } catch {
            setPlaybackState(.stopped)
            lastErrorMessage = error.localizedDescription
            logEvent(
                "playback_failed",
                message: error.localizedDescription,
                metadata: mediaMetadata(for: media, intent: intent)
            )
        }
    }

    private func resumePlayback() async {
        guard queueState.nowPlaying != nil else {
            setPlaybackState(.stopped)
            return
        }
        setPlaybackState(.loading)
        switch activePlayer {
        case .application:
            do {
                try await applicationPlayer.play()
                setPlaybackState(.playing)
                logEvent("playback_resumed", metadata: playbackMetadata())
            } catch {
                setPlaybackState(.stopped)
                lastErrorMessage = error.localizedDescription
                logEvent("playback_failed", message: error.localizedDescription, metadata: playbackMetadata())
            }
        case .system:
            do {
                try await systemPlayer.play()
                setPlaybackState(.playing)
                logEvent("playback_resumed", metadata: playbackMetadata())
            } catch {
                setPlaybackState(.stopped)
                lastErrorMessage = error.localizedDescription
                logEvent("playback_failed", message: error.localizedDescription, metadata: playbackMetadata())
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
        setPlaybackState(.paused)
        logEvent("playback_paused", metadata: playbackMetadata())
    }

    private func persistLastPlayedAlbumIfNeeded(for media: StoryMediaReference) {
        guard media.type == .album,
              let appleMusicId = sanitizedAppleMusicID(media.appleMusicId)
        else {
            return
        }
        let mediaKey = persistedAlbumKey(for: appleMusicId)
        let state = LastPlayedAlbumState(
            mediaKey: mediaKey,
            appleMusicId: appleMusicId,
            title: media.title,
            artist: media.artist,
            artworkURL: media.artworkURL,
            savedAt: Date()
        )
        lastPlayedAlbumStore.save(state)
    }

    func restoreLastPlayedAlbumIfRelevant() async {
        guard queueState.nowPlaying == nil else {
            return
        }
        guard authorizationStatus.allowsPlayback else {
            return
        }
        guard let stored = lastPlayedAlbumStore.load() else {
            return
        }
        let snapshot = systemSnapshotProvider()
        guard systemNowPlayingMatchesStoredAlbum(stored, snapshot: snapshot) else {
            lastPlayedAlbumStore.clear()
            return
        }
        let media = makePersistedAlbumReference(from: stored)
        queueState = PlaybackQueueState(nowPlaying: PlaybackQueueEntry(media: media, intent: .full))
        nowPlayingMetadata = PlaybackNowPlayingMetadata(media: media)
        updateActivePlayer(.system)
        syncWithSystemPlayerState(using: snapshot)
        await restoreAlbumProgressContextIfNeeded(for: stored, snapshot: snapshot)
    }

    private func systemNowPlayingMatchesStoredAlbum(
        _ stored: LastPlayedAlbumState,
        snapshot: SystemPlaybackSnapshot
    ) -> Bool {
        guard let albumTitle = snapshot.albumTitle,
              let artistName = snapshot.artistName
        else {
            return false
        }
        return matchesStoredAlbum(title: albumTitle, artist: artistName, stored: stored)
    }

    private func matchesStoredAlbum(title: String?, artist: String?, stored: LastPlayedAlbumState) -> Bool {
        guard let title, let artist else {
            return false
        }
        return title == stored.title && artist == stored.artist
    }

    private func makePersistedAlbumReference(from stored: LastPlayedAlbumState) -> StoryMediaReference {
        StoryMediaReference(
            key: stored.mediaKey,
            type: .album,
            appleMusicId: stored.appleMusicId,
            title: stored.title,
            artist: stored.artist,
            artworkURL: stored.artworkURL,
            durationMilliseconds: nil
        )
    }

    private func syncWithSystemPlayerState(using snapshot: SystemPlaybackSnapshot? = nil) {
        let snapshot = snapshot ?? systemSnapshotProvider()
        setPlaybackState(mapPlaybackState(snapshot.playbackStatus))
        updateNowPlayingDetails(currentEntry: snapshot.currentEntry)
        updateAlbumProgress(playbackTime: snapshot.playbackTime, currentEntry: snapshot.currentEntry)
    }

    func handleAppForeground() {
        isInForeground = true
        if playbackEnabled {
            startObservingPlayerState()
        }
        syncWithActivePlayerState()
        let queue = currentPlayerQueue()
        emitPlaybackSnapshot(reason: .foreground, currentEntry: queue.currentEntry)
    }

    func handleAppBackground() {
        isInForeground = false
        stopPlaybackTick()
        let queue = currentPlayerQueue()
        emitPlaybackSnapshot(reason: .background, currentEntry: queue.currentEntry)
    }

    private func syncWithActivePlayerState() {
        let state = currentPlayerState()
        let queue = currentPlayerQueue()
        setPlaybackState(mapPlaybackState(state.playbackStatus))
        updateNowPlayingDetails(currentEntry: queue.currentEntry)
        updateAlbumProgress(playbackTime: currentPlaybackTime(), currentEntry: queue.currentEntry)
    }

    private func restoreAlbumProgressContextIfNeeded(
        for stored: LastPlayedAlbumState,
        snapshot: SystemPlaybackSnapshot
    ) async {
        guard albumProgressContext == nil,
              let rawIdentifier = sanitizedAppleMusicID(stored.appleMusicId)
        else {
            return
        }
        do {
            let identifier = MusicItemID(rawIdentifier)
            _ = try await fetchAlbum(matching: identifier)
            updateAlbumProgress(playbackTime: snapshot.playbackTime, currentEntry: snapshot.currentEntry)
        } catch {
            return
        }
    }

    private static func albumTitleAndArtist(
        from entry: MusicKit.MusicPlayer.Queue.Entry?
    ) -> (String?, String?) {
        guard let entry else {
            return (nil, nil)
        }
        switch entry.item {
        case .none:
            return (nil, nil)
        case let .some(item):
            switch item {
            case let .song(song):
                return (song.albumTitle, song.artistName)
            case let .musicVideo(video):
                return (video.albumTitle, video.artistName)
            @unknown default:
                return (nil, nil)
            }
        }
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
                let nextState = self.mapPlaybackState(playerState.playbackStatus)
                self.setPlaybackState(nextState)
                self.updateAlbumProgress(playbackTime: self.currentPlaybackTime(), currentEntry: playerQueue.currentEntry)
                self.emitPlaybackSnapshot(reason: .stateChange, currentEntry: playerQueue.currentEntry)
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
                self.updateNowPlayingDetails(currentEntry: playerQueue.currentEntry)
                self.updateAlbumProgress(playbackTime: self.currentPlaybackTime(), currentEntry: playerQueue.currentEntry)
                self.emitPlaybackSnapshot(reason: .queueChange, currentEntry: playerQueue.currentEntry)
            }
        }
    }

    private func emitPlaybackSnapshot(reason: PlaybackSnapshotReason, currentEntry: MusicKit.MusicPlayer.Queue.Entry?) {
        let snapshot = makePlaybackSnapshot(currentEntry: currentEntry, reason: reason)
        logEvent("playback_snapshot", metadata: playbackSnapshotMetadata(for: snapshot))
        guard let scrobbleHandler else {
            return
        }
        scrobbleHandler.handlePlaybackSnapshot(snapshot)
    }

    private func makePlaybackSnapshot(
        currentEntry: MusicKit.MusicPlayer.Queue.Entry?,
        reason: PlaybackSnapshotReason
    ) -> PlaybackSnapshot {
        PlaybackSnapshot(
            track: makePlaybackTrack(from: currentEntry),
            playbackState: playbackState,
            playbackTime: currentPlaybackTime(),
            reason: reason,
            activePlayer: activePlayer,
            timestamp: Date(),
            intent: queueState.nowPlaying?.intent
        )
    }

    private func playbackSnapshotMetadata(for snapshot: PlaybackSnapshot) -> [String: String] {
        var metadata: [String: String] = [
            "reason": snapshot.reason.rawValue,
            "active_player": snapshot.activePlayer.rawValue,
            "playback_state": snapshot.playbackState.rawValue,
            "playback_time": String(format: "%.3f", snapshot.playbackTime),
        ]
        if let intent = snapshot.intent {
            metadata["intent"] = intent.usePreview ? "preview" : "full"
        }
        if let track = snapshot.track {
            metadata["track_title"] = track.title
            metadata["track_artist"] = track.artist
            if let album = track.album {
                metadata["track_album"] = album
            }
            if let identifier = track.identifier, identifier.isEmpty == false {
                metadata["track_id"] = identifier
            }
            if let duration = track.duration {
                metadata["track_duration"] = String(format: "%.3f", duration)
            }
        }
        return metadata
    }

    private func makePlaybackTrack(from currentEntry: MusicKit.MusicPlayer.Queue.Entry?) -> PlaybackTrack? {
        guard let currentEntry else {
            return nil
        }
        switch currentEntry.item {
        case .none:
            return nil
        case let .some(item):
            switch item {
            case let .song(song):
                return PlaybackTrack(
                    identifier: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    album: song.albumTitle,
                    duration: song.duration
                )
            case .musicVideo:
                return nil
            @unknown default:
                return nil
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

    private func currentPlaybackTime() -> TimeInterval {
        switch activePlayer {
        case .application:
            return applicationPlayer.playbackTime
        case .system:
            return systemPlayer.playbackTime
        }
    }

    private func currentPlayerState() -> MusicKit.MusicPlayer.State {
        switch activePlayer {
        case .application:
            return applicationPlayer.state
        case .system:
            return systemPlayer.state
        }
    }

    private func currentPlayerQueue() -> MusicKit.MusicPlayer.Queue {
        switch activePlayer {
        case .application:
            return applicationPlayer.queue
        case .system:
            return systemPlayer.queue
        }
    }

    private func setPlaybackState(_ nextState: PlaybackState) {
        if playbackState != nextState {
            playbackState = nextState
        }
        updatePlaybackTicking()
    }

    private func updatePlaybackTicking() {
        guard playbackEnabled else {
            stopPlaybackTick()
            return
        }
        if playbackState == .playing, isInForeground {
            startPlaybackTickIfNeeded()
        } else {
            stopPlaybackTick()
        }
    }

    private func startPlaybackTickIfNeeded() {
        guard playbackTickTask == nil else {
            return
        }
        let clampedInterval = max(1.0, min(playbackTickInterval, 5.0))
        let nanoseconds = UInt64(clampedInterval * 1_000_000_000)
        playbackTickTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    break
                }
                if Task.isCancelled {
                    break
                }
                guard self.playbackState == .playing, self.isInForeground else {
                    continue
                }
                self.handlePlaybackTick()
            }
        }
    }

    private func stopPlaybackTick() {
        playbackTickTask?.cancel()
        playbackTickTask = nil
    }

    private func handlePlaybackTick() {
        let queue = currentPlayerQueue()
        updateAlbumProgress(playbackTime: currentPlaybackTime(), currentEntry: queue.currentEntry)
        emitPlaybackSnapshot(reason: .tick, currentEntry: queue.currentEntry)
    }

    private func updateAlbumProgressContext(from album: Album) {
        guard let context = AlbumPlaybackContext(album: album) else {
            albumProgressContext = nil
            albumProgress = nil
            return
        }
        albumProgressContext = context
        albumProgress = AlbumPlaybackProgress(played: 0, total: context.totalDuration)
    }

    private func updateAlbumProgress(playbackTime: TimeInterval, currentEntry: MusicKit.MusicPlayer.Queue.Entry?) {
        guard queueState.nowPlaying?.media.type == .album else {
            albumProgress = nil
            return
        }
        guard let context = albumProgressContext,
              let currentEntry,
              let trackID = currentEntryItemID(currentEntry),
              let index = context.index(for: trackID)
        else {
            albumProgress = nil
            return
        }
        if let mediaID = queueState.nowPlaying?.media.appleMusicId,
           mediaID != context.albumID.rawValue {
            albumProgress = nil
            return
        }
        let priorDuration = context.durationBeforeIndex(index)
        let currentDuration = context.tracks[index].duration
        let clampedPlaybackTime = min(max(playbackTime, 0), currentDuration)
        let played = priorDuration + clampedPlaybackTime
        albumProgress = AlbumPlaybackProgress(played: played, total: context.totalDuration)
    }

    private func updateNowPlayingDetails(currentEntry: MusicKit.MusicPlayer.Queue.Entry?) {
        guard let currentEntry else {
            nowPlayingTrackTitle = nil
            nowPlayingAlbumTitle = nil
            nowPlayingArtistName = nil
            nowPlayingArtworkURL = nil
            return
        }
        let artworkURL = currentEntry.artwork?.url(width: 640, height: 640)
        nowPlayingArtworkURL = artworkURL
        switch currentEntry.item {
        case .none:
            nowPlayingTrackTitle = nil
            nowPlayingAlbumTitle = nil
            nowPlayingArtistName = nil
        case let .some(item):
            switch item {
            case let .song(song):
                nowPlayingTrackTitle = song.title
                nowPlayingAlbumTitle = song.albumTitle
                nowPlayingArtistName = song.artistName
            case let .musicVideo(video):
                nowPlayingTrackTitle = video.title
                nowPlayingAlbumTitle = video.albumTitle
                nowPlayingArtistName = video.artistName
            @unknown default:
                nowPlayingTrackTitle = nil
                nowPlayingAlbumTitle = nil
                nowPlayingArtistName = nil
            }
        }
    }

    private func skipToPreviousEntry() async {
        setPlaybackState(.loading)
        do {
            switch activePlayer {
            case .application:
                try await applicationPlayer.skipToPreviousEntry()
            case .system:
                try await systemPlayer.skipToPreviousEntry()
            }
            setPlaybackState(.playing)
        } catch {
            setPlaybackState(.stopped)
            lastErrorMessage = error.localizedDescription
        }
    }

    private func skipToNextEntry() async {
        setPlaybackState(.loading)
        do {
            switch activePlayer {
            case .application:
                try await applicationPlayer.skipToNextEntry()
            case .system:
                try await systemPlayer.skipToNextEntry()
            }
            setPlaybackState(.playing)
        } catch {
            setPlaybackState(.stopped)
            lastErrorMessage = error.localizedDescription
        }
    }

    private func currentEntryItemID(_ entry: MusicKit.MusicPlayer.Queue.Entry) -> MusicItemID? {
        switch entry.item {
        case .none:
            return nil
        case let .some(item):
            switch item {
            case let .song(song):
                return song.id
            case let .musicVideo(video):
                return video.id
            @unknown default:
                return nil
            }
        }
    }

    private func resetAlbumProgress() {
        albumProgressContext = nil
        albumProgress = nil
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
        var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: identifier)
        request.properties = [.tracks]
        let response = try await request.response()
        guard let item = response.items.first else {
            throw PlaybackError.missingCatalogItem
        }
        updateAlbumProgressContext(from: item)
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

    private func updateActivePlayer(_ nextPlayer: PlaybackActivePlayer) {
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
        logEvent("playback_open_in_music", metadata: mediaMetadata(for: target, intent: nil))
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
            logEvent(
                "playlist_creation_failed",
                message: "No Apple Music items found in this story.",
                metadata: playlistMetadata(for: document, totalCount: 0)
            )
            return
        }
        guard authorizationStatus.allowsPlayback else {
            needsAuthorizationPrompt = true
            playlistCreationStatus = .failed(message: "Sign in to Apple Music to create playlists.")
            playlistCreationProgress = .idle
            playlistCreationCounts = .empty
            logEvent(
                "playlist_creation_failed",
                message: "Authorization required",
                metadata: playlistMetadata(for: document, totalCount: document.media.count)
            )
            return
        }

        playlistCreationStatus = .creating
        playlistCreationProgress = .collectingItems
        playlistCreationCounts = .empty
        playlistLogger.info("Starting playlist creation for story \(document.id, privacy: .public)")
        logEvent("playlist_creation_started", metadata: playlistMetadata(for: document, totalCount: document.media.count))
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
        logEvent("playlist_creation_cancelled")
    }

    func playlistStatus(for document: StoryDocument) -> PlaylistCreationStatus {
        guard playlistCreationStoryID == document.id else {
            return .idle
        }
        return playlistCreationStatus
    }

    private struct AlbumPlaybackContext {
        let albumID: MusicItemID
        let tracks: [AlbumTrackDuration]
        let totalDuration: TimeInterval

        init?(album: Album) {
            guard let tracks = album.tracks, tracks.isEmpty == false else {
                return nil
            }
            let durations = tracks.compactMap { track -> AlbumTrackDuration? in
                let duration = track.duration ?? 0
                guard duration > 0 else {
                    return nil
                }
                return AlbumTrackDuration(id: track.id, duration: duration)
            }
            guard durations.isEmpty == false else {
                return nil
            }
            let total = durations.reduce(0) { $0 + $1.duration }
            guard total > 0 else {
                return nil
            }
            albumID = album.id
            self.tracks = durations
            totalDuration = total
        }

        func index(for trackID: MusicItemID) -> Int? {
            tracks.firstIndex { $0.id == trackID }
        }

        func durationBeforeIndex(_ index: Int) -> TimeInterval {
            guard index > 0 else {
                return 0
            }
            return tracks.prefix(index).reduce(0) { $0 + $1.duration }
        }
    }

    private struct AlbumTrackDuration {
        let id: MusicItemID
        let duration: TimeInterval
    }

    struct SystemPlaybackSnapshot {
        let playbackStatus: MusicKit.MusicPlayer.PlaybackStatus
        let playbackTime: TimeInterval
        let albumTitle: String?
        let artistName: String?
        let currentEntry: MusicKit.MusicPlayer.Queue.Entry?
    }

    private enum PendingAction {
        case play(PlaybackQueueEntry)
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

    private func logEvent(_ event: String, message: String? = nil, metadata: [String: String] = [:]) {
        diagnosticLogger?.log(event: event, message: message, metadata: metadata)
    }

    private func mediaMetadata(for media: StoryMediaReference, intent: PlaybackIntent?) -> [String: String] {
        var metadata: [String: String] = [
            "media_type": media.type.displayName,
            "title": media.title,
            "artist": media.artist,
        ]
        if let appleMusicId = sanitizedAppleMusicID(media.appleMusicId) {
            metadata["apple_music_id"] = appleMusicId
        }
        if let intent {
            metadata["intent"] = intent.usePreview ? "preview" : "full"
        }
        return metadata
    }

    private func playbackMetadata() -> [String: String] {
        guard let entry = displayEntry else {
            return [:]
        }
        return mediaMetadata(for: entry.media, intent: entry.intent)
    }

    private func playlistMetadata(
        for document: StoryDocument,
        totalCount: Int,
        added: Int? = nil,
        failed: Int? = nil
    ) -> [String: String] {
        var metadata: [String: String] = [
            "story_id": document.id,
            "story_title": document.title,
            "total_count": String(totalCount),
        ]
        if let added {
            metadata["added"] = String(added)
        }
        if let failed {
            metadata["failed"] = String(failed)
        }
        return metadata
    }

    private func persistedAlbumKey(for appleMusicId: String) -> String {
        "persisted-album-\(appleMusicId)"
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

            let totalCount = items.totalCount
            playlistCreationCounts = PlaylistCreationCounts(total: totalCount, added: 0, failed: 0)

            let playlistName = playlistName(for: document)
            let description = "Created from the story \"\(document.title)\"."
            playlistCreationProgress = .creatingPlaylist
            try Task.checkCancellation()

            let playlist: Playlist
            var added = 0
            var failed = 0

            if items.songs.isEmpty {
                playlistLogger.info("Creating playlist with \(items.musicVideos.count) videos")
                playlist = try await MusicLibrary.shared.createPlaylist(
                    name: playlistName,
                    description: description,
                    authorDisplayName: nil,
                    items: items.musicVideos
                )
                added = items.musicVideos.count
            } else {
                playlistLogger.info("Creating playlist with \(items.songs.count) songs")
                playlist = try await MusicLibrary.shared.createPlaylist(
                    name: playlistName,
                    description: description,
                    authorDisplayName: nil,
                    items: items.songs
                )
                added = items.songs.count

                if items.musicVideos.isEmpty == false {
                    playlistCreationProgress = .addingItems
                    let outcome = try await addVideos(items.musicVideos, to: playlist)
                    added += outcome.added
                    failed += outcome.failed
                }
            }

            playlistLogger.info("Created playlist \(playlistName, privacy: .public)")
            playlistCreationStatus = .created(name: playlistName, url: playlist.url)
            playlistCreationProgress = .idle
            playlistCreationCounts = PlaylistCreationCounts(total: totalCount, added: added, failed: failed)
            logEvent(
                "playlist_created",
                metadata: playlistMetadata(
                    for: document,
                    totalCount: totalCount,
                    added: added,
                    failed: failed
                )
            )
        } catch is CancellationError {
            playlistCreationStatus = .failed(message: "Playlist creation cancelled.")
            playlistCreationProgress = .idle
            logEvent("playlist_creation_cancelled")
        } catch {
            playlistCreationStatus = .failed(message: error.localizedDescription)
            playlistCreationProgress = .idle
            playlistCreationCounts = .empty
            logEvent(
                "playlist_creation_failed",
                message: error.localizedDescription,
                metadata: playlistMetadata(for: document, totalCount: document.media.count)
            )
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

    private func addVideos(_ videos: [MusicVideo], to playlist: Playlist) async throws -> PlaylistCreationOutcome {
        var added = 0
        var failed = 0

        playlistLogger.info("Adding \(videos.count) videos to playlist")
        for video in videos {
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
    static let addingItems = PlaylistCreationProgress(value: 0.8, label: "Adding items")
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
