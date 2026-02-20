from __future__ import annotations

import json
import threading
import uuid
from dataclasses import dataclass
from pathlib import Path

from story_writer.models import (
    CreateRunRequest,
    RunEvent,
    RunState,
    RunStatus,
    StoryArtifact,
    now_utc,
)


@dataclass(frozen=True)
class CreatedRun:
    run_id: str
    state: RunState


class LocalRunStore:
    def __init__(self, root: Path) -> None:
        self.root = root
        self._runs_dir = root / "runs"
        self._events_dir = root / "events"
        self._artifacts_dir = root / "artifacts"
        self._lock = threading.RLock()
        self._runs_dir.mkdir(parents=True, exist_ok=True)
        self._events_dir.mkdir(parents=True, exist_ok=True)
        self._artifacts_dir.mkdir(parents=True, exist_ok=True)

    def create_run(self, request: CreateRunRequest) -> CreatedRun:
        with self._lock:
            run_id = f"run_{uuid.uuid4().hex[:12]}"
            now = now_utc()
            state = RunState(
                run_id=run_id,
                status="queued",
                created_at=now,
                updated_at=now,
                error=None,
                cancel_requested=False,
            )
            self._write_json(
                self._run_path(run_id),
                {
                    "state": state.model_dump(mode="json"),
                    "request": request.model_dump(mode="json"),
                },
            )
            self._events_path(run_id).touch(exist_ok=True)
            return CreatedRun(run_id=run_id, state=state)

    def get_run(self, run_id: str) -> RunState | None:
        with self._lock:
            payload = self._read_json(self._run_path(run_id))
            if payload is None:
                return None
            state_payload = payload.get("state")
            if not isinstance(state_payload, dict):
                return None
            return RunState.model_validate(state_payload)

    def set_status(
        self, run_id: str, status: RunStatus, error: str | None = None
    ) -> RunState | None:
        with self._lock:
            payload = self._read_json(self._run_path(run_id))
            if payload is None:
                return None
            state_payload = payload.get("state")
            if not isinstance(state_payload, dict):
                return None
            state = RunState.model_validate(state_payload)
            updated = state.model_copy(
                update={
                    "status": status,
                    "error": error,
                    "updated_at": now_utc(),
                }
            )
            payload["state"] = updated.model_dump(mode="json")
            self._write_json(self._run_path(run_id), payload)
            return updated

    def request_cancel(self, run_id: str) -> RunState | None:
        with self._lock:
            payload = self._read_json(self._run_path(run_id))
            if payload is None:
                return None
            state_payload = payload.get("state")
            if not isinstance(state_payload, dict):
                return None
            state = RunState.model_validate(state_payload)
            updated = state.model_copy(
                update={
                    "cancel_requested": True,
                    "updated_at": now_utc(),
                }
            )
            payload["state"] = updated.model_dump(mode="json")
            self._write_json(self._run_path(run_id), payload)
            return updated

    def is_cancel_requested(self, run_id: str) -> bool:
        run = self.get_run(run_id)
        if run is None:
            return False
        return run.cancel_requested or run.status == "cancelled"

    def append_event(
        self, run_id: str, event_type: str, message: str
    ) -> RunEvent | None:
        with self._lock:
            events = self.list_events(run_id)
            if events is None:
                return None
            event = RunEvent(
                idx=len(events) + 1,
                type=event_type,
                message=message,
                timestamp=now_utc(),
            )
            path = self._events_path(run_id)
            line = json.dumps(event.model_dump(mode="json"), ensure_ascii=True)
            with path.open("a", encoding="utf-8") as handle:
                handle.write(line + "\n")
            return event

    def list_events(self, run_id: str) -> list[RunEvent] | None:
        with self._lock:
            if not self._run_path(run_id).exists():
                return None
            path = self._events_path(run_id)
            if not path.exists():
                return []
            events: list[RunEvent] = []
            with path.open("r", encoding="utf-8") as handle:
                for raw_line in handle:
                    line = raw_line.strip()
                    if not line:
                        continue
                    item = json.loads(line)
                    events.append(RunEvent.model_validate(item))
            return events

    def save_artifact(self, artifact: StoryArtifact) -> None:
        with self._lock:
            self._write_json(
                self._artifact_path(artifact.run_id),
                artifact.model_dump(mode="json"),
            )

    def get_artifact(self, run_id: str) -> StoryArtifact | None:
        with self._lock:
            payload = self._read_json(self._artifact_path(run_id))
            if payload is None:
                return None
            return StoryArtifact.model_validate(payload)

    def _run_path(self, run_id: str) -> Path:
        return self._runs_dir / f"{run_id}.json"

    def _events_path(self, run_id: str) -> Path:
        return self._events_dir / f"{run_id}.jsonl"

    def _artifact_path(self, run_id: str) -> Path:
        return self._artifacts_dir / f"{run_id}.json"

    def _read_json(self, path: Path) -> dict | None:
        try:
            if not path.exists():
                return None
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None

    def _write_json(self, path: Path, payload: dict) -> None:
        path.write_text(
            json.dumps(payload, indent=2, ensure_ascii=True), encoding="utf-8"
        )
