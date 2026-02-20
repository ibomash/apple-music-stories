from __future__ import annotations

import asyncio
from dataclasses import dataclass
from pathlib import Path

from story_writer.config import AppConfig
from story_writer.models import CreateRunRequest
from story_writer.orchestrator import MockStoryWriter, StoryOrchestrator
from story_writer.storage import LocalRunStore
from story_writer.tools.apple_music import AppleMusicResult
from story_writer.tools.wikipedia import WikipediaClient, WikipediaSummary


@dataclass
class RetryAppleMusicClient:
    calls: list[str]

    async def search_catalog(
        self, query: str, limit: int = 5
    ) -> list[AppleMusicResult]:
        self.calls.append(query)
        if len(self.calls) == 1:
            return []
        return [
            AppleMusicResult(
                key="album-1",
                media_type="album",
                apple_music_id="1746833068",
                title="Purple Rain",
                artist="Prince & The Revolution",
                artwork_url=None,
                url="https://music.apple.com/us/album/purple-rain/1746833068",
            )
        ]


class EmptyWikiClient:
    async def search(self, query: str, limit: int = 3) -> list[WikipediaSummary]:
        return []


def test_orchestrator_retries_with_simpler_apple_music_query(tmp_path: Path) -> None:
    store = LocalRunStore(tmp_path / "writer")
    config = AppConfig(mode="mock", storage_root=tmp_path / "writer")
    request = CreateRunRequest(
        prompt="Write a full retrospective of Prince's career including major eras and key albums"
    )
    created = store.create_run(request)

    apple_client = RetryAppleMusicClient(calls=[])
    orchestrator = StoryOrchestrator(
        store=store,
        config=config,
        apple_music_client=apple_client,
        wikipedia_client=EmptyWikiClient(),
        writer=MockStoryWriter(),
    )

    asyncio.run(orchestrator.run(created.run_id, request))

    state = store.get_run(created.run_id)
    assert state is not None
    assert state.status == "completed"
    assert len(apple_client.calls) >= 2
    assert apple_client.calls[0] != apple_client.calls[1]

    events = store.list_events(created.run_id)
    assert events is not None
    assert any(
        event.type == "model_note"
        and event.message.startswith("Retrying Apple Music search with simpler query:")
        for event in events
    )


def test_wikipedia_client_sends_user_agent_header(monkeypatch) -> None:
    calls: list[tuple[str, dict[str, str] | None]] = []

    class FakeResponse:
        def __init__(self, status_code: int, payload: dict):
            self.status_code = status_code
            self._payload = payload
            self.text = ""

        def json(self) -> dict:
            return self._payload

    class FakeAsyncClient:
        def __init__(self, timeout: float):  # noqa: ARG002
            pass

        async def __aenter__(self) -> "FakeAsyncClient":
            return self

        async def __aexit__(self, exc_type, exc, tb) -> None:  # noqa: ANN001
            return None

        async def get(self, url: str, params=None, headers=None):  # noqa: ANN001
            calls.append((url, headers))
            if "search/title" in url:
                return FakeResponse(200, {"pages": [{"title": "Prince"}]})
            return FakeResponse(
                200,
                {
                    "title": "Prince",
                    "extract": "Prince was an American singer-songwriter.",
                    "content_urls": {
                        "desktop": {
                            "page": "https://en.wikipedia.org/wiki/Prince_(musician)"
                        }
                    },
                },
            )

    import story_writer.tools.wikipedia as wikipedia_module

    monkeypatch.setattr(wikipedia_module.httpx, "AsyncClient", FakeAsyncClient)

    client = WikipediaClient(timeout_seconds=1.0)
    results = asyncio.run(client.search("Prince", limit=1))

    assert results
    assert len(calls) >= 2
    for _, headers in calls:
        assert headers is not None
        assert (
            headers.get("User-Agent")
            == "apple-music-stories-story-writer/0.1 (local-dev)"
        )
