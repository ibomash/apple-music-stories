---
id: doc-14
title: 'Technical Spec: Music Story Writer API (V0 -> V1)'
type: spec
created_date: '2026-02-20 00:05'
---

## 1. Executive Summary

Yes, the proposed approach makes sense and is the right next step.

We should begin with a local-first server-side writer (V0):

1. A simple Python HTTP API running on localhost.
2. No auth in V0 (and no auth in V1 per current decision).
3. A minimal client to exercise the API and generate stories (CLI and very small web UI).

This de-risks core architecture quickly and keeps us focused on the core user value: generating strong, context-rich, album-centric stories.

## 2. Confirmed Product/Technical Decisions

Integrated from the latest feedback:

1. Source policy for V1: keep sourcing simple.
   - Use structured sources first: Apple Music + Wikipedia.
   - Keep image sourcing conservative (Apple Music artwork and Wikimedia/Wikipedia media metadata when available).
2. Auth policy:
   - No auth in V0.
   - No auth in V1.
3. Activity notes UX:
   - Expose model activity notes verbatim for now.
4. Cancellation semantics:
   - Cancel + retry only.
   - "Continue" is represented as a new user request/message, not run resume.
5. Inline references:
   - Only generate inline source references when model/tool confidence is high.
6. Cost target:
   - No hard cost budget set yet.
   - Instrument costs/usage from day one.
7. Human review gate:
   - No human approval gate in V0/V1.
8. On-device fallback:
   - Deferred; revisit later.

## 3. Core User Value and Design Constraints

Core value statement:

- Help music nerds learn context and discover albums in context, with albums as the anchor.

Technical implications:

1. Retrieval quality is higher priority than editing workflow depth.
2. Fast iteration on prompts/tools matters more than app-embedded orchestration in early milestones.
3. Attribution should build trust but remain lightweight.
4. We should avoid infrastructure complexity that does not improve story quality.

## 4. Architecture Direction

### 4.1 Decision

Server-side orchestration is the primary architecture for V0 and V1.

### 4.2 Why

1. Better observability and debugging for tool loops.
2. Faster prompt and tool iteration without app release cycles.
3. Simpler secret handling for model providers and source adapters.
4. Avoids iOS app lifecycle/background limitations for long calls.

### 4.3 Framework Position

For V0/V1, use a thin explicit orchestrator (plain Python service code), not a heavy durable workflow framework.

1. Do now: direct model API + explicit tool loop + clear run state machine.
2. Defer: LangGraph/Temporal unless operational evidence demands durable workflows.

## 5. Milestone Plan

### 5.1 V0 (New): Local Story Writer API + Basic Clients

Primary objective:

- Prove the server-side generation loop and API contract end-to-end on localhost.

### 5.2 V1: Hardened Service + iOS Integration

Primary objective:

- Keep the same core API shape but productionize reliability, persistence, and client integration.

### 5.3 V2+

1. Suggested-edit chat workflow.
2. Session-local candidate versions with accept/rollback.
3. Later discussion on on-device fallback.

## 6. V0 Detailed Technical Specification

### 6.1 Scope

In scope:

1. Python HTTP API on localhost.
2. One-shot run-based story generation.
3. Real activity/event reporting.
4. Cancel + retry semantics.
5. End notes attribution and optional high-confidence inline references.
6. Basic artifact output compatible with existing story schema/parsers.
7. Minimal client(s): CLI and web UI.

Out of scope:

1. User auth, accounts, billing.
2. Multi-user collaboration.
3. Durable workflow runtime (LangGraph/Temporal).
4. Persistent edit timeline.
5. Broad web search.

### 6.2 Proposed Stack

1. Python 3.13.
2. FastAPI + Uvicorn for HTTP API.
3. Pydantic models for request/response contracts.
4. HTTPX for outbound source/tool requests.
5. Optional SSE endpoint for live events (simple polling is acceptable if simpler to ship first).

Runtime mode:

1. `mode=mock` for deterministic local/testing runs.
2. `mode=live` for real model + source calls.

### 6.3 Service Layout (Proposed)

```text
apps/story_writer/
  api.py                 # FastAPI app and routes
  models.py              # Pydantic contracts
  orchestrator.py        # Run state machine + tool loop
  tools/
    apple_music.py
    wikipedia.py
    sources.py
  validation.py          # Story schema/parser checks
  storage.py             # Local run/artifact store
  web/
    index.html           # minimal web client
scripts/
  story_writer_cli.py    # CLI client for API
```

### 6.4 V0 API Contract

#### Endpoints

1. `GET /v0/health`
2. `POST /v0/runs`
3. `GET /v0/runs/{run_id}`
4. `GET /v0/runs/{run_id}/events`
5. `GET /v0/runs/{run_id}/artifact`
6. `POST /v0/runs/{run_id}/cancel`

#### `POST /v0/runs` request

```json
{
  "prompt": "Write a story about trip-hop origins and essential albums",
  "starter_template": "genre_overview",
  "length_hint": "10min",
  "tone_hint": "smart, opinionated",
  "locale": "en-US"
}
```

#### `POST /v0/runs` response

```json
{
  "run_id": "run_01J...",
  "status": "queued"
}
```

#### `GET /v0/runs/{run_id}` response

```json
{
  "run_id": "run_01J...",
  "status": "running",
  "created_at": "2026-02-20T00:00:00Z",
  "updated_at": "2026-02-20T00:00:05Z",
  "error": null
}
```

#### `GET /v0/runs/{run_id}/events`

Returns append-only event list:

```json
{
  "run_id": "run_01J...",
  "events": [
    {"idx": 1, "type": "run_started", "message": "Run started"},
    {"idx": 2, "type": "tool_call_started", "message": "Searching Wikipedia: trip-hop"},
    {"idx": 3, "type": "model_note", "message": "Drafting section outline"}
  ]
}
```

#### `GET /v0/runs/{run_id}/artifact`

```json
{
  "run_id": "run_01J...",
  "story_mdx": "---\\nschema_version: 0.1\\n...",
  "provenance": {
    "end_notes": [{"source_id": "src-1", "label": "Wikipedia - Trip hop", "url": "https://..."}],
    "inline_references": [{"section_id": "origins", "source_ids": ["src-1"]}],
    "acknowledgements": ["Sources: Apple Music, Wikipedia"]
  },
  "validation": {
    "schema_valid": true,
    "parser_compatible": true,
    "diagnostics": []
  }
}
```

Notes:

1. `inline_references` can be empty when confidence is not high.
2. `story_mdx` must validate against existing schema and parse in current iOS parser.

### 6.5 Run State Machine

States:

1. `queued`
2. `running`
3. `completed`
4. `failed`
5. `cancelled`

Allowed transitions:

- `queued -> running -> completed|failed|cancelled`

Cancellation:

1. `cancel` is best-effort.
2. No resume endpoint.
3. Retry means creating a new run with same or adjusted prompt.

### 6.6 Generation Pipeline (V0)

1. Normalize prompt with selected starter template.
2. Retrieve context from simple source set (Apple Music + Wikipedia).
3. Track all sources used during retrieval/drafting.
4. Generate story MDX draft.
5. Generate end notes from used sources.
6. Add inline references only when confidence is high.
7. Validate output:
   - `scripts/validate_story.py` equivalent checks.
   - Parser compatibility with the current MDX subset.
8. If validation fails, perform one repair pass.
9. Finalize artifact and events.

### 6.7 Source and Attribution Policy (V0/V1)

1. Source set is intentionally simple.
2. End notes list overall sources used.
3. Inline references are optional and confidence-gated.
4. Activity notes are surfaced verbatim.

### 6.8 Local Storage Model (V0)

Default storage root (local only):

- `.cache/story-writer/`

Stored artifacts:

1. `runs/{run_id}.json` (run metadata/status).
2. `events/{run_id}.jsonl` (event log).
3. `artifacts/{run_id}.json` (`story_mdx` + provenance + validation summary).

### 6.9 Local Client Requirements

#### CLI client (`scripts/story_writer_cli.py`)

Commands:

1. `create` - create run from prompt/template.
2. `watch` - poll status/events until terminal state.
3. `artifact` - print or save generated artifact.
4. `cancel` - cancel active run.

#### Web client (minimal)

Requirements:

1. Single page with prompt textarea + template picker.
2. Button: `Generate`.
3. Live run status and event log pane.
4. Story output pane (raw MDX is acceptable in V0).
5. Button: `Cancel` and `Retry`.

### 6.10 Observability (V0)

Track these metrics/logs from day one:

1. Run counts by terminal status.
2. Stage latency (retrieve, draft, validate).
3. Validation failure categories.
4. Source count per run.
5. Token/cost usage telemetry (no hard budget enforcement yet).

### 6.11 V0 Acceptance Criteria

1. Developer can run API locally and generate a story via CLI.
2. Developer can run API locally and generate a story via web UI.
3. At least one end-to-end generated artifact passes schema/parser checks.
4. Cancel endpoint works for in-flight runs.
5. Verbatim event log is visible in client.
6. No auth required; service binds to localhost by default.

### 6.12 V0 Test Plan

1. API contract tests for each endpoint.
2. Orchestrator unit tests for state transitions.
3. Validation tests for malformed and valid story outputs.
4. Client smoke tests for create/watch/cancel/retry flow.

## 7. V1 Delta (After V0)

V1 keeps the same core API shape and adds hardening:

1. Better run persistence and crash recovery.
2. Cleaner event taxonomy and UI formatting (still can expose verbatim notes).
3. iOS client integration with run + artifact endpoints.
4. Improved retrieval quality checks and missing-album detection.
5. Export packaging (`story.mdx` + assets bundle) path.

Still explicitly deferred in V1:

1. Auth/account systems.
2. Human review gates.
3. On-device fallback path.

## 8. Remaining Major Questions (Now)

Most major product questions are resolved for kickoff.

Resolved decisions:

1. Live model provider for V0: Claude Sonnet 4.6.
2. Apple Music adapter requirement for V0: a working Apple Music/MusicKit-backed connection and auth is required for successful runs.
3. Event transport for V0: start with polling; add SSE later if polling UX is inadequate.
4. Artifact format for V0: JSON artifact first; zip package path in V1.

No blocking major open questions remain for V0 kickoff.

## 9. References

Architecture/tooling references considered:

1. OpenAI Responses API tools and function calling docs.
2. LangGraph durable execution + HITL docs (deferred for now).
3. Temporal durable workflow docs (deferred for now).
4. Apple Foundation Models docs (on-device fallback later discussion).
