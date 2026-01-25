---
id: TASK-94
title: Add long-press option for media links
status: Done
assignee: []
created_date: '2026-01-24 21:42'
updated_date: '2026-01-25 14:00'
labels:
  - ios
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Support long-press actions on media links (e.g., copy/open options).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Long-press shows actions for media links.
- [ ] #2 Actions perform expected behavior.
- [ ] #3 Standard tap behavior remains unchanged.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add long-press gesture handling for media links.
- Present action sheet with available actions.
- Implement actions (open in Music, copy link, share).
- Ensure accessibility labels for long-press actions.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scope confirmed: long-press shows Open in Music, Copy Link, Share actions.

Implemented media long-press menu (Open in Music, Copy Link, Share) and enabled Open in Music for all media types. Tests: swift test.
<!-- SECTION:NOTES:END -->
