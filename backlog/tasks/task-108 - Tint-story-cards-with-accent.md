---
id: TASK-108
title: Tint story cards with accent
status: Done
assignee: []
created_date: '2026-01-25 15:41'
updated_date: '2026-01-25 15:45'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tint each story card background with a subtle accent color derived from the story accent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Story cards on iOS main screen show a subtle accent-tinted background.
- [ ] #2 Tint is noticeable but not overpowering (keeps text legible).
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Locate the iOS home/main screen card view styling.
- Add a gentle accent tint layer or background color blend.
- Verify contrast and subtlety across cards.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Added accent color to story metadata snapshot and applied subtle tint overlay on story cards.
- Ran swift package tests: XcodeBuildMCP_swift_package_test (ios/MusicStoryRenderer).
- Ran iOS simulator (iPhone 17 Pro) and captured screenshot for main screen tint verification.
<!-- SECTION:NOTES:END -->
