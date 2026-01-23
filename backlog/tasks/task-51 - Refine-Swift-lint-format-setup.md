---
id: TASK-51
title: Refine Swift lint/format setup
status: Done
assignee: []
created_date: '2026-01-21 01:51'
updated_date: '2026-01-21 01:57'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Exclude build artifacts from SwiftLint, apply SwiftFormat to the iOS package, and address remaining StoryParser.swift lint violations.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Updates:
- Excluded ios/MusicStoryRenderer/.build from SwiftLint.
- Applied SwiftFormat to the iOS package and refactored StoryParser helpers.
- Replaced try! regex init with do/catch and removed front-matter loop lint issues.

Checks:
- swiftformat --lint ios/MusicStoryRenderer (clean).
- swiftlint lint --config ios/MusicStoryRenderer/.swiftlint.yml ios/MusicStoryRenderer (warnings remain for trailing_commas in Package.swift/StoryDocument/StoryDocumentStore plus StoryParser size/complexity warnings; no errors).
<!-- SECTION:NOTES:END -->
