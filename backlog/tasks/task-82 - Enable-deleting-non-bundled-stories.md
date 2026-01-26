---
id: TASK-82
title: Enable deleting non-bundled stories
status: Done
assignee: []
created_date: '2026-01-23 22:24'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Allow users to delete non-built-in stories from the Available Stories list with a clear interaction and confirmation.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Added long-press context menu delete action for non-bundled stories with confirmation dialog.\n- StoryDocumentStore now deletes recent local entries or saved remote stories, with warning diagnostics on failure.\n- Tests: swift test (ios/MusicStoryRenderer).
<!-- SECTION:NOTES:END -->
