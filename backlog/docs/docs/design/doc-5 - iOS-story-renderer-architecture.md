---
id: doc-5
title: iOS story renderer architecture
type: design
created_date: '2026-01-17 14:40'
---

## Summary
Define the architecture for the iOS music story renderer, aligning with the MDX story format and the web renderer goals while taking advantage of SwiftUI and MusicKit for playback.

## Goals
- Render story packages (`story.mdx` + `assets/`) into a single-scroll, magazine-like reading experience.
- Preserve the fallbacks and schema behaviors defined in `doc-1` and match the narrative tone set by the HTML renderer.
- Integrate MusicKit playback with a shared queue and persistent playback bar.
- Keep the app modular so new block types (pull quotes, timelines, footnotes) are easy to add.

## Non-Goals
- Authoring or editing story content.
- Server-side rendering or publishing workflows (handled by web renderer).
- Personalization or territory-specific logic in the initial release.

## Architecture Overview
The app is split into four primary layers:
1. **Story ingestion**: Load a story package from disk or bundled sample and parse front matter + MDX body.
2. **Domain models**: Convert the parsed data into strongly typed `StoryDocument` models with fallbacks applied.
3. **Rendering**: SwiftUI views map sections and blocks into the narrative UI.
4. **Playback**: MusicKit-backed queue and playback controller shared across all media cards.

## Modules & Responsibilities
- **StoryPackageLoader**
  - Resolves a story bundle (`story.mdx` + `assets/`).
  - Handles local file access, security-scoped URLs, and asset path mapping.
- **StoryParser**
  - Parses YAML front matter into metadata, `sections`, and `media` entries.
  - Parses MDX body into a sequence of `Section` and `MediaRef` blocks.
  - Produces a `StoryDocument` with normalized data and validation diagnostics.
- **StoryDocumentStore**
  - Holds the current story, loading state, and validation warnings.
  - Exposes story data to SwiftUI via `@Observable` or `ObservableObject`.
- **StoryRendererView**
  - Renders the story header, sections, media cards, and inline blocks.
  - Applies layout variants (`lede`, `body`) and fallbacks for missing metadata.
- **PlaybackCoordinator**
  - Wraps MusicKit player APIs, builds queues, and keeps now-playing state.
  - Exposes playback state to the UI and provides “play/queue” commands.
- **PlaybackBarView**
  - Persistent mini player (Liquid Glass) with queue controls.
  - Expands into a full now-playing sheet.

## Data Flow
1. User selects a story package (local or bundled).
2. `StoryPackageLoader` loads `story.mdx` and resolves asset paths.
3. `StoryParser` reads front matter + body and emits a `StoryDocument` plus validation notes.
4. `StoryDocumentStore` publishes the model to `StoryRendererView`.
5. Media card actions call `PlaybackCoordinator` to queue or play.
6. Playback state updates flow back to the UI (mini player, inline state).

## Rendering Pipeline
- **Front matter**: Parsed into metadata, `sections`, and `media` arrays.
- **Body**: MDX parsed into ordered blocks (`Section`, `MediaRef`, paragraphs).
- **Layout variants**: `layout=lede` uses hero spacing, `layout=body` uses standard spacing.
- **Fallbacks**: Missing hero image → gradient fallback, missing subtitle → tighten spacing, missing media metadata → text-only card.

## Playback Integration
- Use MusicKit for catalog lookup and `SystemMusicPlayer` for playback.
- Require MusicKit authorization before full playback; if unauthorized, show disabled controls with guidance.
- Maintain a shared queue per story; inline play buttons enqueue and optionally start playback.
- Keep playback state in a single coordinator to avoid divergent queues.

## State Management
- `StoryDocumentStore` manages loading states and validation warnings.
- `PlaybackCoordinator` exposes `nowPlaying`, `queue`, and `isPlaying` via `@Published` or `@Observable`.
- Views read from environment and avoid direct MusicKit calls.

## Error Handling
- Surface parser warnings in a non-blocking banner for dev builds.
- If a `MediaRef` cannot resolve, show a placeholder card with a warning label.
- Handle MusicKit authorization failures with a clear “Sign in to Apple Music” CTA.

## Accessibility & UX
- Match the design principles in `doc-4` (Liquid Glass for controls, narrative-first layout).
- Support Dynamic Type, Reduce Transparency, and VoiceOver semantics.
- Keep inline media actions discoverable with clear labels and haptics.

## Phased Delivery
1. **Phase 1**: Story parsing + static rendering with sample data.
2. **Phase 2**: Media cards + queueing playback stub.
3. **Phase 3**: MusicKit integration + persistent playback bar.
4. **Phase 4**: Story picker + local bundle ingestion.

## Open Questions
- Should we vendor an MDX parser in Swift or precompile story content to JSON?
- How should we store developer tokens for MusicKit during local development?
- Do we want offline caching for artwork and playback metadata?
