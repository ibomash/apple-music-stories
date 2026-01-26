---
id: doc-11
title: Landing the plane workflow
type: workflow
created_date: '2026-01-25 23:34'
---

# Landing the plane workflow

## Purpose
Close a work session in a consistent, low-friction way while keeping Backlog and Beads accurate.

## When to run
- Run the full workflow when you made changes that should be committed or you used Beads.
- If there are no code/content changes and no commits, do a light closeout (status + handoff only).

## Steps
1) File follow-up work as Backlog tasks when product tracking is needed, or Beads issues for execution-only work.
2) Run quality gates if code changed (tests, lint, build). Note blockers if they cannot run.
3) Update task status (Backlog and Beads, if used).
4) Sync Beads when needed:
   - `bd sync` if `.beads/` changed or Beads issues were created/updated.
5) Publish commits only when requested and commits exist:
   - `git pull --rebase`
   - `git push`
   - `git status` shows up to date
6) Clean up: clear stashes and prune remote branches created during the session.
7) Handoff: summarize changes, tests, blockers, and next steps.

## Notes
- Do not create commits unless explicitly requested.
- Avoid force-push or rewriting history unless explicitly requested.
