---
id: TASK-27
title: Add test guidance and parser tests
status: Done
assignee: []
created_date: '2026-01-17 19:53'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 96000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update AGENTS.md with test expectations and add initial Swift package tests for the StoryParser and StoryPackageLoader.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added test-running requirement to AGENTS.md, created SwiftPM package and tests for StoryParser/StoryPackageLoader, attempted to run swift test but Swift toolchain is missing in this environment.

Re-ran swift test with Swift 6.2.3; fixed Linux build issues by excluding StoryDocumentStore from SwiftPM target and guarding security-scoped URL access. Tests now pass.
<!-- SECTION:NOTES:END -->
