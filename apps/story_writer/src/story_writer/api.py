from __future__ import annotations

import asyncio
import io
import json
import zipfile
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse

from story_writer.config import AppConfig
from story_writer.models import (
    CancelRunResponse,
    CreateRunRequest,
    CreateRunResponse,
    PreflightCheck,
    PreflightResponse,
    RunEventsResponse,
    RunState,
)
from story_writer.orchestrator import StoryOrchestrator
from story_writer.storage import LocalRunStore
from story_writer.tools.apple_music import AppleMusicClient


def create_app(config: AppConfig | None = None) -> FastAPI:
    resolved_config = config or AppConfig.from_env()
    store = LocalRunStore(resolved_config.storage_root)
    orchestrator = StoryOrchestrator(store=store, config=resolved_config)

    app = FastAPI(title="Music Story Writer API", version="0.1.0")
    app.state.config = resolved_config
    app.state.store = store
    app.state.orchestrator = orchestrator
    app.state.tasks = {}

    @app.get("/v0/health")
    async def health() -> dict[str, str]:
        return {
            "status": "ok",
            "mode": resolved_config.mode,
        }

    @app.get("/v0/preflight", response_model=PreflightResponse)
    async def preflight() -> PreflightResponse:
        checks: list[PreflightCheck] = []

        if resolved_config.mode == "live":
            checks.append(
                PreflightCheck(
                    name="anthropic_api_key",
                    ok=bool(resolved_config.anthropic_api_key),
                    detail=(
                        "present"
                        if resolved_config.anthropic_api_key
                        else "missing ANTHROPIC_API_KEY"
                    ),
                )
            )
            checks.append(
                PreflightCheck(
                    name="apple_music_developer_token",
                    ok=bool(resolved_config.apple_music_developer_token),
                    detail=(
                        "present"
                        if resolved_config.apple_music_developer_token
                        else "missing APPLE_MUSIC_DEVELOPER_TOKEN or _PATH"
                    ),
                )
            )

            connectivity_ok = False
            connectivity_detail = "skipped"
            if resolved_config.apple_music_developer_token:
                client = AppleMusicClient(
                    developer_token=resolved_config.apple_music_developer_token,
                    storefront=resolved_config.apple_music_storefront,
                    timeout_seconds=resolved_config.apple_music_timeout_seconds,
                )
                try:
                    await client.search_catalog("Prince", limit=1)
                    connectivity_ok = True
                    connectivity_detail = "ok"
                except Exception as exc:  # noqa: BLE001
                    connectivity_detail = f"failed: {exc}"
            checks.append(
                PreflightCheck(
                    name="apple_music_connectivity",
                    ok=connectivity_ok,
                    detail=connectivity_detail,
                )
            )
        else:
            checks.append(
                PreflightCheck(
                    name="runtime_mode",
                    ok=True,
                    detail="mock mode; live credentials not required",
                )
            )

        ready = all(check.ok for check in checks)
        return PreflightResponse(mode=resolved_config.mode, ready=ready, checks=checks)

    @app.post("/v0/runs", status_code=202, response_model=CreateRunResponse)
    async def create_run(request: CreateRunRequest) -> CreateRunResponse:
        created = store.create_run(request)
        task = asyncio.create_task(orchestrator.run(created.run_id, request))
        app.state.tasks[created.run_id] = task
        task.add_done_callback(lambda _: app.state.tasks.pop(created.run_id, None))
        return CreateRunResponse(run_id=created.run_id, status=created.state.status)

    @app.get("/v0/runs/{run_id}", response_model=RunState)
    async def get_run(run_id: str) -> RunState:
        run_state = store.get_run(run_id)
        if run_state is None:
            raise HTTPException(status_code=404, detail="Run not found")
        return run_state

    @app.get("/v0/runs/{run_id}/events", response_model=RunEventsResponse)
    async def get_run_events(run_id: str) -> RunEventsResponse:
        events = store.list_events(run_id)
        if events is None:
            raise HTTPException(status_code=404, detail="Run not found")
        return RunEventsResponse(run_id=run_id, events=events)

    @app.get("/v0/runs/{run_id}/artifact")
    async def get_run_artifact(run_id: str) -> dict:
        run_state = store.get_run(run_id)
        if run_state is None:
            raise HTTPException(status_code=404, detail="Run not found")
        artifact = store.get_artifact(run_id)
        if artifact is None:
            raise HTTPException(status_code=404, detail="Artifact not available yet")
        return artifact.model_dump(mode="json")

    @app.get("/v0/runs/{run_id}/artifact/package")
    async def download_run_artifact_package(run_id: str) -> FileResponse:
        run_state = store.get_run(run_id)
        if run_state is None:
            raise HTTPException(status_code=404, detail="Run not found")

        artifact = store.get_artifact(run_id)
        if artifact is None:
            raise HTTPException(status_code=404, detail="Artifact not available yet")

        package_dir = resolved_config.storage_root / "packages"
        package_dir.mkdir(parents=True, exist_ok=True)
        package_path = package_dir / f"{run_id}.zip"

        payload = artifact.model_dump(mode="json")
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("story.mdx", artifact.story_mdx)
            zf.writestr(
                "artifact.json", json.dumps(payload, indent=2, ensure_ascii=True)
            )
        package_path.write_bytes(buffer.getvalue())

        return FileResponse(
            package_path,
            media_type="application/zip",
            filename=f"{run_id}-story-package.zip",
        )

    @app.post("/v0/runs/{run_id}/cancel", response_model=CancelRunResponse)
    async def cancel_run(run_id: str) -> CancelRunResponse:
        current = store.get_run(run_id)
        if current is None:
            raise HTTPException(status_code=404, detail="Run not found")

        if current.status in {"completed", "failed", "cancelled"}:
            return CancelRunResponse(run_id=run_id, status=current.status)

        store.request_cancel(run_id)
        store.set_status(run_id, "cancelled")
        store.append_event(run_id, "run_cancelled", "Run cancelled by user")
        return CancelRunResponse(run_id=run_id, status="cancelled")

    @app.get("/")
    async def web_home() -> FileResponse:
        index_path = Path(__file__).resolve().parents[2] / "web" / "index.html"
        if not index_path.exists():
            raise HTTPException(status_code=404, detail="Web client not found")
        return FileResponse(index_path)

    return app


app = create_app()
