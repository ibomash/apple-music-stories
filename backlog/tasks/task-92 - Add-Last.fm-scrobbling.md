---
id: TASK-92
title: Add Last.fm scrobbling
status: Later
assignee: []
created_date: '2026-01-24 21:42'
updated_date: '2026-01-24 21:47'
labels:
  - ios
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate Last.fm scrobbling for playback events in the iOS app.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 User can connect/disconnect Last.fm account.
- [ ] #2 Scrobbles are sent for tracks played.
- [ ] #3 Failures are retried or queued without blocking playback.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add Last.fm auth flow and token storage.
- Send scrobble payloads for playback events.
- Add settings toggle and status indicator.
- Handle retries and offline queueing.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scope confirmed: scrobble on track start + update at 50% playtime; Last.fm user auth required.
<!-- SECTION:NOTES:END -->
