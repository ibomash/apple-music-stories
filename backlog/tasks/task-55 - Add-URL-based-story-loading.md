---
id: TASK-55
title: Add URL-based story loading
status: Done
assignee: []
created_date: '2026-01-21 02:50'
updated_date: '2026-01-21 03:06'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add URL loading as a new story source from the launch screen. Support downloading/parsing a story package from a URL with clear error handling and loading states.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a URL prompt from the launch screen for hosted story.mdx files.
- Implement async remote loading in StoryDocumentStore with clear errors.
- Wire loading state and auto-navigation once the download succeeds.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Added a launch screen URL prompt with validation, loading state, and errors.
- Implemented remote story downloads in StoryDocumentStore with HTTP checks.
- URL loads now auto-navigate into the story view on success.
<!-- SECTION:NOTES:END -->
