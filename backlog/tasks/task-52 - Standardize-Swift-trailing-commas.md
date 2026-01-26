---
id: TASK-52
title: Standardize Swift trailing commas
status: Done
assignee: []
created_date: '2026-01-21 02:04'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 76000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Align SwiftLint to require trailing commas and relax StoryParser lint thresholds without splitting the file.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Updates:
- Updated ios/MusicStoryRenderer/.swiftlint.yml to require trailing commas and raise thresholds for StoryParser size/complexity warnings.

Checks:
- swiftlint lint --config ios/MusicStoryRenderer/.swiftlint.yml ios/MusicStoryRenderer (clean).
- swiftformat --lint ios/MusicStoryRenderer (clean).
<!-- SECTION:NOTES:END -->
