---
id: TASK-12
title: Design iOS story renderer architecture
status: Done
assignee: []
created_date: '2026-01-17 05:56'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 112000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document the iOS app architecture for rendering music story documents, covering module boundaries, data flow, renderer components, and MusicKit playback decisions.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Review story schema and renderer requirements.
- Propose app structure and state flow.
- Define MDX/front matter parsing pipeline.
- Decide playback, queueing, and caching approach.
- Record design decisions and open questions.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Design principles (iOS renderer)
- Narrative-first presentation with magazine rhythm: strong hero, generous whitespace, typographic hierarchy, and section-by-section pacing.
- Section layouts honor story schema hints (lede vs body), with lead media cards and clear fallbacks when metadata is missing.
- Liquid Glass usage focuses on controls/overlays (navigation, playback HUD) and avoids glass-on-glass stacking; apply tints/contrast to preserve legibility.
- Playback UX mirrors Apple Music: persistent mini player/glass bar, expandable now-playing view, shared queue, and inline media cards that enqueue without interrupting reading.
- Use materials and blur sparingly around content; keep primary text on solid or lightly tinted surfaces for accessibility.
- Support Dynamic Type, Reduce Transparency, and high-contrast modes; provide clear focus and haptic feedback for media actions.

Captured design principles in doc-4 (iOS story renderer design principles).
Ready to draft architecture/design details next.
<!-- SECTION:NOTES:END -->
