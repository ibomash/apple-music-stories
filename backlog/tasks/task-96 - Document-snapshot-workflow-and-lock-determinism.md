---
id: TASK-96
title: Document snapshot workflow and lock determinism
status: Done
assignee: []
created_date: '2026-01-25 00:26'
updated_date: '2026-01-25 00:37'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add snapshot test documentation and enforce deterministic locale/timezone/dynamic type settings so snapshots are stable.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Documented snapshot recording/verification workflow and deterministic settings in ios/development.md.
- Added deterministic locale/timezone/dynamic type defaults to StorySnapshotTests and updated launch diagnostics baseline snapshot.
- Tests: xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16"
<!-- SECTION:NOTES:END -->
