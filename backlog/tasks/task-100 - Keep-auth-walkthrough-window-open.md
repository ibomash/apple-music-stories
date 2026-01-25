---
id: TASK-100
title: Keep auth walkthrough window open
status: Done
assignee: []
created_date: '2026-01-25 03:28'
updated_date: '2026-01-25 03:30'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Skip playback assertions during interactive auth so Puppeteer stays open for manual login.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add APPLE_MUSIC_SKIP_PLAYBACK flag to puppeteer_story_test.js.
- Use it in walkthrough script to avoid early exit.
- Explain updated run command.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added APPLE_MUSIC_SKIP_PLAYBACK and use it in walkthrough so browser stays open for manual sign-in.
<!-- SECTION:NOTES:END -->
