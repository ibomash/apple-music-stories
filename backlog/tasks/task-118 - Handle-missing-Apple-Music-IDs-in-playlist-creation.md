---
id: TASK-118
title: Handle missing Apple Music IDs in playlist creation
status: Done
assignee: []
created_date: '2026-01-25 20:13'
updated_date: '2026-01-26 18:01'
labels:
  - ios
dependencies: []
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Skip empty or missing Apple Music IDs when creating story playlists so a single invalid item doesn't fail playlist creation.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Skip empty Apple Music IDs and ignore per-item fetch errors when assembling playlist items so missing catalog entries do not fail playlist creation.\n\nTests:\n- xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" (passed)
<!-- SECTION:NOTES:END -->
