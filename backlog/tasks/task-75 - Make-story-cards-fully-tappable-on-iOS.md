---
id: TASK-75
title: Make story cards fully tappable on iOS
status: Done
assignee: []
created_date: '2026-01-23 18:23'
updated_date: '2026-01-23 18:24'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update iOS front page so tapping anywhere on the current story card or available story cards opens the story, not only the Open Story button.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Review iOS front page view for current/available story cards and locate tap handlers.\n- Expand tap target to wrap full card for resume and available stories.\n- Ensure button still works and card tap triggers same navigation.\n- Run relevant iOS tests if available.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Made the current story card a full-card button with a styled call-to-action view.\n- Ran swift test in ios/MusicStoryRenderer.
<!-- SECTION:NOTES:END -->
