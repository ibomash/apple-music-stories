---
id: TASK-76
title: Polish music video playback UI
status: Done
assignee: []
created_date: '2026-01-23 18:56'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove redundant Done button from video player overlay and improve video thumbnails in story media cards.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Remove the extra Done button overlay in the full-screen video player.
- Improve media card artwork rendering for music videos, including a video-specific placeholder when artwork is missing.
- Confirm media story data for video items provides artwork URLs; adjust fallback if needed.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Follow-up to TASK-74. User feedback: Done button duplicates built-in AVPlayer close affordance; story view shows gray squircle for video thumbnails.

Removed the extra Done button from the video player overlay and added a video-specific thumbnail treatment in story media cards (play icon overlay + film placeholder when artwork is missing).
<!-- SECTION:NOTES:END -->
