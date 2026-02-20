from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, Field


StarterTemplate = Literal[
    "artist_deep_dive",
    "new_releases_weekly",
    "genre_overview",
    "album_retrospective",
]

RunStatus = Literal["queued", "running", "completed", "failed", "cancelled"]

EventType = Literal[
    "run_started",
    "model_note",
    "tool_call_started",
    "tool_call_completed",
    "validation_started",
    "validation_repair_attempted",
    "run_completed",
    "run_failed",
    "run_cancelled",
]


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


class CreateRunRequest(BaseModel):
    prompt: str = Field(min_length=1)
    starter_template: StarterTemplate | None = None
    length_hint: str | None = None
    tone_hint: str | None = None
    locale: str | None = None


class CreateRunResponse(BaseModel):
    run_id: str
    status: RunStatus


class RunState(BaseModel):
    run_id: str
    status: RunStatus
    created_at: datetime
    updated_at: datetime
    error: str | None = None
    cancel_requested: bool = False


class RunEvent(BaseModel):
    idx: int
    type: EventType
    message: str
    timestamp: datetime


class RunEventsResponse(BaseModel):
    run_id: str
    events: list[RunEvent]


class SourceNote(BaseModel):
    source_id: str
    label: str
    url: str
    source_type: str


class InlineReference(BaseModel):
    section_id: str
    source_ids: list[str]


class ProvenancePayload(BaseModel):
    end_notes: list[SourceNote]
    inline_references: list[InlineReference]
    acknowledgements: list[str]


class ValidationPayload(BaseModel):
    schema_valid: bool
    parser_compatible: bool
    diagnostics: list[str]


class StoryArtifact(BaseModel):
    run_id: str
    story_mdx: str
    provenance: ProvenancePayload
    validation: ValidationPayload


class CancelRunResponse(BaseModel):
    run_id: str
    status: RunStatus


class PreflightCheck(BaseModel):
    name: str
    ok: bool
    detail: str


class PreflightResponse(BaseModel):
    mode: str
    ready: bool
    checks: list[PreflightCheck]
