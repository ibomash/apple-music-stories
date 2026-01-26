---
id: TASK-87
title: Plan for full music video visuals
status: Done
assignee: []
created_date: '2026-01-23 23:48'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research MusicKit/ApplicationMusicPlayer video playback behavior and propose plan for showing music videos or using SystemMusicPlayer.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Plan:\n1) Keep ApplicationMusicPlayer for audio-first playback of tracks/albums.\n2) For music videos, add an explicit UI action "Open in Music" that uses MediaPlayer (MPMusicPlayerController.systemMusicPlayer.openToPlay or openToPlay queue descriptor) to hand off full video playback to the Music app.\n3) Optionally keep the existing preview-only AVPlayer path for in-app 30s previews (Show Preview button) when preview assets exist.\n4) Update UX copy to clarify that full videos open in Music, while previews play inline.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Findings:\n- MusicKit exposes only MusicVideo preview assets (PreviewAsset.hlsURL/url); no full video stream property in docs.\n- Apple Developer Forums report ApplicationMusicPlayer cannot render music video visuals in-app; recommended to use system Music app via MPMusicPlayerController.systemMusicPlayer.openToPlay.\n- Apple Music assets are DRM-protected; AVPlayer cannot access full streams outside Music app.\nSources: developer.apple.com/forums/thread/694775, MusicKit PreviewAsset docs.
<!-- SECTION:NOTES:END -->
