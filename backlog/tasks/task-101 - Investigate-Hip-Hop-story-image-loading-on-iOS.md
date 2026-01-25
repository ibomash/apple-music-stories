---
id: TASK-101
title: Investigate Hip-Hop story image loading on iOS
status: Done
assignee: []
created_date: '2026-01-25 04:25'
updated_date: '2026-01-25 04:29'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate missing images in Hip-Hop story on iOS, validate story image references, and verify via Simulator if needed.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validated Hip-Hop story image URLs in stories/hip-hop-changed-the-game/story.mdx. Found 12 Apple image URLs returning 404/400 (tracks, albums, music-video preview stills, FullBleed/GalleryImage). Replaced them with iTunes lookup/search artwork URLs and revalidated all image URLs to return <400.
<!-- SECTION:NOTES:END -->
