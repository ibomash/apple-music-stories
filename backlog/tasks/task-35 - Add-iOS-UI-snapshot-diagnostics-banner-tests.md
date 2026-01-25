---
id: TASK-35
title: Add iOS UI snapshot + diagnostics banner tests
status: Done
assignee: []
created_date: '2026-01-19 21:38'
updated_date: '2026-01-24 21:54'
labels:
  - macOS
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add snapshot coverage for core renderer screens and diagnostics banner UI.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Decide snapshot framework and baseline configs.
- Add snapshots for StoryRendererView, media cards, playback bar, now-playing sheet.
- Add diagnostics banner snapshots once banner UI exists.
- Wire into CI/test guidance.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Added SnapshotTesting package and new UI snapshot tests covering StoryRendererView, media cards, playback bar, now playing sheet, and launch diagnostics section.
- Regenerated Xcode project via XcodeGen.
- xcodebuild test failed during package resolution: existing swift-syntax repo in DerivedData (see ResultBundle_2026-24-01_16-54-0023.xcresult).
<!-- SECTION:NOTES:END -->
