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

### Diagnostics
- `DiagnosticLogManager` captures opt-in diagnostic events into a JSONL file under Application Support.
- Logs retain the last 24 hours, clear when disabled, and export via the system share sheet.

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

## Playback Events + Scrobbling
The scrobbling pipeline depends on reliable start/progress/end signals. MusicKit only emits changes for state and queue; playback time does not continuously change the observable objects. The event architecture therefore needs explicit sampling and derived events.

### Event sources
- `MusicPlayer.State` changes via `state.objectWillChange` (playback status transitions).
- `MusicPlayer.Queue` changes via `queue.objectWillChange` (current entry changes).
- `MusicPlayer.playbackTime` sampled on a periodic tick while playing.
- App lifecycle events (`willResignActive`, `didEnterBackground`, `willEnterForeground`) to capture final snapshots and resume tracking.

### Derived event semantics
- Track start: when `queue.currentEntry` changes to a new track or playback transitions to `.playing` with a different item than the last snapshot.
- Progress update: periodic tick while playing; update `PlaybackSnapshot` with current playback time.
- Track end: when `queue.currentEntry` changes away from the current track, or playback transitions to `.stopped` with the queue empty.
- Completion guard (skip vs scrobble): only scrobble on track-end if playback time meets a near-completion window:
  - If duration >= 60s: `playbackTime >= duration - 30s`.
  - If duration < 60s: `playbackTime >= duration * 0.8` (short-track fallback).
  - If duration missing: require `playbackTime >= 30s`.
- Interruptions: when playback state changes to `.paused` or `.loading`, keep the candidate but stop ticking; resume ticking on `.playing`.

### Recommended pipeline
- Introduce a `PlaybackEventCoordinator` (can live inside `AppleMusicPlaybackController`) that emits `PlaybackSnapshot` events.
- On active player changes, rebind observers to the new player (`ApplicationMusicPlayer` vs `SystemMusicPlayer`).
- Use a timer or Task loop to sample `playbackTime` every 1-5 seconds while playing.
- Emit snapshots with a `reason` (state-change, queue-change, tick, lifecycle) so downstream logging can explain missing events.
- Keep a `lastSnapshot` to detect track changes and to suppress duplicate updates.

### Diagnostics for verification
- Log `playback_snapshot` with track id, playback state, playback time, active player, and reason.
- Log `scrobble_candidate` transitions (start/update/finalize) with the same reason and track metadata.
- Use the diagnostic JSONL export to confirm that each track has a start event, progressive playback times, and a finalization event.

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
- Generate the project after changing sources: `cd ios/MusicStoryRenderer && xcodegen generate`.
- Build/test with `xcodebuild` (see `ios/AGENTS.md` for exact commands).
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
