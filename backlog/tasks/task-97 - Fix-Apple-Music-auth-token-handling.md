---
id: TASK-97
title: Fix Apple Music auth token handling
status: Done
assignee: []
created_date: '2026-01-24 21:54'
updated_date: '2026-01-24 21:55'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update walkthrough and docs to load Apple Music developer token so manual sign-in works.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Update walkthrough script to read APPLE_MUSIC_DEVELOPER_TOKEN or APPLE_MUSIC_DEVELOPER_TOKEN_PATH.
- Add README + Backlog doc guidance about providing the developer token.
- Note how to point at external token file.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Walkthrough now loads developer token from env or file, README and doc updated with token guidance.
<!-- SECTION:NOTES:END -->
