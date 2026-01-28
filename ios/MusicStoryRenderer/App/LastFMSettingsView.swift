import SwiftUI

struct LastFMSettingsView: View {
    @ObservedObject var scrobbleManager: LastFMScrobbleManager
    @State private var isShowingSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if scrobbleManager.isConfigured == false {
                    configurationCard
                }
                accountCard
                logSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Last.fm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last.fm Scrobbling")
                .font(.title2.bold())
            Text("Sign in to track what you finish listening to and keep a local scrobble log.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Missing API configuration", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("Add LASTFM_API_KEY and LASTFM_API_SECRET to Config/Secrets.xcconfig.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)
            Text(accountStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let errorMessage = scrobbleManager.lastErrorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if scrobbleManager.isConfigured {
                accountActionButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var accountActionButton: some View {
        switch scrobbleManager.authState {
        case .signedIn:
            Button(role: .destructive) {
                isShowingSignOut = true
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .confirmationDialog("Sign out of Last.fm?", isPresented: $isShowingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    scrobbleManager.signOut()
                }
                Button("Cancel", role: .cancel) {}
            }
        case .authorizing, .exchanging:
            ProgressView("Signing in...")
                .frame(maxWidth: .infinity, alignment: .leading)
        case .signedOut:
            Button {
                scrobbleManager.signIn()
            } label: {
                Label("Sign in", systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scrobble Log")
                .font(.headline)
            if scrobbleManager.logEntries.isEmpty {
                Text("No scrobbles yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(scrobbleManager.logEntries) { entry in
                        scrobbleLogRow(entry)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func scrobbleLogRow(_ entry: LastFMScrobbleLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.status.displayLabel)
                    .font(.caption2.bold())
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                Spacer()
                Text(Self.logDateFormatter.string(from: entry.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(entry.trackTitle)
                .font(.subheadline.bold())
            Text(entry.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let album = entry.album, album.isEmpty == false {
                Text(album)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let message = entry.message, message.isEmpty == false {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var accountStatusText: String {
        if scrobbleManager.isConfigured == false {
            return "Last.fm configuration is missing."
        }
        switch scrobbleManager.authState {
        case .signedIn(let session):
            return "Signed in as \(session.username)."
        case .authorizing:
            return "Waiting for Last.fm authorization."
        case .exchanging:
            return "Completing sign-in with Last.fm."
        case .signedOut:
            return "Sign in to start scrobbling completed tracks."
        }
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
