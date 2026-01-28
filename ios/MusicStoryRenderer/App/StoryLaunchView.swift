import SwiftUI
import UIKit

struct StoryLaunchView: View {
    @ObservedObject var store: StoryDocumentStore
    @ObservedObject var scrobbleManager: LastFMScrobbleManager
    @ObservedObject var diagnosticLogger: DiagnosticLogManager
    let availableStories: [StoryLaunchItem]
    let onOpenStory: () -> Void
    let onSelectStory: (StoryLaunchItem) -> Void
    let onPickStory: () -> Void
    let onLoadStoryURL: () -> Void
    let onDeleteStory: () -> Void
    let onDeleteCatalogStory: (StoryLaunchItem) -> Void

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
                    StoryCatalogSection(
                        stories: availableStories,
                        onSelectStory: onSelectStory,
                        onDeleteStory: onDeleteCatalogStory,
                    )
                    StorySourceSection(onPickStory: onPickStory, onLoadStoryURL: onLoadStoryURL)
                    StorySettingsSection(scrobbleManager: scrobbleManager, diagnosticLogger: diagnosticLogger)
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
                    Color.gray.opacity(0.18),
                    Color.gray.opacity(0.08),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 240, height: 240)
                .blur(radius: 120)
                .offset(x: -140, y: -200)
            Circle()
                .fill(Color.gray.opacity(0.2))
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
    let onDeleteStory: (StoryLaunchItem) -> Void
    @State private var pendingDelete: StoryLaunchItem?

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
                        .contextMenu {
                            if canDelete(item) {
                                Button(role: .destructive) {
                                    pendingDelete = item
                                } label: {
                                    Label("Delete Story", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete story?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { isPresented in
                    if isPresented == false {
                        pendingDelete = nil
                    }
                }
            ),
            titleVisibility: .visible,
        ) {
            if let pendingDelete {
                Button("Delete Story", role: .destructive) {
                    onDeleteStory(pendingDelete)
                    self.pendingDelete = nil
                }
            }
        } message: {
            if let pendingDelete {
                Text(deleteMessage(for: pendingDelete))
            }
        }
    }

    private func canDelete(_ item: StoryLaunchItem) -> Bool {
        item.source != .bundled
    }

    private func deleteMessage(for item: StoryLaunchItem) -> String {
        switch item.source {
        case .bundled:
            return ""
        case .savedRemote:
            return "This removes the saved URL story from this device."
        case .recentLocal:
            return "This removes the story from your recent list."
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
        .background(StoryCardBackground(accentColor: accentColor, cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var accentColor: Color? {
        Color(hex: item.metadata.accentColor)
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
        Button(action: onOpenStory) {
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
                StoryOpenStoryCallToAction()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(StoryCardBackground(accentColor: accentColor, cornerRadius: 24))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private var accentColor: Color? {
        Color(hex: document.accentColor)
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

private struct StoryOpenStoryCallToAction: View {
    var body: some View {
        Label("Open Story", systemImage: "arrow.right.circle.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.tint)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

private struct StorySettingsSection: View {
    @ObservedObject var scrobbleManager: LastFMScrobbleManager
    @ObservedObject var diagnosticLogger: DiagnosticLogManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
            NavigationLink {
                LastFMSettingsView(scrobbleManager: scrobbleManager)
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last.fm Scrobbling")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("lastfm-settings-link")
            DiagnosticLoggingCard(diagnosticLogger: diagnosticLogger)
        }
    }

    private var statusText: String {
        if scrobbleManager.isConfigured == false {
            return "API key not configured"
        }
        switch scrobbleManager.authState {
        case .signedIn(let session):
            return "Signed in as \(session.username)"
        case .authorizing:
            return "Signing in..."
        case .exchanging:
            return "Completing sign-in..."
        case .signedOut:
            return "Not signed in"
        }
    }
}

private struct StoryCardBackground: View {
    let accentColor: Color?
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            if let accentColor {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.46),
                                accentColor.opacity(0.30),
                                accentColor.opacity(0.16),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
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

private struct DiagnosticLoggingCard: View {
    @ObservedObject var diagnosticLogger: DiagnosticLogManager
    @State private var isShowingShareSheet = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var isExporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $diagnosticLogger.isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diagnostic Logging")
                        .font(.headline)
                    Text("Keeps last 24 hours; disabling clears logs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("diagnostic-logging-toggle")

            Button {
                exportError = nil
                isExporting = true
                Task {
                    let url = await diagnosticLogger.prepareExport()
                    await MainActor.run {
                        isExporting = false
                        if let url {
                            exportURL = url
                            isShowingShareSheet = true
                        } else {
                            exportError = "No logs available to export."
                        }
                    }
                }
            } label: {
                Label(isExporting ? "Preparing..." : "Export Logs", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(diagnosticLogger.hasLogs == false || isExporting)

            if diagnosticLogger.hasLogs == false {
                Text("No logs captured yet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let exportError {
                Text(exportError)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(isPresented: $isShowingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
