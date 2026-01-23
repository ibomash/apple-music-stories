---
id: task-32
title: Now playing metadata refresh
status: Done
assignee: []
created_date: '2026-01-18 20:17'
updated_date: '2026-01-18 20:32'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Observe SystemMusicPlayer state to keep playback bar and now-playing sheet in sync.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Observe SystemMusicPlayer.shared.state or queue changes.
- Update playback controller to publish now-playing metadata.
- Wire UI to display refreshed metadata.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Observed SystemMusicPlayer state/queue via objectWillChange, added now-playing metadata model, wired playback bar/sheet to metadata, and added metadata tests. Swift tests passing.
<!-- SECTION:NOTES:END -->
