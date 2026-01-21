import SwiftUI

struct StoryLaunchView: View {
    @ObservedObject var store: StoryDocumentStore
    let onOpenStory: () -> Void
    let onPickStory: () -> Void

    var body: some View {
        ZStack {
            StoryLaunchBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StoryLaunchHeader()
                    StoryStatusSection(state: store.state, onOpenStory: onOpenStory)
                    StorySourceSection(onPickStory: onPickStory)
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
    let onOpenStory: () -> Void

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
                StoryLoadedCard(document: document, onOpenStory: onOpenStory)
            case .loading:
                StoryLoadingCard()
            case .idle:
                StoryEmptyCard()
            case let .failed(message):
                StoryErrorCard(message: message)
            }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story Sources")
                .font(.headline)
            Button(action: onPickStory) {
                Label("Choose Story Package", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Text("Select a folder or .mdx file to load a story package.")
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
