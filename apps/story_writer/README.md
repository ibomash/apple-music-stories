# Story Writer API (V0)

This is the local-first server harness for Music Story generation.

- User guide: `apps/story_writer/USER_GUIDE.md`

V0 goal: validate the server-side run loop end-to-end with a simple API and thin clients before iOS integration.

Current loop architecture is a **hybrid agent workflow**:

- Agentic retrieval loop: model decides which tool to call next (bounded decide-and-call-tools).
- Workflow-controlled finishing: service handles drafting, validation, optional repair, and artifact persistence.

## What this ships

- Python HTTP API (`FastAPI`) for run-based generation.
- Local file-backed storage for runs, events, and artifacts.
- One-shot orchestration pipeline (retrieve -> draft -> validate -> optional repair -> artifact).
- Model-driven, bounded decide-and-call-tools loop for retrieval.
- Apple Music search fallback logic for long prompts (retries with simplified query candidates).
- Wikipedia requests with explicit User-Agent to satisfy Wikimedia robot policy.
- Minimal web client at `/`.
- Python CLI client (`story-writer-cli`).

## Product constraints reflected in V0

- No auth (localhost usage).
- Model provider standardized as Claude Sonnet 4.6 (configured via `STORY_WRITER_MODEL`).
- Apple Music connectivity/auth is required for successful live runs.
- Cancellation is cancel/retry (no resume endpoint).
- Inline references are added only when confidence is high.

## Project layout

```text
apps/story_writer/
  pyproject.toml
  README.md
  src/story_writer/
    api.py
    cli.py
    config.py
    main.py
    models.py
    orchestrator.py
    storage.py
    validation.py
    tools/
      apple_music.py
      wikipedia.py
      sources.py
  tests/
    test_api_contract.py
    test_orchestrator_behavior.py
    test_validation.py
  TOOL_LOOP_PROTOCOL.md
  web/
    index.html
```

## Prerequisites

- `uv` installed.
- Python 3.13 available to `uv`.
- For live mode:
  - `ANTHROPIC_API_KEY`
  - `APPLE_MUSIC_DEVELOPER_TOKEN` (or `APPLE_MUSIC_DEVELOPER_TOKEN_PATH`)

## Setup with `uv`

From repository root:

```bash
uv sync --project apps/story_writer --extra dev
```

## Run the API

### Mock mode (default)

```bash
uv run --project apps/story_writer uvicorn story_writer.api:app --host 127.0.0.1 --port 8787 --reload
```

### Live mode

```bash
export STORY_WRITER_MODE=live
export ANTHROPIC_API_KEY="..."
export APPLE_MUSIC_DEVELOPER_TOKEN="..."
export APPLE_MUSIC_STOREFRONT="us"
export STORY_WRITER_MODEL="claude-sonnet-4-6"
uv run --project apps/story_writer uvicorn story_writer.api:app --host 127.0.0.1 --port 8787 --reload
```

## Use the clients

### Web client

Open:

```text
http://127.0.0.1:8787/
```

### CLI client

Create + watch:

```bash
uv run --project apps/story_writer story-writer-cli create \
  --prompt "Write a story about trip-hop origins and key albums" \
  --template genre_overview \
  --watch
```

Cancel:

```bash
uv run --project apps/story_writer story-writer-cli cancel run_abc123
```

Fetch artifact:

```bash
uv run --project apps/story_writer story-writer-cli artifact run_abc123
```

Preflight (live readiness):

```bash
uv run --project apps/story_writer story-writer-cli preflight
```

### Live end-to-end verification (Prince retrospective)

```bash
source apps/story_writer/.envrc
export STORY_WRITER_MODE=live
export APPLE_MUSIC_DEVELOPER_TOKEN_PATH=.auth/apple-music/developer_token
uv run --project apps/story_writer story-writer-cli create \
  --prompt "Write a full retrospective of Prince's career, covering his major eras, key albums, and major music videos." \
  --template album_retrospective \
  --tone-hint "critical and contextual" \
  --watch
```

If the run completes and you want to promote it into repo fixtures/examples, save it under `stories/<story-id>/story.mdx`.

Current promoted live example:

- `stories/prince-career-retrospective-v0-live/story.mdx`

## API contract (V0)

### Endpoints

- `GET /v0/health`
- `GET /v0/preflight`
- `POST /v0/runs`
- `GET /v0/runs/{run_id}`
- `GET /v0/runs/{run_id}/events`
- `GET /v0/runs/{run_id}/artifact`
- `POST /v0/runs/{run_id}/cancel`

### `POST /v0/runs` request

```json
{
  "prompt": "Write a story about trip-hop origins and essential albums",
  "starter_template": "genre_overview",
  "length_hint": "10min",
  "tone_hint": "smart, opinionated",
  "locale": "en-US"
}
```

### `GET /v0/runs/{run_id}` example

```json
{
  "run_id": "run_01abc...",
  "status": "running",
  "created_at": "2026-02-20T00:00:00Z",
  "updated_at": "2026-02-20T00:00:03Z",
  "error": null,
  "cancel_requested": false
}
```

### `GET /v0/runs/{run_id}/events` example

```json
{
  "run_id": "run_01abc...",
  "events": [
    {
      "idx": 1,
      "type": "run_started",
      "message": "Run started",
      "timestamp": "2026-02-20T00:00:00Z"
    }
  ]
}
```

## Environment variables

- `STORY_WRITER_MODE`: `mock` (default) or `live`
- `STORY_WRITER_HOST`: default `127.0.0.1`
- `STORY_WRITER_PORT`: default `8787`
- `STORY_WRITER_STORAGE_ROOT`: default `.cache/story-writer`
- `STORY_WRITER_MODEL`: default `claude-sonnet-4-6`
- `ANTHROPIC_API_KEY`: required in live mode
- `APPLE_MUSIC_DEVELOPER_TOKEN`: required in live mode
- `APPLE_MUSIC_DEVELOPER_TOKEN_PATH`: optional token file path
- `APPLE_MUSIC_STOREFRONT`: default `us`
- `STORY_WRITER_TOOL_LOOP_MAX_STEPS`: max planner loop steps (default `6`)

## Local storage

By default, artifacts are written under `.cache/story-writer/`:

- `runs/{run_id}.json`
- `events/{run_id}.jsonl`
- `artifacts/{run_id}.json`

## Testing

Run tests:

```bash
uv run --project apps/story_writer --extra dev pytest apps/story_writer/tests
```

The current tests validate:

- API health + run lifecycle contract.
- Artifact availability after completion.
- Story validation pipeline for schema/parser compatibility.
- Apple Music query fallback behavior in orchestrator.
- Model-driven tool loop execution behavior.
- Wikipedia client User-Agent header behavior.

## Troubleshooting

### Run fails with Apple Music auth error

- Verify `APPLE_MUSIC_DEVELOPER_TOKEN` is present.
- Verify token validity and storefront.
- Retry with a simpler prompt to isolate query issues.

### Run fails in live mode with model error

- Verify `ANTHROPIC_API_KEY` and network access.
- Confirm model identifier in `STORY_WRITER_MODEL` is available on your account.
- If Anthropic returns `529 overloaded_error`, retry the run; planner/draft calls include bounded retries and a fallback planner path, but upstream overload can still fail a run.

### Artifact not found

- Check run status first (`GET /v0/runs/{run_id}`).
- Artifact is available only for `completed` runs.
