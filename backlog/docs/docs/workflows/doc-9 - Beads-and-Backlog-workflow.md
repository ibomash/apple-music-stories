---
id: doc-9
title: Beads and Backlog workflow
type: workflow
created_date: '2026-01-25 22:15'
---

# Beads and Backlog: division of labor

## Purpose
Backlog.md is the canonical product backlog and planning record. Beads is the canonical execution graph and agent memory. The bridge between them is intentionally small and deterministic so there is one source of truth per layer.

## Rules of thumb
- Backlog answers: what should we build, why, and what defines done.
- Beads answers: what should we do next, how it decomposes, and what is blocked.
- Create Backlog tasks sparingly for product-level tracking; create Beads issues for execution work.

## Source of truth
- Backlog: epics, features, tasks, acceptance criteria, decisions, priorities.
- Beads: execution status, dependencies, sub-tasks, agent notes, completion summaries.

## Mapping (Backlog to Beads)
Promote a Backlog task to Beads when it moves to `Next` or `Now`, or receives a promotion label like `execution:beads`.

## Beads-first execution
If work is execution-only and does not need product-level tracking, create a Beads issue directly. Use `Backlog: none` in the issue body and skip creating a Backlog task.

Mapping fields:
- Backlog task id -> Beads `external_id` (store the Backlog id).
- Task title -> Beads title.
- Task description + acceptance criteria -> Beads body (full copy or short body + link).
- Priority or estimates -> Beads labels or tags.
- Dependencies -> Beads `depends_on` (if Backlog has explicit deps).

## Minimal write-back (Beads to Backlog)
Beads should not rewrite backlog content. It can append execution signals:
- Execution status: In Progress, Blocked, Done.
- Completion note: summary, PR or commit links, gotchas.
- Follow-ups: new Backlog tasks created in `Later` or `Next`.

## Bridge conventions
- Backlog tasks live under `backlog/tasks/`.
- Beads issues live under `.beads/` in the main repo (not worktrees).
- Each promoted task has a backlink:

```md
## Execution
- Beads: <bd-id>
- Status: <In Progress|Blocked|Done>
```

## Suggested bridge commands (future helper)
- `bridge promote`: create Beads issues for promoted Backlog tasks and write the Beads id back.
- `bridge sync-status`: read Beads status and update Backlog status fields only.
- `bridge close`: mark Backlog done and append completion notes for closed Beads issues.

Idempotency rules:
- If a Backlog task already has a Beads id, do not create another.
- Only update bridge-owned sections (`## Execution`, `## Completion Notes`).

## Beads issue body template
```md
Backlog: backlog/tasks/<task-file>.md (or "Backlog: none" for Beads-only work)

Goal:
- <deliverable>

Acceptance criteria:
- [ ] <criterion>
- [ ] <criterion>

Notes:
- <constraints or links>
```

## Day-to-day workflow
1) If product tracking is needed, plan in Backlog (deliverable, acceptance criteria, constraints).
2) Promote to Beads for execution when it moves to Now/Next.
3) If execution-only, create a Beads issue directly.
4) Execute in Beads (subtasks, dependencies, progress).
5) Close the loop with minimal status and completion notes in Backlog when a Backlog task exists.
