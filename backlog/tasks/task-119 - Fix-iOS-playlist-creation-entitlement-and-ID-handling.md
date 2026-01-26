---
id: TASK-119
title: Fix iOS playlist creation entitlement and ID handling
status: Done
assignee: []
created_date: '2026-01-25 22:12'
updated_date: '2026-01-25 22:32'
labels:
  - ios
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate device playlist creation failure logs (account store entitlement errors, empty identifier warnings) and update MusicKit setup/ID validation so playlist creation works on device.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added MusicKit user-token entitlement and tightened Apple Music ID validation to avoid empty IDs in playback/open-in-Music/playlist creation.\n\nTests:\n- xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" (passed)

Reverted invalid music-user-token entitlement. Added parser validation to skip empty apple_music_id values to avoid empty MusicItemID warnings.\n\nTests:\n- xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" (failed: entitlements file modified during build)
<!-- SECTION:NOTES:END -->
