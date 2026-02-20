# Story Writer User Guide

This guide explains what user-facing clients exist right now and how to run each one.

## Current `STORY_WRITER_TOOL_LOOP_MAX_STEPS`

- Default value: `6`
- Config source: `STORY_WRITER_TOOL_LOOP_MAX_STEPS` env var
- If unset, the service uses `6`.

### What happens when max steps is reached?

The run emits this activity note:

- `tool-loop reached max steps; proceeding with collected context`

Then behavior is:

1. If Apple Music anchors were found, generation continues using collected context.
2. If Apple Music anchors were not found, run fails with `Apple Music search returned no results.`

In the web UI and CLI event stream, you will see these notes as part of run activity.

## How many front ends exist now?

For Story Writer there are currently **2 user-facing clients**:

1. **Web client** (minimal browser UI)
2. **CLI client** (`story-writer-cli`)

## Run the service

From repo root:

```bash
uv run --project apps/story_writer uvicorn story_writer.api:app --host 127.0.0.1 --port 8787 --reload
```

## Front end 1: Web client

Open in browser:

```text
http://127.0.0.1:8787/
```

What you can do:

- Enter prompt and starter template
- Generate run
- Watch events in real time (polling)
- Cancel / retry
- Inspect returned artifact JSON

## Front end 2: CLI client

### Preflight

```bash
uv run --project apps/story_writer story-writer-cli preflight
```

### Create + watch

```bash
uv run --project apps/story_writer story-writer-cli create \
  --prompt "Prince career retrospective: eras, key albums, major videos" \
  --template album_retrospective \
  --watch
```

### Cancel

```bash
uv run --project apps/story_writer story-writer-cli cancel <run_id>
```

### Fetch artifact

```bash
uv run --project apps/story_writer story-writer-cli artifact <run_id>
```

## Live mode quick start

```bash
source apps/story_writer/.envrc
export STORY_WRITER_MODE=live
export APPLE_MUSIC_DEVELOPER_TOKEN_PATH=.auth/apple-music/developer_token
uv run --project apps/story_writer story-writer-cli preflight
```

If preflight is ready, run create/watch via web or CLI.
