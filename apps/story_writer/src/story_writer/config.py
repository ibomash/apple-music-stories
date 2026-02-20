from __future__ import annotations

import os
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, Field


class AppConfig(BaseModel):
    mode: Literal["mock", "live"] = "mock"
    host: str = "127.0.0.1"
    port: int = 8787
    storage_root: Path = Field(default=Path(".cache/story-writer"))
    anthropic_api_key: str | None = None
    model_name: str = "claude-sonnet-4-6"
    apple_music_developer_token: str | None = None
    apple_music_storefront: str = "us"
    apple_music_timeout_seconds: float = 15.0
    wikipedia_timeout_seconds: float = 10.0
    tool_loop_max_steps: int = 6

    @classmethod
    def from_env(cls) -> "AppConfig":
        return cls(
            mode=_env_str("STORY_WRITER_MODE", "mock"),
            host=_env_str("STORY_WRITER_HOST", "127.0.0.1"),
            port=_env_int("STORY_WRITER_PORT", 8787),
            storage_root=Path(
                _env_str("STORY_WRITER_STORAGE_ROOT", ".cache/story-writer")
            ),
            anthropic_api_key=_env_optional_str("ANTHROPIC_API_KEY"),
            model_name=_env_str("STORY_WRITER_MODEL", "claude-sonnet-4-6"),
            apple_music_developer_token=(
                _env_optional_str("APPLE_MUSIC_DEVELOPER_TOKEN")
                or _read_optional_token_file(
                    _env_optional_str("APPLE_MUSIC_DEVELOPER_TOKEN_PATH")
                )
            ),
            apple_music_storefront=_env_str("APPLE_MUSIC_STOREFRONT", "us"),
            apple_music_timeout_seconds=_env_float("APPLE_MUSIC_TIMEOUT_SECONDS", 15.0),
            wikipedia_timeout_seconds=_env_float("WIKIPEDIA_TIMEOUT_SECONDS", 10.0),
            tool_loop_max_steps=_env_int("STORY_WRITER_TOOL_LOOP_MAX_STEPS", 6),
        )


def _env_str(name: str, default: str) -> str:
    value = os.environ.get(name)
    return value if value else default


def _env_optional_str(name: str) -> str | None:
    value = os.environ.get(name)
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


def _env_int(name: str, default: int) -> int:
    value = os.environ.get(name)
    if value is None or value.strip() == "":
        return default
    try:
        return int(value)
    except ValueError:
        return default


def _env_float(name: str, default: float) -> float:
    value = os.environ.get(name)
    if value is None or value.strip() == "":
        return default
    try:
        return float(value)
    except ValueError:
        return default


def _read_optional_token_file(path_value: str | None) -> str | None:
    if not path_value:
        return None
    try:
        token = Path(path_value).read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return token or None
