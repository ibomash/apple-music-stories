# iOS Architecture

## Overview
The iOS renderer is a SwiftUI app that loads a story package, parses the MDX-based document format, renders a single-scroll narrative layout, and integrates MusicKit playback with a persistent playback bar + now-playing sheet. The core responsibilities are split across four layers: ingestion, domain models, rendering, and playback.

## Modules and Responsibilities

### Story ingestion
- `StoryPackageLoader` loads `story.mdx` and resolves `assets/` paths into absolute URLs.
- Story selection uses a toolbar picker with `fileImporter` to open bundled or on-device story packages; the store keeps security-scoped access active while a picked story is rendered.
- Errors from loading are surfaced as `StoryLoadState.failed`.

### Story parsing + models
- `StoryParser` parses YAML front matter and MDX body into `StoryDocument` + `ValidationDiagnostic` values.
- `StoryDocument` is the normalized model for UI rendering.
- `StoryDocumentStore` owns the current story, loading state, and diagnostics, and publishes them via `@Published` properties.

### Rendering
- `StoryRendererView` renders the narrative layout using SwiftUI:
  - `StoryHeaderView` for hero image + metadata.
  - `StorySectionView` for sections and lead media.
  - `MediaReferenceView` for inline media cards.
- Views use the shared playback controller for play/queue actions and to reflect play status.

### Playback
- `AppleMusicPlaybackController` integrates MusicKit authorization, queue state, playback state, and now-playing metadata.
- The controller wraps `SystemMusicPlayer` and maps its state into UI-friendly models (`PlaybackState`, `PlaybackNowPlayingMetadata`).
- Playback UI is shared at the app root:
  - `PlaybackBarView` shows the mini player + authorization CTA.
  - `NowPlayingSheetView` shows expanded playback controls and metadata.

## Data Flow
1. `StoryRootView` loads a story via `StoryDocumentStore`.
2. The store parses the package and publishes `StoryDocument` + diagnostics.
3. `StoryRendererView` renders the story; media cards call the playback controller.
4. `AppleMusicPlaybackController` requests authorization, sets `SystemMusicPlayer` queues, and plays.
5. The playback controller observes player state/queue changes and publishes metadata.
6. Playback bar + now-playing sheet update using published state.

## Key Types
- `StoryDocument`, `StorySection`, `StoryBlock`: normalized content model.
- `PlaybackQueueState`: queue + status helpers for media cards.
- `PlaybackAuthorizationStatus`: authorization state and CTA text.
- `PlaybackNowPlayingMetadata`: Apple Music metadata for the playback bar.

## Playback + Authorization Flow
- Media actions call `play(media:intent:)` or `queue(media:intent:)`.
- If authorization is missing, the controller raises `needsAuthorizationPrompt` and UI shows a CTA.
- Once authorized, playback resumes using the pending action and `SystemMusicPlayer`.
- Playback metadata is refreshed on player state/queue changes.

## Testing
- `StoryParserTests` and `StoryPackageLoaderTests` cover parsing + loading.
- `PlaybackQueueStateTests` cover queue behavior.
- `PlaybackAuthorizationStatusTests` and `PlaybackNowPlayingMetadataTests` cover playback state models.

## Build + Run

### Prerequisites
- macOS with Xcode that supports Swift 6.2 for the app build.
- Apple Developer Program membership and an App ID with the MusicKit capability enabled.
- Apple Music subscription for on-device playback (recommended).

### Core package (Linux/macOS)
- Initialize swiftenv (see `ios/AGENTS.md`).
- From `ios/MusicStoryRenderer`, run `swift test`.

### App build (macOS + Xcode)
- Create or open a local Xcode project in `ios/MusicStoryRenderer` (the repo does not include an `.xcodeproj` yet).
- Add the sources under `App`, `Models`, `Rendering`, `Playback`, plus `StoryDocumentStore.swift`, `StoryPackageLoader.swift`, and `StoryParser.swift` to the app target.
- Use `App/MusicStoryRendererApp.swift` as the SwiftUI entry point.
- Add the MusicKit capability and `NSAppleMusicUsageDescription` (see Entitlements + Usage Description).
- Optional: bundle `examples/sample-story/story.mdx` as `sample-story.mdx` so the initial load succeeds.
- Build and run on a simulator or device. For device runs, ensure signing/provisioning is set and MusicKit is enabled for the App ID.

## Entitlements + Usage Description
- Enable the MusicKit capability for the App ID in the Apple Developer portal (Identifiers -> App Services -> MusicKit), then refresh provisioning profiles.
- In Xcode, add the MusicKit capability under Signing & Capabilities so the entitlements are embedded in the app.
- Add `NSAppleMusicUsageDescription` to the app Info.plist with user-facing text (example: "Allow Apple Music playback in stories.").

## Pending + Planned
- Story picker + local bundle ingestion (Phase 4, TASK-26).
- Snapshot tests for UI components and diagnostic banners (not yet started).
