---
id: TASK-77
title: Add swipe-down dismiss for video playback
status: Done
assignee: []
created_date: '2026-01-23 21:24'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Allow dismissing the full-screen video playback view with a downward swipe gesture.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a drag gesture to the full-screen video container.
- Track vertical drag offset and dismiss when threshold exceeded.
- Reset the offset when the gesture is cancelled or too short.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Video playback is presented via fullScreenCover in ios/MusicStoryRenderer/App/MusicStoryRendererApp.swift.

Added a drag gesture to the full-screen video container; downward swipes past the threshold dismiss the video, with a spring reset if not met.
<!-- SECTION:NOTES:END -->
