---
id: TASK-71
title: Show available stories on launch
status: Done
assignee: []
created_date: '2026-01-23 16:33'
updated_date: '2026-01-23 16:52'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Expose bundled, saved URL, and recently loaded stories on the launch screen for quick selection.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented launch story catalog with bundled/saved/recent sources sorted by recency. Added persistence for recent local stories + recency tracking, UI cards, and tests. xcodegen + xcodebuild test succeeded (warnings only).
<!-- SECTION:NOTES:END -->
