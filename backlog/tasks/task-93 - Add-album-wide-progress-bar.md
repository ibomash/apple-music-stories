---
id: TASK-93
title: Add album-wide progress bar
status: Done
assignee: []
created_date: '2026-01-24 21:42'
updated_date: '2026-01-26 08:15'
labels:
  - ios
dependencies: []
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Show an album-level progress indicator across tracks in the playback UI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Album-wide progress bar appears for album playback.
- [x] #2 Progress updates smoothly as tracks advance.
- [x] #3 Progress resets when album changes.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Define album progress model (total duration vs. played).
- Aggregate track progress into album-wide percent.
- Add UI component to playback screen.
- Update progress as playback advances or track changes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scope confirmed: album progress = sum played time across album tracks / total album duration.
<!-- SECTION:NOTES:END -->

## Execution
- Beads: apple-music-stories-nla
- Status: Done
