import SwiftUI
import UniformTypeIdentifiers

@main
struct MusicStoryRendererApp: App {
    var body: some Scene {
        WindowGroup {
            StoryRootView()
        }
    }
}

struct StoryRootView: View {
    @StateObject private var store: StoryDocumentStore
    @StateObject private var playbackController: AppleMusicPlaybackController
    @StateObject private var scrobbleManager: LastFMScrobbleManager
    @StateObject private var diagnosticLogger: DiagnosticLogManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingNowPlaying = false
    @State private var isShowingStoryPicker = false
    @State private var isShowingURLPrompt = false
    @State private var urlInput = ""
    @State private var urlLoadError: String?
    @State private var isLoadingURL = false
    @State private var isShowingStory = false
    @State private var shouldOpenStoryAfterLoad = false

    init() {
        let diagnosticLogger = DiagnosticLogManager()
        let scrobbleManager = LastFMScrobbleManager(diagnosticLogger: diagnosticLogger)
        _scrobbleManager = StateObject(wrappedValue: scrobbleManager)
        _diagnosticLogger = StateObject(wrappedValue: diagnosticLogger)
        _playbackController = StateObject(
            wrappedValue: AppleMusicPlaybackController(
                scrobbleHandler: scrobbleManager,
                diagnosticLogger: diagnosticLogger
            )
        )
        _store = StateObject(wrappedValue: StoryDocumentStore(diagnosticLogger: diagnosticLogger))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                StoryLaunchView(
                    store: store,
                    scrobbleManager: scrobbleManager,
                    diagnosticLogger: diagnosticLogger,
                    availableStories: store.availableStories,
                    onOpenStory: openStory,
                    onSelectStory: openStoryFromCatalog,
                    onPickStory: { isShowingStoryPicker = true },
                    onLoadStoryURL: { isShowingURLPrompt = true },
                    onDeleteStory: store.deletePersistedStory,
                    onDeleteCatalogStory: store.deleteStory,
                )
                .safeAreaInset(edge: .bottom) {
                    if playbackController.shouldShowPlaybackBar {
                        Color.clear.frame(height: 92)
                    }
                }
                .navigationDestination(isPresented: $isShowingStory) {
                    if let document = loadedDocument {
                        StoryDetailView(document: document, playbackController: playbackController)
                    } else {
                        StoryUnavailableView()
                    }
                }
            }

            if playbackController.shouldShowPlaybackBar {
                PlaybackBarView(controller: playbackController) {
                    isShowingNowPlaying = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isShowingNowPlaying) {
            NowPlayingSheetView(controller: playbackController)
        }
        .sheet(isPresented: $isShowingURLPrompt) {
            StoryURLPromptView(
                urlString: $urlInput,
                isLoading: isLoadingURL,
                errorMessage: urlLoadError,
                onCancel: dismissURLPrompt,
                onSubmit: startURLStoryLoad,
            )
            .interactiveDismissDisabled(isLoadingURL)
        }
        .fileImporter(
            isPresented: $isShowingStoryPicker,
            allowedContentTypes: [.folder, UTType(filenameExtension: "mdx")].compactMap(\.self),
            allowsMultipleSelection: false,
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    shouldOpenStoryAfterLoad = true
                    store.loadStory(from: url)
                }
            case let .failure(error):
                store.handleLoadError(error.localizedDescription)
            }
        }
        .onChange(of: store.state) { newState in
            handleStoryStateChange(newState)
        }
        .onChange(of: urlInput) { _ in
            if isLoadingURL == false {
                urlLoadError = nil
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                playbackController.handleAppForeground()
                scrobbleManager.flushPending(reason: .foreground)
            case .background:
                playbackController.handleAppBackground()
                scrobbleManager.flushPending(reason: .background)
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .task {
            diagnosticLogger.log(event: "app_launch")
            store.loadInitialStory()
        }
        .animation(.easeInOut(duration: 0.2), value: playbackController.shouldShowPlaybackBar)
    }

    private var loadedDocument: StoryDocument? {
        guard case let .loaded(document) = store.state else {
            return nil
        }
        return document
    }

    private func openStory() {
        guard loadedDocument != nil else {
            return
        }
        isShowingStory = true
    }

    private func openStoryFromCatalog(_ item: StoryLaunchItem) {
        if store.isCurrentStory(item) {
            shouldOpenStoryAfterLoad = false
            isShowingStory = true
            return
        }
        shouldOpenStoryAfterLoad = true
        store.loadStory(from: item)
    }

    private func handleStoryStateChange(_ state: StoryLoadState) {
        guard shouldOpenStoryAfterLoad else {
            if isLoadingURL {
                handleURLPromptStateChange(state)
            }
            return
        }
        switch state {
        case .loaded:
            isShowingStory = true
            shouldOpenStoryAfterLoad = false
        case .failed:
            shouldOpenStoryAfterLoad = false
        case .idle, .loading:
            break
        }

        if isLoadingURL {
            handleURLPromptStateChange(state)
        }
    }

    private func startURLStoryLoad() {
        urlLoadError = nil
        let trimmedInput = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedInput) else {
            urlLoadError = "Enter a valid URL."
            return
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            urlLoadError = "Story URLs must start with http or https."
            return
        }
        guard url.pathExtension.lowercased() == "mdx" else {
            urlLoadError = "Story URLs must point to a .mdx file."
            return
        }
        isLoadingURL = true
        shouldOpenStoryAfterLoad = true
        Task {
            await store.loadRemoteStory(from: url)
        }
    }

    private func handleURLPromptStateChange(_ state: StoryLoadState) {
        switch state {
        case .loaded:
            isLoadingURL = false
            urlLoadError = nil
            isShowingURLPrompt = false
            urlInput = ""
        case let .failed(message):
            isLoadingURL = false
            urlLoadError = message
        case .idle, .loading:
            break
        }
    }

    private func dismissURLPrompt() {
        guard isLoadingURL == false else {
            return
        }
        urlLoadError = nil
        isShowingURLPrompt = false
    }
}

private struct StoryDetailView: View {
    let document: StoryDocument
    @ObservedObject var playbackController: AppleMusicPlaybackController

    var body: some View {
        StoryRendererView(document: document, playbackController: playbackController)
            .padding(.bottom, playbackController.shouldShowPlaybackBar ? 92 : 0)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }
}

private struct StoryUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "Story Unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text("Return to the launch screen to choose a story."),
        )
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct StoryURLPromptView: View {
    @Binding var urlString: String
    let isLoading: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste a direct link to a hosted story.mdx file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("https://example.com/story.mdx", text: $urlString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(action: onSubmit) {
                    Label(isLoading ? "Loading..." : "Load Story", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if isLoading {
                    ProgressView("Downloading story...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Load Story URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isLoading)
                }
            }
        }
    }
}

struct PlaybackBarView: View {
    @ObservedObject var controller: AppleMusicPlaybackController
    var onExpand: () -> Void

    var body: some View {
        let albumTitle = controller.nowPlayingAlbumTitle
            ?? (controller.displayMetadata?.type == .album ? controller.displayMetadata?.title : nil)
        let trackTitle = controller.nowPlayingTrackTitle
        let artistName = controller.nowPlayingArtistName ?? controller.displayMetadata?.subtitle
        let titleText: String = {
            if let albumTitle, let trackTitle, controller.displayMetadata?.type == .album {
                return "\(albumTitle) · \(trackTitle)"
            }
            return controller.displayMetadata?.title ?? "Nothing queued"
        }()

        VStack(spacing: 8) {
            if controller.needsAuthorizationPrompt {
                PlaybackAuthorizationBanner(controller: controller)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    NowPlayingArtworkView(url: controller.nowPlayingArtworkURL ?? controller.displayMetadata?.artworkURL, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleText)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(artistName ?? "Tap to browse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button {
                        controller.togglePlayPause()
                    } label: {
                        Image(systemName: controller.playbackState.actionSymbolName)
                            .font(.title3.bold())
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.authorizationStatus.requiresAuthorization)
                    Button {
                        controller.skipToNextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3.bold())
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.canSkipToNextTrack == false)
                }

                if let albumProgress = controller.albumProgress {
                    ProgressView(value: albumProgress.fraction)
                        .progressViewStyle(.linear)
                        .tint(.primary)
                        .frame(height: 4)
                        .accessibilityLabel("Album progress")
                        .accessibilityValue(Text(albumProgress.accessibilityValue))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .onTapGesture(perform: onExpand)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playback-bar")
    }
}

private struct PlaybackAuthorizationBanner: View {
    @ObservedObject var controller: AppleMusicPlaybackController

    var body: some View {
        Button {
            controller.requestAuthorization()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.authorizationStatus.actionTitle)
                        .font(.subheadline.bold())
                    Text("Sign in to enable full Apple Music playback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct NowPlayingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: AppleMusicPlaybackController

    var body: some View {
        let albumTitle = controller.nowPlayingAlbumTitle
            ?? (controller.displayMetadata?.type == .album ? controller.displayMetadata?.title : nil)
        let artistName = controller.nowPlayingArtistName ?? controller.displayMetadata?.subtitle
        let trackTitle = controller.nowPlayingTrackTitle ?? controller.displayMetadata?.title

        NavigationStack {
            VStack(spacing: 24) {
                if controller.needsAuthorizationPrompt {
                    PlaybackAuthorizationBanner(controller: controller)
                }

                NowPlayingArtworkView(
                    url: controller.nowPlayingArtworkURL ?? controller.displayMetadata?.artworkURL,
                    size: 220,
                    cornerRadius: 24
                )
                .accessibilityIdentifier("now-playing-artwork")

                VStack(spacing: 6) {
                    Text(trackTitle ?? "Nothing playing")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    if let artistName {
                        Text(artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let albumTitle {
                        Text(albumTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 20) {
                    Button {
                        controller.skipToPreviousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2.bold())
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.canSkipToPreviousTrack == false)

                    Button {
                        controller.togglePlayPause()
                    } label: {
                        Image(systemName: controller.playbackState.actionSymbolName)
                            .font(.largeTitle.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.authorizationStatus.requiresAuthorization)

                    Button {
                        controller.skipToNextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2.bold())
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.canSkipToNextTrack == false)
                }

                if controller.displayMetadata?.type == .musicVideo {
                    Button {
                        controller.openInMusic()
                    } label: {
                        Label("Play Video in Music app", systemImage: "music.note")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.authorizationStatus.requiresAuthorization)
                }

                if let message = controller.lastErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct NowPlayingArtworkView: View {
    let url: URL?
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.secondary.opacity(0.2))
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            } else {
                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
