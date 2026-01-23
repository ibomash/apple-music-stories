import AVKit
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
    @StateObject private var store = StoryDocumentStore()
    @StateObject private var playbackController = AppleMusicPlaybackController()
    @State private var isShowingNowPlaying = false
    @State private var isShowingStoryPicker = false
    @State private var isShowingURLPrompt = false
    @State private var urlInput = ""
    @State private var urlLoadError: String?
    @State private var isLoadingURL = false
    @State private var isShowingStory = false
    @State private var shouldOpenStoryAfterLoad = false

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                StoryLaunchView(
                    store: store,
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
        .fullScreenCover(
            item: Binding(
                get: { playbackController.videoPlaybackSession },
                set: { session in
                    if session == nil {
                        playbackController.dismissVideoPlayback()
                    }
                }
            )
        ) { session in
            VideoPlaybackContainerView(session: session) {
                playbackController.dismissVideoPlayback()
            }
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
        .task {
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

private struct PlaybackBarView: View {
    @ObservedObject var controller: AppleMusicPlaybackController
    var onExpand: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if controller.needsAuthorizationPrompt {
                PlaybackAuthorizationBanner(controller: controller)
            }

            HStack(spacing: 12) {
                NowPlayingArtworkView(url: controller.displayMetadata?.artworkURL, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.displayMetadata?.title ?? "Nothing queued")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text(controller.displayMetadata?.subtitle ?? "Tap to browse")
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

private struct NowPlayingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: AppleMusicPlaybackController

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if controller.needsAuthorizationPrompt {
                    PlaybackAuthorizationBanner(controller: controller)
                }

                NowPlayingArtworkView(url: controller.displayMetadata?.artworkURL, size: 180, cornerRadius: 20)

                VStack(spacing: 8) {
                    Text(controller.displayMetadata?.title ?? "Nothing playing")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(controller.displayMetadata?.subtitle ?? "Select a track to start")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 24) {
                    Button {
                        controller.togglePlayPause()
                    } label: {
                        Image(systemName: controller.playbackState.actionSymbolName)
                            .font(.largeTitle.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.authorizationStatus.requiresAuthorization)

                    Button {
                        controller.playNextInQueue()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2.bold())
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.queueState.upNext.isEmpty)
                }

                if controller.displayMetadata?.type == .musicVideo {
                    Button {
                        controller.presentVideoPlayback()
                    } label: {
                        Label("Show Video", systemImage: "play.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.videoPlaybackSession != nil)
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
            .padding(.top, 16)
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

private struct VideoPlaybackContainerView: View {
    let session: VideoPlaybackSession
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    private let dismissThreshold: CGFloat = 140

    var body: some View {
        VideoPlaybackView(player: session.player)
            .ignoresSafeArea()
            .offset(y: dragOffset)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard value.translation.height > 0 else {
                            return
                        }
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: dragOffset)
        .onAppear {
            session.player.play()
        }
        .onDisappear {
            session.player.pause()
            onDismiss()
        }
    }
}

private struct VideoPlaybackView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context _: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context _: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
