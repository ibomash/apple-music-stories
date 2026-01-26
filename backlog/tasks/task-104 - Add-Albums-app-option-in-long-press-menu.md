---
id: TASK-104
title: Add Albums app option in long-press menu
status: Next
assignee: []
created_date: '2026-01-25 14:35'
updated_date: '2026-01-26 03:50'
labels:
  - ios
dependencies: []
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a long-press menu option to open the current item in the Albums app, shown below \"Open in Music\".

Requirements:
- Menu item only appears when the Albums app is installed (probe URL scheme).
- Use albums:// scheme with canOpenURL gating.
- Add albums to LSApplicationQueriesSchemes in Info.plist.

Notes:
- iOS generally cannot enumerate installed apps; use canOpenURL on a registered scheme.
- Optional: attempt open and handle success callback if needed.
- Reference: https://www.reddit.com/r/albumstheapp/comments/1ob11w9/share_albums_link_album_couldnt_be_loaded/
<!-- SECTION:DESCRIPTION:END -->
