---
id: TASK-64
title: Fix story Play button overlay UX
status: Done
assignee: []
created_date: '2026-01-23 03:05'
updated_date: '2026-01-23 03:17'
labels:
  - ui
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Adjust story Play button behavior so playback UI is dismissible and artwork sizing stays within the sheet.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Root cause: NowPlayingArtworkView had no explicit frame, so the playback bar expanded to full-screen size.
- Fix: add size/cornerRadius parameters and apply fixed frame; pass size 56 in PlaybackBarView and 180 in NowPlayingSheetView.
- Verified: tapping Play now shows a compact playback bar at the bottom; Now Playing sheet remains dismissible via Done.
<!-- SECTION:NOTES:END -->
