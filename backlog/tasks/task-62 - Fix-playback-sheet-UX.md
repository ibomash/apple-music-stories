---
id: TASK-62
title: Fix playback sheet UX
status: Done
assignee: []
created_date: '2026-01-23 02:39'
updated_date: '2026-01-23 02:49'
labels:
  - ui
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define and implement a better playback sheet experience after tapping Play in the story view (dismissal, layout, and state handling).
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Design desired playback sheet UX (layout, dismissal affordances, and error messaging).
- Inspect current sheet presentation and state triggers after tapping Play.
- Implement the UX changes and dismissal controls.
- Verify sheet behavior on simulator (open, dismiss, no layout offsets).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Design (proposed):
- Show a mini playback bar after tapping Play; only open the sheet when the bar is tapped.
- Add a clear Done/Close button in the sheet (navigation bar) that calls dismiss.
- Use the system drag indicator instead of a custom capsule; keep detents at medium/large.
- In the sheet, show track metadata, play/pause + next, and surface errors in a callout.
- Keep the sheet dismissible via swipe and the Done button, with no layout shifts on return.

Implementation:
- Updated NowPlayingSheetView to use a NavigationStack with a Done button and visible drag indicator.
- Added authorization banner inside the sheet and wrapped errors in a callout-style label.
- Verified on simulator: tapping the playback bar opens the sheet with Done and Now Playing title; Done dismisses the sheet.
<!-- SECTION:NOTES:END -->
