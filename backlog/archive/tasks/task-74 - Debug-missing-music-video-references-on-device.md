---
id: TASK-74
title: Debug missing music video references on device
status: Now
assignee: []
created_date: '2026-01-23 17:56'
updated_date: '2026-01-23 18:06'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate why music video references in the 'Hip-Hop Changed the Game' story do not render on physical devices. Use XcodeBuildMCP device log capture or other diagnostics to trace data loading, rendering, and MusicKit link resolution.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Device log capture returned only tunnel/launch lines (no app output). Story file in repo includes music-video media refs (mv-runaway, mv-yonkers, mv-anaconda, mv-humble, mv-this-is-america). App should show cards even though playback unsupported. Likely device loaded older story/persisted bundle. Diagnostics section appears on StoryLaunchView when store.diagnostics is non-empty.
<!-- SECTION:NOTES:END -->
