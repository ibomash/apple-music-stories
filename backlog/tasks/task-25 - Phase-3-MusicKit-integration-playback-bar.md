---
id: TASK-25
title: 'Phase 3: MusicKit integration + playback bar'
status: Done
assignee: []
created_date: '2026-01-17 19:05'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 98000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate MusicKit authorization and playback, plus the persistent playback bar and now-playing sheet.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Review existing playback queue stub and current playback controller surface.
- Add MusicKit authorization handling and now-playing state to the playback controller.
- Introduce persistent playback bar + now-playing sheet UI in the renderer.
- Wire media card actions to MusicKit-backed playback controller and state updates.
- Add tests for playback controller state (queue + now-playing updates, authorization).
- Run Swift tests in ios/MusicStoryRenderer after swiftenv init.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented MusicKit-backed playback controller with authorization handling, added persistent playback bar + now-playing sheet at app root, and added authorization/status tests. Swift tests passing.
<!-- SECTION:NOTES:END -->
