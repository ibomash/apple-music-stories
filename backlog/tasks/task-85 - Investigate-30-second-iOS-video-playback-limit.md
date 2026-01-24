---
id: TASK-85
title: Investigate 30-second iOS video playback limit
status: Done
assignee: []
created_date: '2026-01-23 22:39'
updated_date: '2026-01-23 22:43'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Look into why iOS app video playback stops at 30 seconds; inspect code and relevant Apple docs, and capture likely causes.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Findings:\n- Code uses MusicKit MusicVideo.previewAssets (preview HLS/URL) and feeds that into AVPlayer (AppleMusicPlaybackController.makePlaybackTarget + startVideoPlayback).\n- Preview assets are 30-second clips by Apple Music design; docs and Apple Music spec indicate music video previews are clipped to 30 seconds.\n- Full-length playback likely requires a different playback path (SystemMusicPlayer/ApplicationMusicPlayer queueing MusicVideo or Apple Music API asset URLs with user token).
<!-- SECTION:NOTES:END -->
