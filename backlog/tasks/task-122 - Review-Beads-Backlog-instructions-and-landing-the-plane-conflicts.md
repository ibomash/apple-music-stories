---
id: TASK-122
title: Review Beads/Backlog instructions and landing-the-plane conflicts
status: Done
assignee: []
created_date: '2026-01-25 22:41'
updated_date: '2026-01-25 23:35'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Review markdown-based agent/skill guidance plus Beads/Backlog workflow status, and identify conflicts or redundancies to streamline.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Inventory instructions across Markdown files
- [x] #2 Call out conflicts or redundancies
- [x] #3 Suggest updates to streamline
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Findings:
- Beads/Backlog integration documented in backlog/docs/docs/workflows/doc-9 - Beads-and-Backlog-workflow.md and tracked as Done in TASK-115 and TASK-116.
- Only landing-the-plane instructions appear in AGENTS.md; no other markdown sources add a second landing workflow.
- Duplicate Backlog task id TASK-115 appears in two files (Beads workflow vs Apple Music developer token), should be de-duplicated.
- AGENTS.md mandates push every session; consider gating to sessions with changes and aligning with agent execution policies.

Follow-up:
- Reissued "Configure Apple Music developer token" as TASK-124 and removed duplicate TASK-115 file.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
- Added canonical landing-the-plane workflow doc (doc-11) and linked it from AGENTS.md.
- Added Beads/Backlog workflow summary in AGENTS.md and referenced doc-9.
- Removed redundant Backlog CLI instruction from ios/development.md and linked to AGENTS.md.
- Recreated duplicate TASK-115 as TASK-124 and removed the conflicting file.
<!-- SECTION:FINAL_SUMMARY:END -->
