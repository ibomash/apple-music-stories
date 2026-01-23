---
id: TASK-61
title: Investigate play button sheet
status: Done
assignee: []
created_date: '2026-01-23 00:58'
updated_date: '2026-01-23 02:34'
labels:
  - ui
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Load a story in the simulator, tap the first Play button, and capture what UI appears and how (or if) it can be dismissed.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Loaded https://bomash.net/story.mdx and tapped the first Play button.
- A bottom sheet appears with a Sheet Grabber, track info (Rap Life / Apple Music Hip-Hop), play/forward buttons, and a 'Failed to request developer token' message.
- No Close/Done/Back control is exposed on the sheet.
- Tapping the Sheet Grabber (single taps) did not collapse it; swipe-down on the grabber removed the sheet but left the story view offset with large negative x frames in describe_ui.
<!-- SECTION:NOTES:END -->
