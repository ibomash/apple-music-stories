---
id: TASK-102
title: Fix MusicKit playback test
status: Later
assignee: []
created_date: '2026-01-25 04:16'
labels:
  - HTML renderer
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate why MusicKit playback does not start in Puppeteer playback test and make it reliable.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Observed:
- Playback test times out waiting for MusicKit.getInstance().isPlaying.
- Page console logs show MusicKit loaded but two 404 resource errors.
- Placeholder IDs in sample story are invalid; switched test to hip-hop story + media key trk-alright (Apple Music catalog 200), but still no playback.
- Authorization completes via walkthrough (HTTPS), yet playback does not start.

Ideas to try:
- Capture network failures (request URLs + status) in Puppeteer to pinpoint 404s.
- Log MusicKit state after clicking play: nowPlayingItem, playbackState, authorization status, last error.
- Verify that playback requires a Music User Token scoped to https://127.0.0.1:8443 and that the saved profile contains it.
- Try a song ID (not album/playlist) with known availability for the logged-in storefront; confirm region mismatches.
- Consider using MusicKit setQueue with song ID via page.evaluate to isolate UI click issues.
<!-- SECTION:NOTES:END -->
