---
id: TASK-98
title: Fix Puppeteer auth script hang
status: Done
assignee: []
created_date: '2026-01-24 22:02'
updated_date: '2026-01-24 22:02'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Stop puppeteer_story_test.js from hanging after interactive sign-in by closing stdin.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Update waitForEnter to pause stdin after receiving input.
- Note expected behavior after sign-in.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Paused stdin after interactive prompt so Node can exit cleanly.
<!-- SECTION:NOTES:END -->
