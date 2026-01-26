---
id: TASK-89
title: Make music video button open Music app
status: Done
assignee: []
created_date: '2026-01-24 00:16'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace in-app music video playback with a single story view action that opens Apple Music for full video.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Changes:\n- Music video play actions now open Apple Music directly and no longer route through in-app playback for videos.\n- Story card shows a single "Play Video in Music app" button with no queue option.\n- Now Playing sheet shows the same Music app handoff label when applicable.\nTests: ./scripts/ios.sh swift-test
<!-- SECTION:NOTES:END -->
