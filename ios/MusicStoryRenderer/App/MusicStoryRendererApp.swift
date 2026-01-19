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

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                Group {
                    switch store.state {
                    case .idle, .loading:
                        ProgressView("Loading Story…")
                    case let .loaded(document):
                        StoryRendererView(document: document, playbackController: playbackController)
                            .padding(.bottom, playbackController.shouldShowPlaybackBar ? 92 : 0)
                    case let .failed(message):
                        ContentUnavailableView(
                            "Unable to Load Story",
                            systemImage: "exclamationmark.triangle",
                            description: Text(message)
                        )
                    }
                }
                .navigationTitle("Music Stories")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isShowingStoryPicker = true
                        } label: {
                            Label("Open Story", systemImage: "folder")
                        }
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
        .fileImporter(
            isPresented: $isShowingStoryPicker,
            allowedContentTypes: [.folder, UTType(filenameExtension: "mdx")].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    store.loadStory(from: url)
                }
            case let .failure(error):
                store.handleLoadError(error.localizedDescription)
            }
        }
        .task {
            store.loadBundledSampleIfAvailable()
        }
        .animation(.easeInOut(duration: 0.2), value: playbackController.shouldShowPlaybackBar)
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

            Button(action: onExpand) {
                HStack(spacing: 12) {
                    NowPlayingArtworkView(url: controller.displayMetadata?.artworkURL)
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
            }
            .buttonStyle(.plain)
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
    @ObservedObject var controller: AppleMusicPlaybackController

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 48, height: 6)
                .padding(.top, 12)

            NowPlayingArtworkView(url: controller.displayMetadata?.artworkURL)
                .frame(width: 180, height: 180)

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

            if let message = controller.lastErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .presentationDetents([.medium, .large])
    }
}

private struct NowPlayingArtworkView: View {
    let url: URL?

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
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
