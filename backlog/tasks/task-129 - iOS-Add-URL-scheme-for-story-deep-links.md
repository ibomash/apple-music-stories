---
id: TASK-129
title: 'iOS: Add URL scheme for story deep links'
status: Done
assignee: []
created_date: '2026-01-26 19:07'
updated_date: '2026-02-23 19:00'
labels:
  - ios
dependencies: []
documentation:
  - doc-15
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a custom URL scheme and handler to auto-open a particular story.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented iOS story deep links with deterministic story codes and a custom URL scheme handler to auto-open matching stories from the launch catalog.

Spec:
- backlog/docs/doc-15 - iOS-story-deep-link-spec.md

Behavior updates:
- Added custom URL scheme support for apple-music-stories://story/<code> and apple-music-stories:/story/<code>.
- Added long-press action on story cards to copy a story-specific deep link.

Tests:
- xcodebuild test -project ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:MusicStoryRendererTests/StoryDocumentStoreTests
<!-- SECTION:NOTES:END -->
