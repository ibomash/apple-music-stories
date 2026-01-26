---
id: TASK-70
title: Bundle local stories into iOS build
status: Done
assignee: []
created_date: '2026-01-23 16:10'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Include all stories from stories/ in the iOS app bundle so they ship with the build.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Bundled stories directory via XcodeGen resources; StoryDocumentStore now loads bundled story packages when sample is missing. Added tests for bundled story loading; xcodegen + xcodebuild test succeeded.
<!-- SECTION:NOTES:END -->
