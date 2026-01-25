import AVKit
import Foundation
import SwiftUI
import UIKit

struct StoryRendererView: View {
    let document: StoryDocument
    @ObservedObject var playbackController: AppleMusicPlaybackController
    @State private var hasRestoredBookmark = false
    @State private var isRestoringBookmark = false
    @State private var lastAnchorID: String?
    private let bookmarkStore = StoryBookmarkStore()
    private let scrollSpaceName = "story-scroll"

    var body: some View {
        GeometryReader { proxy in
            let screenWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            let contentWidth = max(screenWidth - 48, 0)
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        StoryHeaderView(document: document, heroGradient: heroGradient, contentWidth: contentWidth)
                            .id(headerAnchorID)
                            .storyScrollAnchor(id: headerAnchorID, in: scrollSpaceName)
                        ForEach(document.sections) { section in
                            StorySectionView(
                                section: section,
                                mediaLookup: document.mediaByKey,
                                playbackController: playbackController,
                                scrollSpaceName: scrollSpaceName,
                                accentColor: accentColor,
                            )
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .clipped()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .fontDesign(document.typeRamp?.fontDesign)
                }
                .coordinateSpace(name: scrollSpaceName)
                .tint(accentColor)
                .onAppear {
                    restoreBookmarkIfNeeded(using: scrollProxy)
                }
                .onPreferenceChange(StoryScrollAnchorPreferenceKey.self) { offsets in
                    storeBookmarkIfNeeded(offsets)
                }
            }
        }
    }

    private var accentColor: Color {
        Color(hex: document.accentColor) ?? Color.indigo
    }

    private var heroGradient: [Color] {
        let colors = document.heroGradient.compactMap { Color(hex: $0) }
        if colors.isEmpty {
            return [Color.indigo.opacity(0.8), Color.purple.opacity(0.8)]
        }
        return colors
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
    let heroGradient: [Color]
    let contentWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StoryHeroImageView(heroImage: document.heroImage, gradientColors: heroGradient, width: contentWidth)
            VStack(alignment: .leading, spacing: 8) {
                Text(document.title)
                    .font(.largeTitle.bold())
                if let deck = document.deck {
                    Text(deck)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                if let subtitle = document.subtitle {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text(metadataLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let leadArt = document.leadArt {
                StoryLeadArtView(leadArt: leadArt)
                    .frame(width: contentWidth, alignment: .leading)
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
    let gradientColors: [Color]
    let width: CGFloat

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
        .frame(width: width, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel(heroImage?.altText ?? "Story hero image")
    }

    private var heroFallback: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StoryLeadArtView: View {
    let leadArt: StoryLeadArt

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = URL(string: leadArt.source) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.2))
                }
                .frame(maxWidth: .infinity, maxHeight: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if let caption = leadArt.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let credit = leadArt.credit {
                Text(credit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StorySectionView: View {
    let section: StorySection
    let mediaLookup: [String: StoryMediaReference]
    let playbackController: AppleMusicPlaybackController
    let scrollSpaceName: String
    let accentColor: Color

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
                    accentColor: accentColor,
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
    let accentColor: Color

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
            case let .dropQuote(_, text, attribution):
                DropQuoteView(text: text, attribution: attribution, accentColor: accentColor)
            case let .sideNote(_, text, label):
                SideNoteView(text: text, label: label, accentColor: accentColor)
            case let .featureBox(_, title, summary, expandable, content):
                FeatureBoxView(
                    title: title,
                    summary: summary,
                    expandable: expandable,
                    content: content,
                )
            case let .factGrid(_, facts):
                FactGridView(facts: facts, accentColor: accentColor)
            case let .timeline(_, items):
                TimelineView(items: items, accentColor: accentColor)
            case let .gallery(_, images):
                GalleryView(images: images)
            case let .fullBleed(_, source, altText, caption, credit, kind):
                FullBleedView(
                    source: source,
                    altText: altText,
                    caption: caption,
                    credit: credit,
                    kind: kind,
                )
            }
        }
        .id(block.id)
        .storyScrollAnchor(id: block.id, in: scrollSpaceName)
    }
}

struct DropQuoteView: View {
    let text: String
    let attribution: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.init(text))
                .font(.title3)
                .italic()
            if let attribution {
                Text(attribution.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.4), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.thinMaterial)
                )
        )
    }
}

struct SideNoteView: View {
    let text: String
    let label: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                Text(label.uppercased())
                    .font(.caption)
                    .foregroundStyle(accentColor)
            }
            Text(.init(text))
                .font(.callout)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }
}

struct FeatureBoxView: View {
    let title: String?
    let summary: String?
    let expandable: Bool
    let content: String

    var body: some View {
        if expandable {
            DisclosureGroup {
                Text(.init(content))
                    .font(.body)
            } label: {
                FeatureBoxHeader(title: title, summary: summary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                FeatureBoxHeader(title: title, summary: summary)
                Text(.init(content))
                    .font(.body)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
            )
        }
    }
}

struct FeatureBoxHeader: View {
    let title: String?
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            if let summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FactGridView: View {
    let facts: [StoryFact]
    let accentColor: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(facts, id: \.label) { fact in
                VStack(spacing: 6) {
                    Text(fact.value)
                        .font(.title3.bold())
                        .foregroundStyle(accentColor)
                    Text(fact.label.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                )
            }
        }
    }
}

struct TimelineView: View {
    let items: [StoryTimelineItem]
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(items, id: \.year) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.year)
                        .font(.headline)
                        .foregroundStyle(accentColor)
                        .frame(width: 72, alignment: .leading)
                    Text(.init(item.text))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct GalleryView: View {
    let images: [StoryGalleryImage]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            ForEach(images, id: \.source) { image in
                VStack(alignment: .leading, spacing: 8) {
                    if let url = URL(string: image.source) {
                        AsyncImage(url: url) { content in
                            content.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.2))
                        }
                        .frame(height: 140)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel(image.altText)
                    }
                    if let caption = image.caption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let credit = image.credit {
                        Text(credit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct FullBleedView: View {
    let source: String
    let altText: String
    let caption: String?
    let credit: String?
    let kind: StoryFullBleedKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if kind == .video {
                if let url = URL(string: source) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else if let url = URL(string: source) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.2))
                }
                .frame(height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel(altText)
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let credit {
                Text(credit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MediaReferenceView: View {
    let media: StoryMediaReference
    let intent: PlaybackIntent?
    let playbackController: AppleMusicPlaybackController

    var body: some View {
        let isVideo = media.type == .musicVideo
        let status = playbackController.queueState.status(for: media)
        let playLabel = status == .playing ? "Playing" : playButtonLabel
        let queueLabel = switch status {
        case .idle:
            queueButtonLabel
        case .queued:
            "Queued"
        case .playing:
            "Playing"
        }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                MediaArtworkView(media: media)
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
            if isVideo {
                Button {
                    playbackController.openInMusic(for: media)
                } label: {
                    Text("Play Video in Music app")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
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
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button {
                playbackController.openInMusic(for: media)
            } label: {
                Label("Open in Music", systemImage: "music.note")
            }
            Button {
                if let mediaLinkURL {
                    UIPasteboard.general.url = mediaLinkURL
                }
            } label: {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
            if let mediaLinkURL {
                ShareLink(item: mediaLinkURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var playButtonLabel: String {
        return intent?.autoplay == true ? "Play Now" : "Play"
    }

    private var queueButtonLabel: String {
        "Queue"
    }

    private var mediaLinkURL: URL? {
        StoryMediaLinkBuilder.url(for: media)
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
    let media: StoryMediaReference

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2))
            if let url = media.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            if media.type == .musicVideo {
                Image(systemName: "play.rectangle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
                    .padding(6)
                    .background(.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var placeholderSymbol: String {
        media.type == .musicVideo ? "film" : "music.note"
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

private extension StoryTypeRamp {
    var fontDesign: Font.Design {
        switch self {
        case .serif:
            return .serif
        case .sans:
            return .default
        case .slab:
            return .rounded
        }
    }
}

private enum StoryMediaLinkBuilder {
    static func url(for media: StoryMediaReference) -> URL? {
        let storefront = Locale.current.regionCode?.lowercased() ?? "us"
        let path: String
        switch media.type {
        case .track:
            path = "song"
        case .album:
            path = "album"
        case .playlist:
            path = "playlist"
        case .musicVideo:
            path = "music-video"
        }
        return URL(string: "https://music.apple.com/\(storefront)/\(path)/\(media.appleMusicId)")
    }
}

private extension Color {
    init?(hex: String?) {
        guard let hex, hex.isEmpty == false else {
            return nil
        }
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard trimmed.count == 6 || trimmed.count == 8 else {
            return nil
        }
        var value: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&value) else {
            return nil
        }
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        if trimmed.count == 8 {
            red = Double((value & 0xFF00_0000) >> 24) / 255
            green = Double((value & 0x00FF_0000) >> 16) / 255
            blue = Double((value & 0x0000_FF00) >> 8) / 255
            alpha = Double(value & 0x0000_00FF) / 255
        } else {
            red = Double((value & 0xFF00_00) >> 16) / 255
            green = Double((value & 0x00FF_00) >> 8) / 255
            blue = Double(value & 0x0000_FF) / 255
            alpha = 1
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
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
