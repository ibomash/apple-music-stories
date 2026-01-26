---
id: TASK-66
title: Fix invalid music user token entitlement
status: Done
assignee: []
created_date: '2026-01-23 12:36'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Resolve the iOS signing error about com.apple.developer.music-user-token by removing or correcting the entitlement and updating project settings.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Locate the entitlements file and signing settings referencing the entitlement.
- Update entitlements/project configuration to match the app's enabled capabilities.
- Run relevant tests/builds to verify signing succeeds.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Removed com.apple.developer.music-user-token from MusicStoryRenderer.entitlements to avoid invalid entitlement during signing.
- Tests not run (entitlements change; Xcode/iOS build environment not exercised here).
<!-- SECTION:NOTES:END -->
