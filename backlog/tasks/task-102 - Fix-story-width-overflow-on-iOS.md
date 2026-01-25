---
id: TASK-102
title: Fix story width overflow on iOS
status: Done
assignee: []
created_date: '2026-01-25 04:42'
updated_date: '2026-01-25 04:51'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replicate Hip-Hop story width overflow in simulator and adjust iOS layout logic to fit phone width.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Reproduced overflow in iPhone 17 simulator (story content frames exceeded screen width with negative x). Updated StoryRendererView to clamp content width to screen and pass fixed width into StoryHeaderView/StoryHeroImageView; set hero image to fixed width/height and clip story content. Ran simulator builds after changes. Accessibility still reports hero image frame wider than screen; visual clipping now constrained. Tests: XcodeBuildMCP_test_sim failed in StorySnapshotTests.swift due to missing StoryDocument initializer args (pre-existing).
<!-- SECTION:NOTES:END -->
