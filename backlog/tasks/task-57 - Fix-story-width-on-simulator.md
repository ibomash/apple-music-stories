---
id: TASK-57
title: Fix story width on simulator
status: Done
assignee: []
created_date: '2026-01-22 21:10'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Story content overflows width on iPhone 17 simulator; constrain layout to device width.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Pinned story scroll content to available width with maxWidth frame in StoryRendererView to prevent overflow on iPhone 17 simulator.
<!-- SECTION:NOTES:END -->
