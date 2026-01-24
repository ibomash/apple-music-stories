# Agent instructions

This project is described in README.md

## Backlog management

Backlog tasks and documents are kept under `backlog/` and use the Backlog.md system to maintain. Check for skills related to Backlog.md and the `backlog` CLI tool to understand how to find tasks and documents and work with them.

This project uses the labels: (to come)

**Whenever the user asks you to do something,** if they don't specify a task ID and it's more than just a trivial task like moving some tickets or running a command line, create a new Backlog task to capture and document the work. Keep the task's status updated as you work, outlining what you were asked for, how you're going to do it, and documenting what happened when it's done.

## Coding

This project uses Python 3.13 and Swift 6.2.

Always write and run relevant tests for changes. If tests cannot run in the current environment, note the blocker in your final update.

For web story renderer smoke checks, run `uv run scripts/render_story.py serve --host 127.0.0.1 --port 8000` and `node scripts/puppeteer_story_test.js` (override with `STORY_BASE_URL`).

## Story Authoring

Use `AGENTS-authoring.md` for the authoring-only prompt and guidance.
