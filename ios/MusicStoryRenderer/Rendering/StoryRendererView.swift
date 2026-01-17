import SwiftUI

struct StoryRendererView: View {
    let document: StoryDocument
    let playbackController: PlaybackControlling

    init(document: StoryDocument, playbackController: PlaybackControlling = AppleMusicPlaybackController()) {
        self.document = document
        self.playbackController = playbackController
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                StoryHeaderView(document: document)
                ForEach(document.sections) { section in
                    StorySectionView(
                        section: section,
                        mediaLookup: document.mediaByKey,
                        playbackController: playbackController
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }
}

struct StoryHeaderView: View {
    let document: StoryDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StoryHeroImageView(heroImage: document.heroImage)
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
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel(heroImage?.altText ?? "Story hero image")
    }

    private var heroFallback: some View {
        LinearGradient(
            colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct StorySectionView: View {
    let section: StorySection
    let mediaLookup: [String: StoryMediaReference]
    let playbackController: PlaybackControlling

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = section.title {
                Text(title)
                    .font(.title2.bold())
            }
            if let leadMediaKey = section.leadMediaKey, let media = mediaLookup[leadMediaKey] {
                MediaReferenceView(media: media, intent: PlaybackIntent(autoplay: false, usePreview: true, loop: false), playbackController: playbackController)
            }
            ForEach(section.blocks) { block in
                StoryBlockView(block: block, mediaLookup: mediaLookup, playbackController: playbackController)
            }
        }
    }
}

struct StoryBlockView: View {
    let block: StoryBlock
    let mediaLookup: [String: StoryMediaReference]
    let playbackController: PlaybackControlling

    var body: some View {
        switch block {
        case let .paragraph(_, text):
            Text(.init(text))
                .font(.body)
                .lineSpacing(6)
        case let .media(_, referenceKey, intent):
            if let media = mediaLookup[referenceKey] {
                MediaReferenceView(media: media, intent: intent, playbackController: playbackController)
            }
        }
    }
}

struct MediaReferenceView: View {
    let media: StoryMediaReference
    let intent: PlaybackIntent?
    let playbackController: PlaybackControlling

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            }
            Button {
                playbackController.play(media: media, intent: intent)
            } label: {
                Text(intent?.autoplay == true ? "Play Now" : "Play")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.ultraThinMaterial)
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

extension DateFormatter {
    static let storyDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

#Preview {
    StoryRendererView(document: .sample())
}
