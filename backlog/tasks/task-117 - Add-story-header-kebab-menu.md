---
id: TASK-117
title: Add story header kebab menu
status: Done
assignee: []
created_date: '2026-01-25 20:00'
updated_date: '2026-01-25 20:03'
labels:
  - ios
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a kebab menu affordance in the story header (title bar) to access actions like creating a playlist, so users don't need to scroll to the end.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added a kebab menu in the story header with a Create Story Playlist action tied to MusicKit playlist creation status.\n\nTests:\n- xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" (passed; snapshots re-recorded)
<!-- SECTION:NOTES:END -->
