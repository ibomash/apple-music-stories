---
id: TASK-88
title: Implement Open in Music video playback
status: Done
assignee: []
created_date: '2026-01-23 23:59'
updated_date: '2026-01-23 23:59'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Wire music video playback to open full videos in Apple Music and show optional preview UI when space allows.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Changes:\n- Added MediaPlayer handoff for music videos (openInMusic) using MPMusicPlayerStoreQueueDescriptor.\n- Preserve preview URL for videos to enable optional preview button; preview only shown at large sheet detent.\n- Updated Now Playing sheet buttons to Open in Music + Preview Video (conditional) and adjusted music video play/queue labels to audio-focused copy.\nTests: ./scripts/ios.sh swift-test; XcodeBuildMCP_build_sim
<!-- SECTION:NOTES:END -->
