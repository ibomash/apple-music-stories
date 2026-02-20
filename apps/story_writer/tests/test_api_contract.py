from __future__ import annotations

import io
import time
import zipfile
from pathlib import Path

from fastapi.testclient import TestClient

from story_writer.api import create_app
from story_writer.config import AppConfig


def test_health_endpoint(tmp_path: Path) -> None:
    app = create_app(AppConfig(mode="mock", storage_root=tmp_path / "writer"))
    client = TestClient(app)

    response = client.get("/v0/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_preflight_reports_missing_live_credentials(tmp_path: Path) -> None:
    app = create_app(
        AppConfig(
            mode="live",
            storage_root=tmp_path / "writer",
            anthropic_api_key=None,
            apple_music_developer_token=None,
        )
    )
    client = TestClient(app)

    response = client.get("/v0/preflight")

    assert response.status_code == 200
    payload = response.json()
    assert payload["mode"] == "live"
    assert payload["ready"] is False
    checks = {item["name"]: item for item in payload["checks"]}
    assert checks["anthropic_api_key"]["ok"] is False
    assert checks["apple_music_developer_token"]["ok"] is False


def test_create_run_and_fetch_artifact(tmp_path: Path) -> None:
    app = create_app(AppConfig(mode="mock", storage_root=tmp_path / "writer"))
    client = TestClient(app)

    create_response = client.post(
        "/v0/runs",
        json={
            "prompt": "Tell me about trip-hop albums worth hearing",
            "starter_template": "genre_overview",
        },
    )
    assert create_response.status_code == 202
    run_id = create_response.json()["run_id"]

    status = None
    for _ in range(40):
        status_response = client.get(f"/v0/runs/{run_id}")
        assert status_response.status_code == 200
        status = status_response.json()["status"]
        if status in {"completed", "failed", "cancelled"}:
            break
        time.sleep(0.05)

    assert status == "completed"

    artifact_response = client.get(f"/v0/runs/{run_id}/artifact")
    assert artifact_response.status_code == 200
    artifact = artifact_response.json()
    assert artifact["validation"]["schema_valid"] is True
    assert artifact["validation"]["parser_compatible"] is True
    assert "story_mdx" in artifact

    package_response = client.get(f"/v0/runs/{run_id}/artifact/package")
    assert package_response.status_code == 200
    assert package_response.headers["content-type"] == "application/zip"
    with zipfile.ZipFile(io.BytesIO(package_response.content), mode="r") as zf:
        members = set(zf.namelist())
        assert "story.mdx" in members
        assert "artifact.json" in members
        story_text = zf.read("story.mdx").decode("utf-8")
        assert "<Section" in story_text


def test_cancel_unknown_run_returns_404(tmp_path: Path) -> None:
    app = create_app(AppConfig(mode="mock", storage_root=tmp_path / "writer"))
    client = TestClient(app)

    response = client.post("/v0/runs/run_missing/cancel")

    assert response.status_code == 404
