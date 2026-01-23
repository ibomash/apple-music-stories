import SwiftUI

struct StoryRendererView: View {
    let document: StoryDocument
    @ObservedObject var playbackController: AppleMusicPlaybackController
    @State private var hasRestoredBookmark = false
    @State private var isRestoringBookmark = false
    @State private var lastAnchorID: String?
    private let bookmarkStore = StoryBookmarkStore()
    private let scrollSpaceName = "story-scroll"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    StoryHeaderView(document: document)
                        .id(headerAnchorID)
                        .storyScrollAnchor(id: headerAnchorID, in: scrollSpaceName)
                    ForEach(document.sections) { section in
                        StorySectionView(
                            section: section,
                            mediaLookup: document.mediaByKey,
                            playbackController: playbackController,
                            scrollSpaceName: scrollSpaceName,
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .coordinateSpace(name: scrollSpaceName)
            .onAppear {
                restoreBookmarkIfNeeded(using: proxy)
            }
            .onPreferenceChange(StoryScrollAnchorPreferenceKey.self) { offsets in
                storeBookmarkIfNeeded(offsets)
            }
        }
    }

    private var headerAnchorID: String {
        "story-header-\(document.id)"
    }

    private func restoreBookmarkIfNeeded(using proxy: ScrollViewProxy) {
        guard !hasRestoredBookmark else {
            return
        }
        guard let anchorID = bookmarkStore.loadAnchorID(for: document.id) else {
            hasRestoredBookmark = true
            return
        }
        isRestoringBookmark = true
        DispatchQueue.main.async {
            proxy.scrollTo(anchorID, anchor: .top)
            DispatchQueue.main.async {
                isRestoringBookmark = false
                hasRestoredBookmark = true
            }
        }
    }

    private func storeBookmarkIfNeeded(_ offsets: [String: CGFloat]) {
        guard hasRestoredBookmark else {
            return
        }
        guard !isRestoringBookmark else {
            return
        }
        guard let anchorID = resolveAnchorID(from: offsets) else {
            return
        }
        guard anchorID != lastAnchorID else {
            return
        }
        lastAnchorID = anchorID
        bookmarkStore.saveAnchorID(anchorID, for: document.id)
    }

    private func resolveAnchorID(from offsets: [String: CGFloat]) -> String? {
        let sanitized = offsets.filter { $0.value.isFinite }
        if let nearestBelow = sanitized.filter({ $0.value >= 0 }).min(by: { $0.value < $1.value }) {
            return nearestBelow.key
        }
        return sanitized.max(by: { $0.value < $1.value })?.key
    }
}

struct StoryHeaderView: View {
    let document: StoryDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StoryHeroImageView(heroImage: document.heroImage)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(document.title)
                    .font(.largeTitle.bold())
                if let subtitle = document.subtitle {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text(metadataLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metadataLine: String {
        let authorLine = document.authors.joined(separator: ", ")
        let dateLine = DateFormatter.storyDate.string(from: document.publishDate)
        if document.tags.isEmpty {
            return "\(authorLine) • \(dateLine)"
        }
        let tagLine = document.tags.joined(separator: " • ")
        return "\(authorLine) • \(dateLine) • \(tagLine)"
    }
}

struct StoryHeroImageView: View {
    let heroImage: StoryHeroImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let heroImage, let url = URL(string: heroImage.source) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    heroFallback
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
                heroFallback
            }
            if let heroImage, let credit = heroImage.credit {
                Text(credit)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel(heroImage?.altText ?? "Story hero image")
    }

    private var heroFallback: some View {
        LinearGradient(
            colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StorySectionView: View {
    let section: StorySection
    let mediaLookup: [String: StoryMediaReference]
    let playbackController: AppleMusicPlaybackController
    let scrollSpaceName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = section.title {
                Text(title)
                    .font(.title2.bold())
            }
            if let leadMediaKey = section.leadMediaKey {
                if let media = mediaLookup[leadMediaKey] {
                    MediaReferenceView(media: media, intent: .preview, playbackController: playbackController)
                } else {
                    MissingMediaReferenceView(referenceKey: leadMediaKey)
                }
            }
            ForEach(section.blocks) { block in
                StoryBlockView(
                    block: block,
                    mediaLookup: mediaLookup,
                    playbackController: playbackController,
                    scrollSpaceName: scrollSpaceName,
                )
            }
        }
        .id(section.id)
        .storyScrollAnchor(id: section.id, in: scrollSpaceName)
    }
}

struct StoryBlockView: View {
    let block: StoryBlock
    let mediaLookup: [String: StoryMediaReference]
    let playbackController: AppleMusicPlaybackController
    let scrollSpaceName: String

    var body: some View {
        Group {
            switch block {
            case let .paragraph(_, text):
                Text(.init(text))
                    .font(.body)
                    .lineSpacing(6)
            case let .media(_, referenceKey, intent):
                if let media = mediaLookup[referenceKey] {
                    MediaReferenceView(media: media, intent: intent, playbackController: playbackController)
                } else {
                    MissingMediaReferenceView(referenceKey: referenceKey)
                }
            }
        }
        .id(block.id)
        .storyScrollAnchor(id: block.id, in: scrollSpaceName)
    }
}

struct MediaReferenceView: View {
    let media: StoryMediaReference
    let intent: PlaybackIntent?
    let playbackController: AppleMusicPlaybackController

    var body: some View {
        let status = playbackController.queueState.status(for: media)
        let playLabel = status == .playing ? "Playing" : (intent?.autoplay == true ? "Play Now" : "Play")
        let queueLabel = switch status {
        case .idle:
            "Queue"
        case .queued:
            "Queued"
        case .playing:
            "Playing"
        }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                MediaArtworkView(url: media.artworkURL)
                VStack(alignment: .leading, spacing: 6) {
                    Text(media.title)
                        .font(.headline)
                    Text(media.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(media.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                MediaStatusBadge(status: status)
            }
            HStack(spacing: 12) {
                Button {
                    playbackController.play(media: media, intent: intent)
                } label: {
                    Text(playLabel)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(status == .playing)

                Button {
                    playbackController.queue(media: media, intent: intent)
                } label: {
                    Text(queueLabel)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(status != .idle)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MissingMediaReferenceView: View {
    let referenceKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Missing media reference", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(referenceKey)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MediaArtworkView: View {
    let url: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
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
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MediaStatusBadge: View {
    let status: PlaybackQueueStatus

    var body: some View {
        if status == .idle {
            EmptyView()
        } else {
            Text(status.label)
                .font(.caption2.bold())
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .accessibilityLabel(status.label)
        }
    }
}

private struct StoryScrollAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] { [:] }

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct StoryScrollAnchorReporter: View {
    let id: String
    let scrollSpaceName: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: StoryScrollAnchorPreferenceKey.self,
                    value: [id: proxy.frame(in: .named(scrollSpaceName)).minY]
                )
        }
    }
}

private extension View {
    func storyScrollAnchor(id: String, in scrollSpaceName: String) -> some View {
        background(StoryScrollAnchorReporter(id: id, scrollSpaceName: scrollSpaceName))
    }
}

extension DateFormatter {
    static let storyDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

struct StoryBookmarkStore {
    private let defaults: UserDefaults
    private let keyPrefix = "story-bookmark-anchor-id"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAnchorID(for storyID: String) -> String? {
        defaults.string(forKey: key(for: storyID))
    }

    func saveAnchorID(_ anchorID: String, for storyID: String) {
        defaults.set(anchorID, forKey: key(for: storyID))
    }

    func clearAnchorID(for storyID: String) {
        defaults.removeObject(forKey: key(for: storyID))
    }

    private func key(for storyID: String) -> String {
        "\(keyPrefix).\(storyID)"
    }
}

#Preview {
    StoryRendererView(document: .sample(), playbackController: AppleMusicPlaybackController())
}
