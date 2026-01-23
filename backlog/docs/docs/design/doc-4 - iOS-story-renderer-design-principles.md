---
id: doc-4
title: iOS story renderer design principles
type: design
created_date: '2026-01-17 14:36'
---

## Purpose
Define the experience, visual language, and playback UI principles for the iOS renderer so future implementation work stays coherent across layout, motion, and MusicKit controls.

## Narrative Presentation
- **Magazine rhythm**: Use generous whitespace, consistent margins, and a structured type scale (title → dek → body) to keep long-form reading comfortable.
- **Hero focus**: Lead with a hero image (or gradient fallback) plus title/subtitle metadata to anchor the story identity.
- **Section pacing**: Honor `Section` layout hints (`lede` vs `body`) with tighter or looser spacing and optional lead media.
- **Inline media**: Keep `MediaRef` blocks embedded within the narrative so media highlights feel like part of the story, not a separate feed.

## Layout & Interaction
- **Single-scroll narrative**: Readers should be able to read start-to-finish without changing tabs or modes.
- **Sticky context cues**: Section titles can reappear as subtle headers when scrolling long sections, but never eclipse the content.
- **Progress cues**: Offer gentle progress indicators (e.g., subtle page position or chapter markers) without distracting from reading.
- **Tap targets**: Media cards and playback actions should be large, high-contrast, and accessible for quick taps.

## Liquid Glass Language
- **Controls float above content**: Reserve glass materials for navigation bars, playback HUDs, and context menus, not the story body.
- **Avoid stacking**: Don’t place glass surfaces on top of other glass surfaces; keep text overlays on solid/tinted backgrounds.
- **Legibility first**: Apply subtle tints and shadowing behind text in glass surfaces to preserve readability and contrast.
- **Respect system settings**: Honor Reduce Transparency and increase contrast options by falling back to opaque backgrounds.

## Playback UX
- **Shared queue**: All inline media cards enqueue into one global queue to prevent fragmented playback.
- **Mini player**: Provide a persistent, compact now-playing bar that floats at the bottom and expands into a full player view.
- **Non-disruptive playback**: Inline play actions should not yank scroll position or cover the narrative; playback stays ambient.
- **Preview vs full**: If preview-only playback is required, clearly indicate it and keep controls consistent.

## Accessibility & Motion
- **Dynamic Type**: Allow text scaling without breaking layout; keep media cards flexible.
- **Reduced motion**: Use subtle transitions; avoid parallax or heavy motion effects for glass layers.
- **VoiceOver semantics**: Ensure section headings, media cards, and playback actions have clear labels.

## Implementation Notes
- Use SwiftUI `Material` for glass surfaces, with safe-area insets to float playback controls above content.
- Keep main body text on solid backgrounds; use tinted panels for metadata or quotes.
- Start with reusable components (`StoryHeaderView`, `MediaReferenceView`, `PlaybackBarView`) so the app scales with new block types.
