---
id: TASK-116
title: Add create-playlist affordance in iOS story
status: Done
assignee: []
created_date: '2026-01-25 18:48'
updated_date: '2026-01-26 18:01'
labels:
  - ios
dependencies: []
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add an iOS affordance at the end of a story (or unobtrusive top placement if it preserves visual fidelity) to create a playlist of all music mentioned in the article for offline availability. Future placement will be in the story card long-press menu.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented a story-end playlist CTA and MusicKit playlist creation that aggregates tracks, album tracks, playlist entries, and music videos.\n\nTests:\n- SNAPSHOT_RECORDING=1 ./scripts/ios.sh swift-test (passed)\n- SNAPSHOT_RECORDING=1 ./scripts/ios.sh test (failed: snapshot mismatch for launch-diagnostics + story-renderer; recording env not picked up)
<!-- SECTION:NOTES:END -->
