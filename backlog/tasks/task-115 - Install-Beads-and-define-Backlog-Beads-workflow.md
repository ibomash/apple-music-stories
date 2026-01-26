---
id: TASK-115
title: Install Beads and define Backlog/Beads workflow
status: Done
assignee: []
created_date: '2026-01-25 22:14'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Install beads from https://github.com/steveyegge/beads on this machine and define a clear division of labor between Backlog.md and Beads for this repo. Capture the workflow and bridge conventions in repo documentation.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Inspect existing Backlog.md setup and repo guidance.
- Install beads CLI/tooling and verify it runs.
- Draft a concise workflow doc describing Backlog (product backlog) vs Beads (execution graph), mapping fields, promotion rules, and write-back rules.
- Add minimal bridging conventions (IDs, links, status sync) and file locations.
- Report commands used and next steps.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
- Installed beads via Homebrew and verified `bd --version`.
- Initialized beads in main repo `/Users/ibomash/repos-ibomash/apple-music-stories` (worktree requires main repo init).
- Added workflow doc for Backlog/Beads division: `backlog/docs/docs/workflows/doc-9 - Beads-and-Backlog-workflow.md`.
- Noted beads init added landing-the-plane instructions to main repo `AGENTS.md`.
<!-- SECTION:FINAL_SUMMARY:END -->
