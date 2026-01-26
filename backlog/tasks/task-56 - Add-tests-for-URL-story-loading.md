---
id: TASK-56
title: Add tests for URL story loading
status: Done
assignee: []
created_date: '2026-01-21 03:22'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 72000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add unit tests covering remote story loading and StoryDocumentStore state updates, then build/run the iOS app to verify the new URL flow.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Added unit tests for remote loader and StoryDocumentStore URL loading.
- Updated core remote loader to be Sendable for Swift 6 concurrency.
- Regenerated Xcode project and ran swift test + xcodebuild test.
- Built and launched the app on the iPhone 16 simulator.
<!-- SECTION:NOTES:END -->
