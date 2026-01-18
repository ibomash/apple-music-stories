---
id: task-24
title: 'Phase 2: Media cards + queue stub'
status: Done
assignee: []
created_date: '2026-01-17 19:05'
updated_date: '2026-01-18 19:02'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add media card rendering and stub playback queue state so play/queue actions update UI without MusicKit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Playback queue stub has unit tests covering play/queue behavior.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Define playback queue state models and status helpers in the core models.
- Publish queue state from the playback controller and update play/queue actions to mutate stub state.
- Refresh media card UI to surface play/queue controls and queued/playing status.
- Add unit tests covering queue state updates and status calculations.
<!-- SECTION:PLAN:END -->
