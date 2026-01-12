---
id: doc-3
title: HTML Story Renderer Spec
type: spec
created_date: '2026-01-12 18:47'
---

## Summary
Define an HTML renderer that transforms a music story MDX package into a magazine-style web page. The renderer must support both static exports (HTML file + assets) and a local server that lists available stories and serves the rendered output on demand.

## Goals
- Render story documents that follow the schema in `backlog/docs/docs/design/doc-1 - Music-Story-Document-Format.md`.
- Produce a high-fidelity, magazine-like HTML layout with hero imagery, rich typography, and media callouts.
- Support two output modes: static HTML export and a local story browser server.
- Integrate MusicKit JS with playback authorization, a shared queue, and per-card playback controls.
- Ensure renderer fallbacks align with `doc-1` requirements and existing validation tooling.

## Non-Goals
- Authoring or editing tools for story documents.
- Localization, personalization, or territory-aware rendering beyond basic metadata display.

## Inputs
- Path to a `story.mdx` file or a story package folder containing `story.mdx` + `assets/`.
- Story front matter and body must conform to the schema in `doc-1`.
- Target directories: `stories/` and `examples/` are the default discovery roots for server mode.

## Output Modes
### Static Export
- CLI input: `render --input <story path> --output <dir>`.
- Output directory contains `index.html` plus copied `assets/` (local images, transcripts).
- Generated HTML should be standalone (no build pipeline) and reference local assets with relative URLs.

### Server Mode
- CLI input: `render serve --stories <dir>`.
- Landing page lists each story (title, subtitle, hero image, tags).
- Clicking a story navigates to `/stories/<id>` and serves rendered HTML.
- Optionally cache rendered output in memory for faster navigation.

## Rendering Model
- Parse YAML front matter into metadata, `sections`, and `media` collections.
- Parse MDX body and render Markdown to HTML, treating `Section` and `MediaRef` as custom nodes.
- `Section` defines layout boundaries; `layout=lede` is rendered with hero treatment and lead media.
- `MediaRef` resolves against the `media` list by `key` and renders a media card.
- Each media card includes artwork, title, artist, type label, and embedded Apple Music playback controls.
- Section ordering follows the MDX body, but section metadata should be validated against `sections`.
- The page hosts a shared MusicKit JS queue and global playback controls, updated by media card interactions.

## Layout & Style Requirements
- Magazine-style layout with generous whitespace and strong typography hierarchy.
- Hero region: title, subtitle, byline, publish date, hero image + credit.
- Section headers are prominent; body copy uses legible serif type.
- Media cards align with narrative flow and include MusicKit JS controls.
- Include a persistent global playback bar with current queue context.
- Responsive design: single-column on mobile, multi-column grid on desktop.

## Fallbacks & Validation
- Reuse fallback behavior from `doc-1` (missing hero image, missing subtitle, missing media artwork).
- Use `scripts/validate_story.py` during render to surface schema issues.
- If a `MediaRef` is missing, render a warning placeholder instead of crashing.
- If MusicKit authorization fails, show a non-blocking UI state with disabled playback controls.

## Implementation Notes
- Prefer Python for the initial renderer to align with `scripts/validate_story.py`.
- Use a Markdown parser with extensions for MDX-like custom tags; map `Section`/`MediaRef` to HTML templates.
- Embed MusicKit JS and handle developer token + user token authorization flows.
- Keep template code modular for playback controls and queue management.
- Ensure deterministic output for the same input (stable HTML ordering and IDs).

## Acceptance Criteria
- Rendering `examples/sample-story/story.mdx` produces a complete HTML page with hero, sections, and media cards.
- Media cards enqueue and control playback through a shared MusicKit JS queue.
- Global playback controls reflect the current track and queue state.
- Server mode lists stories and serves per-story routes without errors.
- Static export produces a self-contained folder suitable for direct browser viewing.
