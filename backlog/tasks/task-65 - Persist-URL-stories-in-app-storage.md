---
id: TASK-65
title: Persist URL stories in app storage
status: Done
assignee: []
created_date: '2026-01-23 03:41'
updated_date: '2026-01-23 04:03'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ensure stories loaded from URL are stored locally and can be removed.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
UX
- When a URL story is successfully loaded, show it as the current story on launch and note the source host.
- Add a destructive \"Delete saved story\" action with confirmation to remove the persisted URL story.
- If loading the saved URL story fails, keep the error state visible but still surface the delete action.

Technical
- Add a persistence helper that stores the remote story text + source URL (JSON) in Application Support.
- Load persisted remote stories at startup before falling back to bundled samples.
- Update StoryDocumentStore to track persisted story metadata and delete/reset state when removed.
- Extend tests to cover saving, loading, and deleting persisted URL stories.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed
- Added URL story persistence (FilePersistedRemoteStoryStore) and wired StoryDocumentStore to save/load/delete.
- Updated launch UI to surface saved URL story details and deletion confirmation.
- Updated startup flow to load persisted stories before bundled samples.
- Added/updated StoryDocumentStoreTests for persistence coverage.

Tests
- ./scripts/ios.sh test
<!-- SECTION:NOTES:END -->
