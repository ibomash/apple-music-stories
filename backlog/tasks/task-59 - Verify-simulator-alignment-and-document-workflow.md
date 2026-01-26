---
id: TASK-59
title: Verify simulator alignment and document workflow
status: Done
assignee: []
created_date: '2026-01-22 22:13'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Check current iOS simulator alignment, document steps in ios/development.md, and summarize current issues plus next steps.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Run simulator and verify alignment for story view.
- Update ios/development.md with simulator alignment steps.
- Review current layout issues and suggest next approach.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Ran XcodeBuildMCP_build_run_sim and loaded https://bomash.net/story.mdx.
- describe_ui shows hero artwork frame x=-46.7 width=495.3 while screen width=402 (overflow persists).
<!-- SECTION:NOTES:END -->
