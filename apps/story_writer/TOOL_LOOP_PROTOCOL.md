# Story Writer Tool-Loop Protocol (V1 Track)

This document defines the bounded decide-and-call-tools runtime used by Story Writer.

Current architecture is intentionally **hybrid**:

- The retrieval phase is agentic (model decides next tool action).
- Drafting/validation/repair remains workflow-controlled by the orchestrator.

## Goals

- Let the model choose the next retrieval action instead of hardcoding fixed retrieval order.
- Keep execution safe and predictable with strict bounds.
- Emit auditable events for every model decision and tool call.

## Allowed actions

The planner can choose one action per step:

1. `search_apple_music`
2. `search_wikipedia`
3. `finalize`

Planner output contract:

```json
{
  "action": "search_apple_music",
  "query": "Prince",
  "reason": "Need canonical albums first"
}
```

## Loop lifecycle

1. Initialize `ToolLoopState` with prompt and empty retrieval context.
2. For each step (up to max):
   - Ask planner for next action.
   - Emit model-note event with action and reason.
   - Execute the selected tool (if not `finalize`).
   - Record results in loop state + source tracker.
3. Stop when planner chooses `finalize` or max steps is reached.
4. Continue with drafting and validation pipeline.

## Safety bounds

- Hard step limit: `STORY_WRITER_TOOL_LOOP_MAX_STEPS` (default `6`).
- Tool calls are one-per-step.
- Planner failures fall back to conservative retrieval action.
- Run cancellation checked before each step and before each tool call.

## Event logging

Each decision and tool call must produce visible events:

- `model_note`: `tool-loop action: <action> (<reason>)`
- `tool_call_started`
- `tool_call_completed`

## Failure behavior

- Apple Music auth/connectivity failures fail the run.
- If no Apple Music results are collected by loop end, run fails.
- Wikipedia can return zero results; generation can still continue.

## Current implementation notes

- Mock mode uses deterministic planner logic.
- Live mode uses Claude planner calls with JSON-only decisions.
- Story drafting remains a separate model call after retrieval loop.
