---
id: TASK-78
title: Update hip-hop story video links
status: Done
assignee: []
created_date: '2026-01-23 21:35'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Find full Apple Music video references for the hip-hop story and replace preview links in story.mdx with the full catalog URLs.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Blocked: APPLE_MUSIC_DEVELOPER_TOKEN not set for Apple Music catalog searches.

Apple Music API search failed: 401 Unauthorized using token from APPLE_MUSIC_DEVELOPER_TOKEN_2026-01-15.

Updated music-video entries with Apple Music catalog URLs and updated renderer to use apple_music_url for link rendering. Validated story schema with scripts/validate_story.py.
<!-- SECTION:NOTES:END -->
