---
id: TASK-63
title: Fix developer token request failure
status: Done
assignee: []
created_date: '2026-01-23 02:39'
updated_date: '2026-01-23 03:36'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate and resolve the 'Failed to request developer token' playback error in the iOS app.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Added MusicKit entitlements file (com.apple.developer.music-user-token) and wired it into project.yml so the app can request the developer token.
- Regenerate the Xcode project with `xcodegen generate` before building.
- Tests: `./scripts/ios.sh swift-test`.

- Adjusted XcodeGen config to set CODE_SIGN_ENTITLEMENTS instead of top-level entitlements; regenerated the Xcode project.

- Simulator playback is not supported: MusicKit/MPMusicPlayerController reports it is unavailable on Simulator, so playback must be verified on a physical device. See console: "MPMusicPlayerController is not available on the simulator".
<!-- SECTION:NOTES:END -->
