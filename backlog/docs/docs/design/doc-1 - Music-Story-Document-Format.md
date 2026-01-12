---
id: doc-1
title: Music Story Document Format
type: other
created_date: '2026-01-11 04:41'
---

## Purpose
Establish a display-independent, agent-friendly document model for “music stories” that pairs narrative writing with Apple Music catalog playback and can be rendered consistently across magazine-style web experiences, native apps, and other downstream consumers.

## Target Use Cases
- Narrative features that mix long-form text with embedded Apple Music tracks, albums, music videos, and playlists.
- Autonomous or semi-autonomous agents that generate stories from prompts or background material and must emit a structured artifact ready for publishing.
- Rendering pipelines (web, iOS, others) that ingest the format and output bespoke layouts with synchronized playback controls.

## Likely Requirements
- **Document metadata**: stable identifiers, title, subtitle/dek, author(s), editors, publish date, hero imagery, thematic tags, Apple Music curator/playlist references, and optional localization metadata.
- **Section schema**: ordered sections/blocks combining narrative text, media callouts, pull quotes, lists, and inline annotations that point to referenced tracks or timelines.
- **Media references**: normalized Apple Music entities (song, album, playlist, music video) stored as MusicKit catalog IDs plus display metadata (name, artist, artwork URL, duration) to avoid repeated API fan-out at render time.
- **Playback intents**: structured instructions for how each media reference should behave (preview vs full playback, autoplay, loop, highlight timestamp ranges, queue ordering, crossfade needs).
- **Layout hints**: optional presentation cues (e.g., block type, emphasis variants, background treatments) that remain render-agnostic yet provide enough structure for agents to target magazine layouts.
- **Interactivity hooks**: support for linking sections to timeline events, footnotes, glossary entries, and external resources without tightly coupling to a single UI.
- **Extensibility**: explicit schema versioning plus a mechanism for custom block types so experimental storytellers can iterate without breaking existing renderers.
- **Validation & packaging**: schema validation (JSON Schema or similar), deterministic serialization (likely JSON, YAML, or Markdown+front matter), and guidance for bundling referenced assets (images, transcripts).
- **Accessibility**: text alternatives for imagery, captions/transcripts for audio/video summaries, and semantic markers for screen readers.

## Decisions
- **Serialization format**: Use MDX with YAML front matter. The body stays readable Markdown, while MDX components handle structured media blocks.
- **Media enrichment**: Duplicate basic Apple Music metadata in-document (title, artist, artwork, duration) for offline/placeholder rendering.
- **Rights & authentication**: No credentials stored in the document. Writers and renderers obtain tokens separately.
- **Temporal alignment**: No formal time-coded annotations yet; timestamps can remain part of prose.
- **Personalization**: Omit personalization and territory fallbacks in the initial schema.
- **Authoring workflow**: Agents output directly; humans may hand-edit. Add a validator script to enforce schema rules.
- **Distribution bundles**: Ship as a package (folder/zip) containing the MDX and referenced assets.

## Proposed Base Format
- **Package layout**: `story/` containing `story.mdx` plus an `assets/` folder for images/transcripts.
- **Document body**: Markdown narrative with MDX components for structured blocks.
- **Schema versioning**: `schema_version` in front matter, validated by a JSON Schema.

## Minimal Schema (Draft)
```yaml
schema_version: 0.1
id: "story-001"
title: "Story Title"
subtitle: "Optional dek"
authors: ["Author Name"]
editors: ["Editor Name"]
publish_date: "2026-01-12"
tags: ["genre", "theme"]
locale: "en-US"
hero_image:
  src: "assets/hero.jpg"
  alt: "Alt text"
  credit: "Photographer"
sections:
  - id: intro
    title: "Opening"
    layout: "lede"
    lead_media: "trk-01"
media:
  - key: "trk-01"
    type: "track"
    apple_music_id: "123456789"
    title: "Song Name"
    artist: "Artist Name"
    artwork_url: "https://..."
    duration_ms: 210000
```

```mdx
<Section id="intro" title="Opening" layout="lede">
  ...narrative text...
  <MediaRef ref="trk-01" intent="autoplay" />
</Section>
```

### Required MDX Components (Minimal)
- `Section`: groups content blocks, sets `id`, `title`, and optional `layout`.
- `MediaRef`: embeds a media reference by `ref` and optional `intent` (preview/full, autoplay).

## Open Items / Next Steps
- Prototype one short-form story in the proposed format and run it through at least one renderer (e.g., magazine web experience) to validate the block model.
- Define how agents discover the schema (published spec, JSON Schema, OpenAPI?) and how validation errors are surfaced during generation.
- Expand component list (pull quotes, timelines, footnotes) once the prototype lands.
