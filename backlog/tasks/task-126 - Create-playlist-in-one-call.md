---
id: TASK-126
title: Create playlist in one call
status: Done
assignee: []
created_date: '2026-01-26 00:02'
updated_date: '2026-01-26 00:03'
labels:
  - ios
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Use MusicLibrary createPlaylist(items:) to add songs in one call (and only add remaining videos if needed) to reduce per-item add calls during playlist creation.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Switched playlist creation to createPlaylist(items:) for songs (or videos if no songs) and only add videos afterward if present. Updated progress UI to drop per-item counts during creation while keeping summary counts on completion.\n\nTests:\n- xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" (failed: entitlements file modified during build)
<!-- SECTION:NOTES:END -->
