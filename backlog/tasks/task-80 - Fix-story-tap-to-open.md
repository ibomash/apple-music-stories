---
id: TASK-80
title: Fix story tap to open
status: Done
assignee: []
created_date: '2026-01-23 22:15'
updated_date: '2026-01-23 22:20'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ensure tapping a story under Available Stories opens the story detail in iOS main view.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Updated story selection to open immediately when the tapped story is already loaded.\n- Added StoryDocumentStore.isCurrentStory helper + tests for match/mismatch.\n- Tests: swift test (ios/MusicStoryRenderer).\n- Simulator: xcodegen generate + XcodeBuildMCP_build_run_sim; tapped Available Stories item and confirmed story view shows title.
<!-- SECTION:NOTES:END -->
