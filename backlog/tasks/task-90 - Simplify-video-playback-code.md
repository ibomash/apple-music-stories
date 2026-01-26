---
id: TASK-90
title: Simplify video playback code
status: Done
assignee: []
created_date: '2026-01-24 02:10'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove in-app video preview/full-screen playback and keep only Music app handoff for music videos.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Changes:\n- Removed AVPlayer-based video preview/session code and full-screen cover UI.\n- Music videos now only open in Apple Music (no in-app video state).\nTests: ./scripts/ios.sh swift-test
<!-- SECTION:NOTES:END -->
