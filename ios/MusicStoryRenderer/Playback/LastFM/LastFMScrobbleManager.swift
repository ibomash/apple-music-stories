import AuthenticationServices
import Foundation
import os
import UIKit

@MainActor
final class LastFMScrobbleManager: NSObject, ObservableObject, PlaybackScrobbleHandling {
    @Published private(set) var authState: LastFMAuthState
    @Published private(set) var logEntries: [LastFMScrobbleLogEntry]
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isConfigured: Bool

    private let configuration: LastFMConfiguration?
    private let apiClient: LastFMAPIClient?
    private let sessionStore: LastFMSessionStoring
    private let logStore: LastFMScrobbleLogStoring
    private let pendingStore: LastFMPendingScrobbleStoring
    private let ledgerStore: LastFMDedupLedgerStoring
    private let candidateStore: LastFMScrobbleCandidateStoring
    private let policy: LastFMScrobblePolicy
    private let clock: () -> Date
    private let uuidProvider: () -> UUID
    private let logger: Logger
    private let diagnosticLogger: DiagnosticLogging?
    private let maxLogEntries = 50
    private let ledgerRetentionDays = 30
    private let baseRetryDelay: TimeInterval = 30
    private let maxRetryDelay: TimeInterval = 15 * 60

    private var pendingScrobbles: [LastFMPendingScrobble]
    private var ledgerEntries: [LastFMDedupLedgerEntry]
    private var candidate: LastFMScrobbleCandidate?
    private var authSession: ASWebAuthenticationSession?
    private var pendingAuthToken: String?
    private var isFlushing = false

    init(
        configuration: LastFMConfiguration? = LastFMConfiguration.load(),
        apiClient: LastFMAPIClient? = nil,
        sessionStore: LastFMSessionStoring = KeychainLastFMSessionStore(),
        logStore: LastFMScrobbleLogStoring = UserDefaultsLastFMScrobbleLogStore(),
        pendingStore: LastFMPendingScrobbleStoring = UserDefaultsLastFMPendingScrobbleStore(),
        ledgerStore: LastFMDedupLedgerStoring = UserDefaultsLastFMDedupLedgerStore(),
        candidateStore: LastFMScrobbleCandidateStoring = UserDefaultsLastFMScrobbleCandidateStore(),
        policy: LastFMScrobblePolicy = LastFMScrobblePolicy(),
        clock: @escaping () -> Date = Date.init,
        uuidProvider: @escaping () -> UUID = UUID.init,
        diagnosticLogger: DiagnosticLogging? = nil
    ) {
        self.configuration = configuration
        if let configuration {
            self.apiClient = apiClient ?? LastFMAPIClient(configuration: configuration)
        } else {
            self.apiClient = apiClient
        }
        self.sessionStore = sessionStore
        self.logStore = logStore
        self.pendingStore = pendingStore
        self.ledgerStore = ledgerStore
        self.candidateStore = candidateStore
        self.policy = policy
        self.clock = clock
        self.uuidProvider = uuidProvider
        self.diagnosticLogger = diagnosticLogger
        self.isConfigured = configuration != nil
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MusicStoryRenderer", category: "LastFM")
        let existingSession = sessionStore.load()
        self.authState = existingSession.map { .signedIn($0) } ?? .signedOut
        self.logEntries = logStore.load()
        self.pendingScrobbles = pendingStore.load()
        self.ledgerEntries = ledgerStore.load()
        self.candidate = candidateStore.load()
        super.init()
        if let candidate {
            logCandidateEvent("scrobble_candidate_restored", candidate: candidate)
        }
        pruneLedgerIfNeeded()
    }

    var username: String? {
        authState.session?.username
    }

    func signIn() {
        guard isConfigured, let configuration, let apiClient else {
            lastErrorMessage = "Last.fm API key/secret not configured."
            return
        }
        guard authState == .signedOut else {
            return
        }
        lastErrorMessage = nil
        authState = .authorizing
        logger.info("Starting Last.fm auth")
        Task {
            do {
                let token = try await apiClient.getToken()
                pendingAuthToken = token
                guard let callbackURL = configuration.callbackURL else {
                    throw LastFMAPIError.invalidResponse
                }
                let authURL = makeAuthURL(apiKey: configuration.apiKey, token: token, callbackURL: callbackURL)
                startAuthSession(url: authURL, callbackScheme: configuration.callbackScheme)
            } catch {
                handleAuthError(error)
            }
        }
    }

    func signOut() {
        sessionStore.clear()
        authState = .signedOut
        lastErrorMessage = nil
        pendingAuthToken = nil
        pendingScrobbles.removeAll()
        pendingStore.save([])
        ledgerEntries.removeAll()
        ledgerStore.clear()
        candidate = nil
        candidateStore.save(nil)
        logger.info("Signed out of Last.fm")
    }

    func handlePlaybackSnapshot(_ snapshot: PlaybackSnapshot) {
        guard isConfigured else {
            return
        }
        if snapshot.intent?.usePreview == true {
            return
        }

        let track = snapshot.track.flatMap { track -> LastFMTrack? in
            let trimmedTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedTitle.isEmpty == false, trimmedArtist.isEmpty == false else {
                return nil
            }
            return LastFMTrack(
                identifier: track.identifier,
                title: trimmedTitle,
                artist: trimmedArtist,
                album: track.album,
                duration: track.duration
            )
        }

        if let candidate, let track {
            let candidateKey = trackKey(for: candidate.track)
            let newKey = trackKey(for: track)
            if candidateKey != newKey {
                finalizeCandidate(reason: "track-changed")
                startCandidateIfPossible(track: track, snapshot: snapshot)
                return
            }
            updateCandidate(using: snapshot)
            if snapshot.playbackState == .stopped {
                finalizeCandidate(reason: "playback-stopped")
            }
            return
        }

        if candidate != nil, track == nil {
            if snapshot.playbackState == .stopped {
                finalizeCandidate(reason: "playback-stopped")
            }
            return
        }

        if let track {
            startCandidateIfPossible(track: track, snapshot: snapshot)
        }
    }

    func flushPending(reason: LastFMFlushReason) {
        guard isConfigured, authState.session != nil else {
            return
        }
        guard pendingScrobbles.isEmpty == false else {
            return
        }
        guard isFlushing == false else {
            return
        }
        isFlushing = true
        logger.info("Flushing pending scrobbles (\(reason.rawValue, privacy: .public))")
        Task {
            await flushPendingScrobbles()
        }
    }

    private func startCandidateIfPossible(track: LastFMTrack, snapshot: PlaybackSnapshot) {
        guard snapshot.playbackState != .stopped else {
            return
        }
        let startedAt = clock().addingTimeInterval(-snapshot.playbackTime)
        var newCandidate = LastFMScrobbleCandidate(
            track: track,
            startedAt: startedAt,
            lastPlaybackTime: max(0, snapshot.playbackTime),
            lastUpdatedAt: clock(),
            didSendNowPlaying: false
        )
        if snapshot.playbackState == .playing {
            newCandidate.didSendNowPlaying = true
            sendNowPlaying(for: track)
        }
        candidate = newCandidate
        candidateStore.save(newCandidate)
        var metadata: [String: String] = [
            "snapshot_reason": snapshot.reason.rawValue,
            "playback_state": snapshot.playbackState.rawValue,
        ]
        if let intent = snapshot.intent {
            metadata["intent"] = intent.usePreview ? "preview" : "full"
        }
        logCandidateEvent("scrobble_candidate_started", candidate: newCandidate, metadata: metadata)
    }

    private func updateCandidate(using snapshot: PlaybackSnapshot) {
        guard var candidate else {
            return
        }
        candidate.lastPlaybackTime = max(candidate.lastPlaybackTime, snapshot.playbackTime)
        candidate.lastUpdatedAt = clock()
        if snapshot.playbackState == .playing, candidate.didSendNowPlaying == false {
            candidate.didSendNowPlaying = true
            sendNowPlaying(for: candidate.track)
        }
        self.candidate = candidate
        candidateStore.save(candidate)
    }

    private func finalizeCandidate(reason: String) {
        guard let candidate else {
            return
        }
        let shouldScrobble = policy.shouldScrobble(candidate: candidate)
        let playedSeconds = max(0, candidate.lastPlaybackTime)
        let thresholdSeconds = scrobbleThresholdSeconds(for: candidate)
        var metadata = candidateMetadata(for: candidate)
        metadata["finalize_reason"] = reason
        metadata["played_seconds"] = String(format: "%.3f", playedSeconds)
        metadata["threshold_seconds"] = String(format: "%.3f", thresholdSeconds)
        metadata["eligible"] = shouldScrobble ? "true" : "false"
        diagnosticLogger?.log(event: "scrobble_candidate_finalized", message: nil, metadata: metadata)
        if shouldScrobble {
            queueScrobble(candidate)
        } else {
            appendLog(for: candidate.track, status: .skipped, message: "Playback ended before scrobble threshold (\(reason))")
        }
        self.candidate = nil
        candidateStore.save(nil)
        flushPending(reason: .playbackEnded)
    }

    private func queueScrobble(_ candidate: LastFMScrobbleCandidate) {
        guard authState.session != nil else {
            appendLog(for: candidate.track, status: .skipped, message: "Sign in to Last.fm to scrobble tracks")
            return
        }
        let key = ledgerKey(for: candidate)
        if ledgerEntries.contains(where: { $0.key == key }) {
            appendLog(for: candidate.track, status: .skipped, message: "Duplicate scrobble")
            return
        }
        let pending = LastFMPendingScrobble(
            id: uuidProvider(),
            track: candidate.track,
            startedAt: candidate.startedAt,
            attempts: 0,
            lastAttemptAt: nil
        )
        Task {
            await attemptScrobble(pending, markQueuedOnFailure: true)
        }
    }

    private func attemptScrobble(_ pending: LastFMPendingScrobble, markQueuedOnFailure: Bool) async {
        guard let session = authState.session, let apiClient else {
            return
        }
        do {
            try await apiClient.scrobble(track: pending.track, startedAt: pending.startedAt, sessionKey: session.key)
            recordScrobbleSuccess(for: pending)
        } catch {
            handleScrobbleFailure(error, pending: pending, markQueuedOnFailure: markQueuedOnFailure)
        }
    }

    private func recordScrobbleSuccess(for pending: LastFMPendingScrobble) {
        let entry = LastFMDedupLedgerEntry(key: ledgerKey(for: pending), scrobbledAt: clock())
        ledgerEntries.append(entry)
        ledgerStore.save(ledgerEntries)
        pendingScrobbles.removeAll { $0.id == pending.id }
        pendingStore.save(pendingScrobbles)
        appendLog(for: pending.track, status: .scrobbled, message: nil)
        logger.info("Scrobbled \(pending.track.displayName, privacy: .public)")
    }

    private func handleScrobbleFailure(
        _ error: Error,
        pending: LastFMPendingScrobble,
        markQueuedOnFailure: Bool
    ) {
        if let apiError = error as? LastFMAPIError, apiError.isAuthError {
            appendLog(for: pending.track, status: .failed, message: apiError.errorDescription)
            signOut()
            return
        }
        let retryable = (error as? LastFMAPIError)?.isRetryable ?? true
        if retryable, markQueuedOnFailure {
            var updated = pending
            updated.attempts += 1
            updated.lastAttemptAt = clock()
            upsertPending(updated)
            appendLog(for: pending.track, status: .pending, message: (error as? LastFMAPIError)?.errorDescription)
        } else {
            appendLog(for: pending.track, status: .failed, message: (error as? LastFMAPIError)?.errorDescription)
        }
    }

    private func upsertPending(_ pending: LastFMPendingScrobble) {
        if let index = pendingScrobbles.firstIndex(where: { $0.id == pending.id }) {
            pendingScrobbles[index] = pending
        } else {
            pendingScrobbles.append(pending)
        }
        pendingStore.save(pendingScrobbles)
    }

    private func flushPendingScrobbles() async {
        defer {
            isFlushing = false
        }
        guard let session = authState.session else {
            return
        }
        let now = clock()
        let eligible = pendingScrobbles.filter { shouldAttempt($0, now: now) }
        guard eligible.isEmpty == false else {
            return
        }
        for item in eligible {
            guard authState.session?.key == session.key else {
                break
            }
            await attemptScrobble(item, markQueuedOnFailure: true)
        }
    }

    private func shouldAttempt(_ pending: LastFMPendingScrobble, now: Date) -> Bool {
        let attempts = max(0, pending.attempts)
        let delay = min(baseRetryDelay * pow(2, Double(attempts)), maxRetryDelay)
        guard let lastAttemptAt = pending.lastAttemptAt else {
            return true
        }
        return now.timeIntervalSince(lastAttemptAt) >= delay
    }

    private func sendNowPlaying(for track: LastFMTrack) {
        guard let session = authState.session, let apiClient else {
            return
        }
        Task {
            do {
                try await apiClient.updateNowPlaying(track: track, sessionKey: session.key)
                logger.info("Updated now playing for \(track.displayName, privacy: .public)")
            } catch {
                if let apiError = error as? LastFMAPIError, apiError.isAuthError {
                    appendLog(for: track, status: .failed, message: apiError.errorDescription)
                    signOut()
                } else {
                    logger.error("Failed now playing update: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func appendLog(for track: LastFMTrack, status: LastFMScrobbleStatus, message: String?) {
        let entry = LastFMScrobbleLogEntry(
            id: uuidProvider(),
            timestamp: clock(),
            trackTitle: track.title,
            artist: track.artist,
            album: track.album,
            status: status,
            message: message
        )
        var metadata = trackMetadata(for: track)
        metadata["status"] = status.rawValue
        diagnosticLogger?.log(event: "scrobble_event", message: message, metadata: metadata)
        logEntries.insert(entry, at: 0)
        if logEntries.count > maxLogEntries {
            logEntries = Array(logEntries.prefix(maxLogEntries))
        }
        logStore.save(logEntries)
    }

    private func trackMetadata(for track: LastFMTrack) -> [String: String] {
        [
            "track_title": track.title,
            "artist": track.artist,
            "album": track.album ?? "",
            "identifier": track.identifier ?? "",
        ]
    }

    private func candidateMetadata(for candidate: LastFMScrobbleCandidate) -> [String: String] {
        var metadata = trackMetadata(for: candidate.track)
        metadata["started_at"] = String(Int(candidate.startedAt.timeIntervalSince1970))
        metadata["last_updated_at"] = String(Int(candidate.lastUpdatedAt.timeIntervalSince1970))
        metadata["playback_time"] = String(format: "%.3f", candidate.lastPlaybackTime)
        metadata["did_send_now_playing"] = candidate.didSendNowPlaying ? "true" : "false"
        if let duration = candidate.track.duration {
            metadata["duration"] = String(format: "%.3f", duration)
        }
        return metadata
    }

    private func logCandidateEvent(
        _ event: String,
        candidate: LastFMScrobbleCandidate,
        metadata extraMetadata: [String: String] = [:]
    ) {
        var metadata = candidateMetadata(for: candidate)
        for (key, value) in extraMetadata {
            metadata[key] = value
        }
        diagnosticLogger?.log(event: event, message: nil, metadata: metadata)
    }

    private func scrobbleThresholdSeconds(for candidate: LastFMScrobbleCandidate) -> TimeInterval {
        let duration = candidate.track.duration ?? 0
        if duration > 0 {
            if duration >= policy.longTrackMinimumSeconds {
                return max(0, duration - policy.completionGraceSeconds)
            }
            return max(0, duration * policy.completionFraction)
        }
        return max(0, policy.fallbackMinimumSeconds)
    }

    private func trackKey(for track: LastFMTrack) -> String {
        if let identifier = track.identifier, identifier.isEmpty == false {
            return identifier
        }
        return "\(track.artist.lowercased())|\(track.title.lowercased())"
    }

    private func ledgerKey(for candidate: LastFMScrobbleCandidate) -> String {
        ledgerKey(for: candidate.track, startedAt: candidate.startedAt)
    }

    private func ledgerKey(for pending: LastFMPendingScrobble) -> String {
        ledgerKey(for: pending.track, startedAt: pending.startedAt)
    }

    private func ledgerKey(for track: LastFMTrack, startedAt: Date) -> String {
        let identifier = trackKey(for: track)
        let duration = track.duration.map { String(Int($0.rounded())) } ?? "unknown"
        return "\(identifier)|\(Int(startedAt.timeIntervalSince1970))|\(duration)|\(track.artist.lowercased())"
    }

    private func pruneLedgerIfNeeded() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -ledgerRetentionDays, to: clock())
        guard let cutoff else {
            return
        }
        let filtered = ledgerEntries.filter { $0.scrobbledAt >= cutoff }
        if filtered.count != ledgerEntries.count {
            ledgerEntries = filtered
            ledgerStore.save(filtered)
        }
    }

    private func makeAuthURL(apiKey: String, token: String, callbackURL: URL) -> URL {
        var components = URLComponents(string: "https://www.last.fm/api/auth/")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "cb", value: callbackURL.absoluteString),
        ]
        return components?.url ?? callbackURL
    }

    private func startAuthSession(url: URL, callbackScheme: String) {
        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
            guard let self else {
                return
            }
            Task { @MainActor in
                if let error {
                    if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                        if self.pendingAuthToken != nil {
                            self.exchangeSession(with: nil)
                        } else {
                            self.authState = .signedOut
                        }
                        return
                    }
                    self.handleAuthError(error)
                    return
                }
                self.exchangeSession(with: callbackURL)
            }
        }
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = true
        if authSession?.start() != true {
            handleAuthError(LastFMAPIError.invalidResponse)
        }
    }

    private func exchangeSession(with callbackURL: URL?) {
        guard let apiClient else {
            handleAuthError(LastFMAPIError.invalidResponse)
            return
        }
        let token = callbackURL.flatMap(extractToken(from:)) ?? pendingAuthToken
        guard let token else {
            handleAuthError(LastFMAPIError.invalidResponse)
            return
        }
        authState = .exchanging
        Task {
            do {
                let session = try await apiClient.getSession(token: token)
                sessionStore.save(session)
                authState = .signedIn(session)
                pendingAuthToken = nil
                logger.info("Signed in as \(session.username, privacy: .public)")
            } catch {
                handleAuthError(error)
            }
        }
    }

    private func extractToken(from callbackURL: URL) -> String? {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            return nil
        }
        return queryItems.first { $0.name == "token" }?.value
    }

    private func handleAuthError(_ error: Error) {
        authState = .signedOut
        lastErrorMessage = error.localizedDescription
        pendingAuthToken = nil
        logger.error("Last.fm auth error: \(error.localizedDescription, privacy: .public)")
    }
}

enum LastFMFlushReason: String {
    case foreground
    case background
    case playbackEnded
}

extension LastFMScrobbleManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}
