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
from story_writer.tool_loop import ToolDecision


@dataclass
class RetryAppleMusicClient:
    calls: list[str]

    async def search_catalog(
        self, query: str, limit: int = 5
    ) -> list[AppleMusicResult]:
        self.calls.append(query)
        if len(self.calls) == 1:
            return []
        return [_sample_album_result()]


@dataclass
class CaptureAppleMusicClient:
    calls: list[str]

    async def search_catalog(
        self, query: str, limit: int = 5
    ) -> list[AppleMusicResult]:
        self.calls.append(query)
        return [_sample_album_result()]


@dataclass
class FirstHitThenEmptyAppleMusicClient:
    calls: list[str]

    async def search_catalog(
        self, query: str, limit: int = 5
    ) -> list[AppleMusicResult]:
        self.calls.append(query)
        if len(self.calls) == 1:
            return [_sample_album_result()]
        return []


class EmptyWikiClient:
    async def search(self, query: str, limit: int = 3) -> list[WikipediaSummary]:
        return []


class StubToolLoopAgent:
    def __init__(self) -> None:
        self._decisions = [
            ToolDecision(
                action="search_apple_music",
                query="Prince retrospective",
                reason="seed music",
            ),
            ToolDecision(
                action="search_apple_music",
                query="Prince",
                reason="narrow search",
            ),
            ToolDecision(
                action="search_wikipedia", query="Prince", reason="need context"
            ),
            ToolDecision(action="finalize", reason="enough sources"),
        ]
        self.calls: int = 0

    async def decide(self, state):  # noqa: ANN001
        decision = self._decisions[min(self.calls, len(self._decisions) - 1)]
        self.calls += 1
        return decision


class AlwaysWikipediaAgent:
    async def decide(self, state):  # noqa: ANN001
        return ToolDecision(action="search_wikipedia", query="Prince", reason="loop")


class FailingAgent:
    async def decide(self, state):  # noqa: ANN001
        raise RuntimeError("planner overloaded")


class InstructionalPromptAgent:
    def __init__(self) -> None:
        self.calls = 0

    async def decide(self, state):  # noqa: ANN001
        if self.calls == 0:
            self.calls += 1
            return ToolDecision(
                action="search_apple_music",
                query=state.request.prompt,
                reason="use prompt directly",
            )
        return ToolDecision(action="finalize", reason="done")


class FinalizeTooEarlyAgent:
    def __init__(self) -> None:
        self.calls = 0

    async def decide(self, state):  # noqa: ANN001
        if self.calls == 0:
            self.calls += 1
            return ToolDecision(
                action="search_apple_music",
                query="rare underground pioneers",
                reason="first attempt",
            )
        self.calls += 1
        return ToolDecision(action="finalize", reason="no more needed")


class FirstHitThenEmptyAgent:
    def __init__(self) -> None:
        self.calls = 0

    async def decide(self, state):  # noqa: ANN001
        self.calls += 1
        if self.calls == 1:
            return ToolDecision(
                action="search_apple_music",
                query="Massive Attack",
                reason="seed anchors",
            )
        if self.calls == 2:
            return ToolDecision(
                action="search_apple_music",
                query="not-a-real-match-zxyq",
                reason="probe alternate term",
            )
        return ToolDecision(action="finalize", reason="ready to write")


def _sample_album_result() -> AppleMusicResult:
    return AppleMusicResult(
        key="album-1",
        media_type="album",
        apple_music_id="1746833068",
        title="Purple Rain",
        artist="Prince & The Revolution",
        artwork_url=None,
        url="https://music.apple.com/us/album/purple-rain/1746833068",
    )


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
        event.message.startswith("tool-loop action: search_apple_music")
        for event in events
    )


def test_orchestrator_executes_model_driven_tool_loop(tmp_path: Path) -> None:
    store = LocalRunStore(tmp_path / "writer")
    config = AppConfig(mode="mock", storage_root=tmp_path / "writer")
    request = CreateRunRequest(prompt="Prince retrospective")
    created = store.create_run(request)

    agent = StubToolLoopAgent()
    orchestrator = StoryOrchestrator(
        store=store,
        config=config,
        apple_music_client=RetryAppleMusicClient(calls=[]),
        wikipedia_client=EmptyWikiClient(),
        writer=MockStoryWriter(),
        tool_loop_agent=agent,
    )

    asyncio.run(orchestrator.run(created.run_id, request))

    state = store.get_run(created.run_id)
    assert state is not None
    assert state.status == "completed"
    assert agent.calls >= 4

    events = store.list_events(created.run_id)
    assert events is not None
    assert any(
        event.message.startswith("tool-loop action: search_apple_music")
        for event in events
    )
    assert any(
        event.message.startswith("tool-loop action: search_wikipedia")
        for event in events
    )


def test_orchestrator_forces_apple_music_before_loop_end(tmp_path: Path) -> None:
    store = LocalRunStore(tmp_path / "writer")
    config = AppConfig(
        mode="mock", storage_root=tmp_path / "writer", tool_loop_max_steps=3
    )
    request = CreateRunRequest(prompt="Prince retrospective")
    created = store.create_run(request)
    apple_client = RetryAppleMusicClient(calls=[])

    orchestrator = StoryOrchestrator(
        store=store,
        config=config,
        apple_music_client=apple_client,
        wikipedia_client=EmptyWikiClient(),
        writer=MockStoryWriter(),
        tool_loop_agent=AlwaysWikipediaAgent(),
    )

    asyncio.run(orchestrator.run(created.run_id, request))

    state = store.get_run(created.run_id)
    assert state is not None
    assert state.status == "completed"
    assert len(apple_client.calls) >= 1
    events = store.list_events(created.run_id)
    assert events is not None
    assert any(
        event.message
        == "tool-loop reached max steps; proceeding with collected context"
        for event in events
    )


def test_orchestrator_falls_back_when_planner_fails(tmp_path: Path) -> None:
    store = LocalRunStore(tmp_path / "writer")
    config = AppConfig(mode="mock", storage_root=tmp_path / "writer")
    request = CreateRunRequest(prompt="Prince retrospective")
    created = store.create_run(request)

    orchestrator = StoryOrchestrator(
        store=store,
        config=config,
        apple_music_client=RetryAppleMusicClient(calls=[]),
        wikipedia_client=EmptyWikiClient(),
        writer=MockStoryWriter(),
        tool_loop_agent=FailingAgent(),
    )

    asyncio.run(orchestrator.run(created.run_id, request))

    state = store.get_run(created.run_id)
    assert state is not None
    assert state.status == "completed"
    events = store.list_events(created.run_id)
    assert events is not None
    assert any("using fallback strategy" in event.message for event in events)


def test_orchestrator_normalizes_instructional_apple_music_queries(
    tmp_path: Path,
) -> None:
    store = LocalRunStore(tmp_path / "writer")
    config = AppConfig(mode="mock", storage_root=tmp_path / "writer")
    request = CreateRunRequest(
        prompt=(
            "Write an overview of trip-hop past Portishead in two big sections "
            "covering the era and what came later"
        )
    )
    created = store.create_run(request)
    apple_client = CaptureAppleMusicClient(calls=[])

    orchestrator = StoryOrchestrator(
        store=store,
        config=config,
        apple_music_client=apple_client,
        wikipedia_client=EmptyWikiClient(),
        writer=MockStoryWriter(),
        tool_loop_agent=InstructionalPromptAgent(),
    )

    asyncio.run(orchestrator.run(created.run_id, request))

    assert apple_client.calls
    assert apple_client.calls[0] != request.prompt
    assert len(apple_client.calls[0].split()) <= 6


def test_orchestrator_retries_instead_of_finalizing_without_anchors(
    tmp_path: Path,
) -> None:
    store = LocalRunStore(tmp_path / "writer")
    config = AppConfig(mode="mock", storage_root=tmp_path / "writer")
    request = CreateRunRequest(prompt="Trip-hop essentials beyond Portishead")
    created = store.create_run(request)
    apple_client = RetryAppleMusicClient(calls=[])

    orchestrator = StoryOrchestrator(
        store=store,
        config=config,
        apple_music_client=apple_client,
        wikipedia_client=EmptyWikiClient(),
        writer=MockStoryWriter(),
        tool_loop_agent=FinalizeTooEarlyAgent(),
    )

    asyncio.run(orchestrator.run(created.run_id, request))

    state = store.get_run(created.run_id)
    assert state is not None
    assert state.status == "completed"
    assert len(apple_client.calls) >= 2

    events = store.list_events(created.run_id)
    assert events is not None
    assert any(
        "cannot finalize without Apple Music anchors" in event.message
        for event in events
    )


def test_orchestrator_keeps_prior_apple_music_hits_when_later_query_is_empty(
    tmp_path: Path,
) -> None:
    store = LocalRunStore(tmp_path / "writer")
    config = AppConfig(mode="mock", storage_root=tmp_path / "writer")
    request = CreateRunRequest(prompt="Trip-hop listening guide")
    created = store.create_run(request)

    orchestrator = StoryOrchestrator(
        store=store,
        config=config,
        apple_music_client=FirstHitThenEmptyAppleMusicClient(calls=[]),
        wikipedia_client=EmptyWikiClient(),
        writer=MockStoryWriter(),
        tool_loop_agent=FirstHitThenEmptyAgent(),
    )

    asyncio.run(orchestrator.run(created.run_id, request))

    state = store.get_run(created.run_id)
    assert state is not None
    assert state.status == "completed"


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
