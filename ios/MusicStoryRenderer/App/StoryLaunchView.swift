import SwiftUI

struct StoryLaunchView: View {
    @ObservedObject var store: StoryDocumentStore
    let availableStories: [StoryLaunchItem]
    let onOpenStory: () -> Void
    let onSelectStory: (StoryLaunchItem) -> Void
    let onPickStory: () -> Void
    let onLoadStoryURL: () -> Void
    let onDeleteStory: () -> Void

    var body: some View {
        ZStack {
            StoryLaunchBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StoryLaunchHeader()
                    StoryStatusSection(
                        state: store.state,
                        persistedStoryURL: persistedStoryURL,
                        showDeleteAction: store.hasPersistedStory,
                        onOpenStory: onOpenStory,
                        onDeleteStory: onDeleteStory,
                    )
                    StoryCatalogSection(stories: availableStories, onSelectStory: onSelectStory)
                    StorySourceSection(onPickStory: onPickStory, onLoadStoryURL: onLoadStoryURL)
                    if store.diagnostics.isEmpty == false {
                        StoryDiagnosticsSection(diagnostics: store.diagnostics)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var persistedStoryURL: URL? {
        store.isPersistedStoryActive ? store.persistedStoryURL : nil
    }
}

private struct StoryLaunchBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.35),
                    Color.blue.opacity(0.2),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 240, height: 240)
                .blur(radius: 120)
                .offset(x: -140, y: -200)
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 260, height: 260)
                .blur(radius: 130)
                .offset(x: 160, y: 220)
        }
        .ignoresSafeArea()
    }
}

private struct StoryLaunchHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.title2.weight(.semibold))
                Text("Music Stories")
                    .font(.largeTitle.bold())
            }
            Text("Curated narratives with Apple Music playback.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StoryStatusSection: View {
    let state: StoryLoadState
    let persistedStoryURL: URL?
    let showDeleteAction: Bool
    let onOpenStory: () -> Void
    let onDeleteStory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Story")
                    .font(.headline)
                Spacer()
                StoryStatusPill(state: state)
            }
            switch state {
            case let .loaded(document):
                StoryLoadedCard(document: document, sourceURL: persistedStoryURL, onOpenStory: onOpenStory)
            case .loading:
                StoryLoadingCard()
            case .idle:
                StoryEmptyCard()
            case let .failed(message):
                StoryErrorCard(message: message)
            }
            if showDeleteAction {
                StoryPersistedStoryActions(sourceURL: persistedStoryURL, onDeleteStory: onDeleteStory)
            }
        }
    }
}

private struct StoryCatalogSection: View {
    let stories: [StoryLaunchItem]
    let onSelectStory: (StoryLaunchItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Stories")
                .font(.headline)
            if stories.isEmpty {
                StoryCatalogEmptyState()
            } else {
                VStack(spacing: 12) {
                    ForEach(stories) { item in
                        Button {
                            onSelectStory(item)
                        } label: {
                            StoryCatalogCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct StoryCatalogEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No stories available", systemImage: "sparkles")
                .font(.headline)
            Text("Add a story package or load a URL to get started.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct StoryCatalogCard: View {
    let item: StoryLaunchItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            StoryCatalogArtwork(heroImage: item.metadata.heroImage)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.metadata.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    StorySourcePill(source: item.source)
                }
                if let subtitle = item.metadata.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(metadataLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var metadataLine: String {
        let authorLine = item.metadata.authors.joined(separator: ", ")
        let dateLine = DateFormatter.storyDate.string(from: item.metadata.publishDate)
        if item.metadata.tags.isEmpty {
            return "\(authorLine) - \(dateLine)"
        }
        let tagLine = item.metadata.tags.prefix(2).joined(separator: " - ")
        return "\(authorLine) - \(dateLine) - \(tagLine)"
    }
}

private struct StoryCatalogArtwork: View {
    let heroImage: StoryHeroImage?

    var body: some View {
        ZStack {
            if let heroImage, let url = URL(string: heroImage.source) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: 96, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel(heroImage?.altText ?? "Story hero image")
    }

    @ViewBuilder
    private var fallback: some View {
        LinearGradient(
            colors: [Color.indigo.opacity(0.8), Color.blue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }
}

private struct StorySourcePill: View {
    let source: StoryLaunchSource

    var body: some View {
        Text(source.displayTitle)
            .font(.caption2.bold())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}

private struct StoryStatusPill: View {
    let state: StoryLoadState

    var body: some View {
        Label(statusLabel, systemImage: statusSymbol)
            .font(.caption.bold())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }

    private var statusLabel: String {
        switch state {
        case .loaded:
            "Ready"
        case .loading:
            "Loading"
        case .idle:
            "No Story"
        case .failed:
            "Needs Attention"
        }
    }

    private var statusSymbol: String {
        switch state {
        case .loaded:
            "checkmark.circle"
        case .loading:
            "hourglass"
        case .idle:
            "music.note"
        case .failed:
            "exclamationmark.triangle"
        }
    }
}

private struct StoryLoadedCard: View {
    let document: StoryDocument
    let sourceURL: URL?
    let onOpenStory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StoryPreviewImage(heroImage: document.heroImage)
            VStack(alignment: .leading, spacing: 6) {
                Text(document.title)
                    .font(.title2.bold())
                if let subtitle = document.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(metadataLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let sourceLine {
                    Text(sourceLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if document.tags.isEmpty == false {
                StoryTagRow(tags: document.tags)
            }
            Button(action: onOpenStory) {
                Label("Open Story", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var metadataLine: String {
        let authorLine = document.authors.joined(separator: ", ")
        let dateLine = DateFormatter.storyDate.string(from: document.publishDate)
        if document.tags.isEmpty {
            return "\(authorLine) - \(dateLine)"
        }
        let tagLine = document.tags.prefix(2).joined(separator: " - ")
        return "\(authorLine) - \(dateLine) - \(tagLine)"
    }

    private var sourceLine: String? {
        guard let sourceURL else {
            return nil
        }
        let host = sourceURL.host ?? sourceURL.absoluteString
        return "Saved from \(host)"
    }
}

private struct StoryPreviewImage: View {
    let heroImage: StoryHeroImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let heroImage, let url = URL(string: heroImage.source) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
            if let heroImage, let credit = heroImage.credit {
                Text(credit)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(10)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel(heroImage?.altText ?? "Story hero image")
    }

    @ViewBuilder
    private var fallback: some View {
        LinearGradient(
            colors: [Color.indigo.opacity(0.8), Color.blue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }
}

private struct StoryTagRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags.prefix(5), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.bold())
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct StoryLoadingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView()
            Text("Loading story...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct StoryEmptyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No story loaded", systemImage: "sparkles")
                .font(.headline)
            Text("Choose a story package to begin.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct StoryErrorCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to load story", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct StorySourceSection: View {
    let onPickStory: () -> Void
    let onLoadStoryURL: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story Sources")
                .font(.headline)
            Button(action: onPickStory) {
                Label("Choose Story Package", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button(action: onLoadStoryURL) {
                Label("Load from URL", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Text("Select a local package or paste a URL to a hosted story.mdx file.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct StoryDiagnosticsSection: View {
    let diagnostics: [ValidationDiagnostic]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics")
                .font(.headline)
            ForEach(diagnostics) { diagnostic in
                StoryDiagnosticRow(diagnostic: diagnostic)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct StoryPersistedStoryActions: View {
    let sourceURL: URL?
    let onDeleteStory: () -> Void
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved URL story")
                .font(.headline)
            if let sourceLine {
                Text(sourceLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label("Delete Saved Story", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .confirmationDialog(
            "Delete saved story?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible,
        ) {
            Button("Delete Story", role: .destructive, action: onDeleteStory)
        } message: {
            Text("This removes the saved URL story from this device.")
        }
    }

    private var sourceLine: String? {
        guard let sourceURL else {
            return nil
        }
        return sourceURL.host ?? sourceURL.absoluteString
    }
}

private struct StoryDiagnosticRow: View {
    let diagnostic: ValidationDiagnostic

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(symbolColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(diagnostic.message)
                    .font(.caption)
                if let location = diagnostic.location {
                    Text(location)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var symbolName: String {
        switch diagnostic.severity {
        case .error:
            "xmark.octagon"
        case .warning:
            "exclamationmark.triangle"
        }
    }

    private var symbolColor: Color {
        switch diagnostic.severity {
        case .error:
            .red
        case .warning:
            .orange
        }
    }
}
