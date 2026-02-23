---
id: TASK-130
title: 'iOS: Story card long-press actions'
status: Done
assignee: []
created_date: '2026-01-26 19:07'
updated_date: '2026-02-23 14:43'
labels:
  - ios
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a long-press menu to story cards on the Main Screen with options to copy a story link and create a playlist.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented the story-card context menu updates on the launch screen so each card now exposes `Copy Story Link` and `Create Playlist` actions together.

Behavior updates:
- Added a launch-screen callback to create a playlist from the long-press menu for the selected story card.
- Added unit tests for story-card context menu action composition, including `Create Playlist` and source-specific delete behavior.

Tests:
- xcodebuild test -project ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:MusicStoryRendererTests/StoryCatalogContextMenuBuilderTests
- xcodebuild test -project ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:MusicStoryRendererTests/StorySnapshotTests/testLaunchDiagnostics
<!-- SECTION:NOTES:END -->
