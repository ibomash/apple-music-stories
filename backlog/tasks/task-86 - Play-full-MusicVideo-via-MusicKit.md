---
id: TASK-86
title: Play full MusicVideo via MusicKit
status: Done
assignee: []
created_date: '2026-01-23 22:46'
updated_date: '2026-01-23 22:50'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update music video playback to use ApplicationMusicPlayer if possible (fallback to SystemMusicPlayer) for full-length playback instead of preview assets.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Updates:\n- Music videos now use MusicKit playback with ApplicationMusicPlayer (fallback to SystemMusicPlayer) instead of preview AVPlayer streams; intent for music videos resolves to full playback.\n- In-app preview button only appears when a preview URL is available.\nTests: ./scripts/ios.sh swift-test
<!-- SECTION:NOTES:END -->
