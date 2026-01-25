---
id: TASK-69
title: Add story bookmarking (scroll position)
status: Done
assignee: []
created_date: '2026-01-23 14:49'
updated_date: '2026-01-24 21:43'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Persist the last scroll position per story and restore it when reopening the story.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Locate the story reading view and identify where scroll position can be observed.
- Persist a per-story scroll offset in local storage (likely UserDefaults/AppStorage).
- Restore the scroll position when the story view appears, handling layout timing.
- Add tests or diagnostics coverage if feasible.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Added StoryBookmarkStore and wired StoryRendererView to persist/restore ScrollPosition per story.
- Added StoryBookmarkStoreTests for save/clear behavior.
- Tests: XcodeBuildMCP_test_sim (scheme MusicStoryRenderer).

- Updated scroll restore logic to use anchored scrollPosition, point-based ScrollPosition, and restore guard to avoid skipping saves.
- Tests: XcodeBuildMCP_test_sim (scheme MusicStoryRenderer).

- Switched scrollPosition init to point-based ScrollPosition so y updates are available.
- Tests: XcodeBuildMCP_test_sim (scheme MusicStoryRenderer).

- Switched scrollPosition to CGFloat-based y tracking and scrollTo(y:) to improve offset updates.
- Tests: XcodeBuildMCP_test_sim (scheme MusicStoryRenderer).

- Replaced scrollPosition approach with anchor tracking using PreferenceKey + ScrollViewReader.
- Bookmark now stores nearest visible anchor ID (header/section/block) and restores via scrollTo.
- Tests: XcodeBuildMCP_test_sim (scheme MusicStoryRenderer).
<!-- SECTION:NOTES:END -->
