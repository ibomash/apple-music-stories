---
id: TASK-45
title: Enable XcodeBuildMCP simulator build
status: Done
assignee: []
created_date: '2026-01-20 22:05'
updated_date: '2026-01-20 22:23'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Get XcodeBuildMCP configured so the iOS project under ios/ can build on an iOS simulator.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Simulator build now succeeds via XcodeBuildMCP (scheme MusicStoryRenderer). Updated StoryDocumentStore deinit, simplified AppleMusicPlaybackController metadata + catalog fetch helpers, added @preconcurrency import, and fixed MediaReferenceView body to return a View.
<!-- SECTION:NOTES:END -->
