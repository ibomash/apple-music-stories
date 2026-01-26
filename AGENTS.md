# Agent instructions

This project is described in README.md

## Backlog management

Backlog tasks and documents are kept under `backlog/` and use the Backlog.md system to maintain. Check for skills related to Backlog.md and the `backlog` CLI tool to understand how to find tasks and documents and work with them.

This project uses the labels: (to come)

Backlog is for high-level product tracking (features, acceptance criteria, priorities). Beads is for execution (steps, dependencies, progress).

Create Backlog tasks only when work should be tracked at the product level or when the user asks for backlog tracking. For execution work, create a Beads issue instead; for trivial work, skip tracking.

## Beads + Backlog workflow

- Canonical guidance: `backlog/docs/docs/workflows/doc-9 - Beads-and-Backlog-workflow.md`.
- Backlog owns planning and acceptance criteria; Beads owns execution status and decomposition.
- Promote a Backlog task to Beads when it moves to Now/Next or has an `execution:beads` label, and add the `## Execution` backlink section to the Backlog task.
- For execution-only work without product tracking, create a Beads issue directly and skip Backlog.

## Coding

This project uses Python 3.13 and Swift 6.2.

Always write and run relevant tests for changes. If tests cannot run in the current environment, note the blocker in your final update.

For web story renderer smoke checks, run `uv run scripts/render_story.py serve --host 127.0.0.1 --port 8000` and `node scripts/puppeteer_story_test.js` (override with `STORY_BASE_URL`).

## Story Authoring

Use `AGENTS-authoring.md` for the authoring-only prompt and guidance.

## Landing the Plane (Session Completion)

Follow `backlog/docs/docs/workflows/doc-11 - Landing-the-plane-workflow.md`.

Key points:
- Run the full workflow only when you made changes to publish or used Beads.
- Push only when explicitly requested and commits exist.
