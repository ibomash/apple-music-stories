from __future__ import annotations

import datetime as dt
import asyncio
from dataclasses import dataclass

import httpx

from story_writer.config import AppConfig
from story_writer.models import CreateRunRequest, ProvenancePayload, StoryArtifact
from story_writer.storage import LocalRunStore
from story_writer.tool_loop import (
    ClaudeToolLoopAgent,
    MockToolLoopAgent,
    ToolDecision,
    ToolLoopAgent,
    ToolLoopState,
)
from story_writer.tools import (
    AppleMusicAuthError,
    AppleMusicClient,
    AppleMusicResult,
    MockAppleMusicClient,
    MockWikipediaClient,
    SourceTracker,
    WikipediaClient,
    WikipediaSummary,
    maybe_inline_reference,
)
from story_writer.validation import validate_story_document


class CancelledRunError(RuntimeError):
    pass


@dataclass(frozen=True)
class GeneratedDraft:
    story_mdx: str
    notes: list[str]


class StoryWriter:
    async def write_story(
        self,
        request: CreateRunRequest,
        apple_music_results: list[AppleMusicResult],
        wikipedia_results: list[WikipediaSummary],
    ) -> GeneratedDraft:
        raise NotImplementedError

    async def repair_story(
        self, draft_story_mdx: str, diagnostics: list[str]
    ) -> GeneratedDraft:
        raise NotImplementedError


class MockStoryWriter(StoryWriter):
    async def write_story(
        self,
        request: CreateRunRequest,
        apple_music_results: list[AppleMusicResult],
        wikipedia_results: list[WikipediaSummary],
    ) -> GeneratedDraft:
        story_mdx = _build_deterministic_story(
            request, apple_music_results, wikipedia_results
        )
        return GeneratedDraft(
            story_mdx=story_mdx,
            notes=[
                "create TOC",
                "draft intro and album picks",
                "assemble end notes",
            ],
        )

    async def repair_story(
        self, draft_story_mdx: str, diagnostics: list[str]
    ) -> GeneratedDraft:
        # Keep repair simple in mock mode. If it already validates, return as-is.
        return GeneratedDraft(
            story_mdx=draft_story_mdx,
            notes=[f"repair attempted: {len(diagnostics)} diagnostics"],
        )


class ClaudeStoryWriter(StoryWriter):
    def __init__(self, *, api_key: str | None, model_name: str) -> None:
        self.api_key = api_key
        self.model_name = model_name

    async def write_story(
        self,
        request: CreateRunRequest,
        apple_music_results: list[AppleMusicResult],
        wikipedia_results: list[WikipediaSummary],
    ) -> GeneratedDraft:
        if not self.api_key:
            raise RuntimeError(
                "ANTHROPIC_API_KEY is required when STORY_WRITER_MODE=live."
            )

        system_prompt = (
            "You write music journalism stories in strict MDX format for this schema. "
            "Return only a full story document with front matter and <Section> blocks. "
            "Do not include markdown fences."
        )
        user_prompt = _build_live_user_prompt(
            request, apple_music_results, wikipedia_results
        )
        response_text = await self._call_model(
            system_prompt=system_prompt, user_prompt=user_prompt
        )
        return GeneratedDraft(story_mdx=response_text, notes=["model draft completed"])

    async def repair_story(
        self, draft_story_mdx: str, diagnostics: list[str]
    ) -> GeneratedDraft:
        if not self.api_key:
            raise RuntimeError(
                "ANTHROPIC_API_KEY is required when STORY_WRITER_MODE=live."
            )

        system_prompt = (
            "You repair an MDX story document to satisfy schema constraints. "
            "Return only the corrected document with front matter and <Section> blocks."
        )
        diagnostic_text = "\n".join(f"- {item}" for item in diagnostics)
        user_prompt = (
            "Fix this story so validation passes.\n\n"
            f"Diagnostics:\n{diagnostic_text}\n\n"
            "Story:\n"
            f"{draft_story_mdx}"
        )
        response_text = await self._call_model(
            system_prompt=system_prompt, user_prompt=user_prompt
        )
        return GeneratedDraft(story_mdx=response_text, notes=["model repair attempted"])

    async def _call_model(self, *, system_prompt: str, user_prompt: str) -> str:
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        payload = {
            "model": self.model_name,
            "max_tokens": 2600,
            "temperature": 0.4,
            "system": system_prompt,
            "messages": [
                {
                    "role": "user",
                    "content": [{"type": "text", "text": user_prompt}],
                }
            ],
        }

        retries = 2
        response: httpx.Response | None = None
        async with httpx.AsyncClient(timeout=90.0) as client:
            for attempt in range(retries + 1):
                response = await client.post(
                    "https://api.anthropic.com/v1/messages",
                    headers=headers,
                    json=payload,
                )
                if response.status_code not in {429, 529}:
                    break
                if attempt < retries:
                    await asyncio.sleep(1.0 * (attempt + 1))

        if response is None:
            raise RuntimeError("Anthropic request returned no response")

        if response.status_code >= 400:
            raise RuntimeError(
                f"Anthropic request failed with status {response.status_code}: {response.text}"
            )

        body = response.json()
        content = body.get("content")
        if not isinstance(content, list):
            raise RuntimeError("Anthropic response missing content list.")

        chunks: list[str] = []
        for item in content:
            if not isinstance(item, dict):
                continue
            if item.get("type") == "text" and isinstance(item.get("text"), str):
                chunks.append(item["text"])

        text = "\n".join(chunks).strip()
        if not text:
            raise RuntimeError("Anthropic response did not include story text.")
        return text


class StoryOrchestrator:
    def __init__(
        self,
        *,
        store: LocalRunStore,
        config: AppConfig,
        apple_music_client: AppleMusicClient | MockAppleMusicClient | None = None,
        wikipedia_client: WikipediaClient | MockWikipediaClient | None = None,
        writer: StoryWriter | None = None,
        tool_loop_agent: ToolLoopAgent | None = None,
    ) -> None:
        self.store = store
        self.config = config
        self.apple_music_client = apple_music_client or _build_apple_music_client(
            config
        )
        self.wikipedia_client = wikipedia_client or _build_wikipedia_client(config)
        self.writer = writer or _build_writer(config)
        self.tool_loop_agent = tool_loop_agent or _build_tool_loop_agent(config)
        self.fallback_tool_loop_agent: ToolLoopAgent = MockToolLoopAgent()

    async def run(self, run_id: str, request: CreateRunRequest) -> None:
        self.store.set_status(run_id, "running")
        self.store.append_event(run_id, "run_started", "Run started")

        try:
            self._raise_if_cancelled(run_id)
            source_tracker = SourceTracker()

            apple_music_results, wikipedia_results = await self._run_tool_loop(
                run_id=run_id,
                request=request,
                source_tracker=source_tracker,
            )

            if not apple_music_results:
                raise RuntimeError("Apple Music search returned no results.")

            self._raise_if_cancelled(run_id)

            draft = await self.writer.write_story(
                request, apple_music_results, wikipedia_results
            )
            for note in draft.notes:
                self.store.append_event(run_id, "model_note", note)

            self.store.append_event(
                run_id, "validation_started", "Running schema and parser checks"
            )
            validation = validate_story_document(draft.story_mdx)
            story_mdx = draft.story_mdx

            if not validation.schema_valid or not validation.parser_compatible:
                self.store.append_event(
                    run_id, "validation_repair_attempted", "Running one repair pass"
                )
                repaired = await self.writer.repair_story(
                    story_mdx, validation.diagnostics
                )
                for note in repaired.notes:
                    self.store.append_event(run_id, "model_note", note)
                story_mdx = repaired.story_mdx
                validation = validate_story_document(story_mdx)

            if not validation.schema_valid or not validation.parser_compatible:
                raise RuntimeError("Validation failed after repair pass.")

            end_notes = source_tracker.end_notes()
            source_ids = [item.source_id for item in end_notes]
            inline_ref = maybe_inline_reference(
                section_id="context",
                source_ids=source_ids[:2],
                confidence=_inline_reference_confidence(wikipedia_results),
            )
            inline_refs = [inline_ref] if inline_ref else []

            provenance = ProvenancePayload(
                end_notes=end_notes,
                inline_references=inline_refs,
                acknowledgements=["Sources: Apple Music and Wikipedia"],
            )

            artifact = StoryArtifact(
                run_id=run_id,
                story_mdx=story_mdx,
                provenance=provenance,
                validation=validation,
            )
            self.store.save_artifact(artifact)

            self._raise_if_cancelled(run_id)
            self.store.set_status(run_id, "completed")
            self.store.append_event(run_id, "run_completed", "Run completed")
        except CancelledRunError:
            self.store.set_status(run_id, "cancelled")
            self.store.append_event(run_id, "run_cancelled", "Run cancelled")
        except AppleMusicAuthError as exc:
            message = str(exc)
            self.store.set_status(run_id, "failed", error=message)
            self.store.append_event(run_id, "run_failed", message)
        except Exception as exc:  # noqa: BLE001
            message = str(exc).strip() or repr(exc)
            self.store.set_status(run_id, "failed", error=message)
            self.store.append_event(run_id, "run_failed", message)

    def _raise_if_cancelled(self, run_id: str) -> None:
        if self.store.is_cancel_requested(run_id):
            raise CancelledRunError("Run cancelled")

    async def _run_tool_loop(
        self,
        *,
        run_id: str,
        request: CreateRunRequest,
        source_tracker: SourceTracker,
    ) -> tuple[list[AppleMusicResult], list[WikipediaSummary]]:
        state = ToolLoopState(
            request=request, max_steps=self.config.tool_loop_max_steps
        )
        finalized = False

        for step in range(1, self.config.tool_loop_max_steps + 1):
            self._raise_if_cancelled(run_id)
            state.step = step
            try:
                decision = await self.tool_loop_agent.decide(state)
            except Exception as exc:  # noqa: BLE001
                self.store.append_event(
                    run_id,
                    "model_note",
                    f"tool-loop planner unavailable, using fallback strategy: {exc}",
                )
                decision = await self.fallback_tool_loop_agent.decide(state)
            decision = self._normalize_decision(state, decision)
            self.store.append_event(
                run_id,
                "model_note",
                f"tool-loop action: {decision.action} ({decision.reason})",
            )

            if decision.action == "finalize":
                finalized = True
                break

            if decision.action == "search_apple_music":
                await self._execute_apple_music_step(
                    run_id, state, decision, source_tracker
                )
                continue

            if decision.action == "search_wikipedia":
                await self._execute_wikipedia_step(
                    run_id, state, decision, source_tracker
                )
                continue

        if not finalized:
            self.store.append_event(
                run_id,
                "model_note",
                "tool-loop reached max steps; proceeding with collected context",
            )

        return state.apple_music_results, state.wikipedia_results

    def _normalize_decision(
        self,
        state: ToolLoopState,
        decision: ToolDecision,
    ) -> ToolDecision:
        if decision.action == "search_apple_music":
            return decision

        remaining_steps = self.config.tool_loop_max_steps - state.step
        if not state.apple_music_results and remaining_steps <= 2:
            fallback_query = _candidate_queries(state.request.prompt)[0]
            return ToolDecision(
                action="search_apple_music",
                query=fallback_query,
                reason="forced fallback to ensure Apple Music anchors before finalize",
            )
        return decision

    async def _execute_apple_music_step(
        self,
        run_id: str,
        state: ToolLoopState,
        decision: ToolDecision,
        source_tracker: SourceTracker,
    ) -> None:
        query = decision.query or state.request.prompt
        if query in state.attempted_queries:
            fallback = _candidate_queries(state.request.prompt)
            for item in fallback:
                if item not in state.attempted_queries:
                    query = item
                    break

        state.attempted_queries.append(query)
        self.store.append_event(
            run_id, "tool_call_started", f"Searching Apple Music: {query}"
        )
        results = await self.apple_music_client.search_catalog(query, limit=5)
        self.store.append_event(
            run_id,
            "tool_call_completed",
            f"Apple Music returned {len(results)} result(s)",
        )
        state.apple_music_results = results
        for item in results:
            if item.url:
                source_tracker.add(
                    label=f"Apple Music - {item.title}",
                    url=item.url,
                    source_type="apple_music",
                )

    async def _execute_wikipedia_step(
        self,
        run_id: str,
        state: ToolLoopState,
        decision: ToolDecision,
        source_tracker: SourceTracker,
    ) -> None:
        query = decision.query or state.request.prompt
        state.attempted_queries.append("search_wikipedia")
        self.store.append_event(
            run_id, "tool_call_started", f"Searching Wikipedia: {query}"
        )
        results = await self.wikipedia_client.search(query, limit=3)
        self.store.append_event(
            run_id,
            "tool_call_completed",
            f"Wikipedia returned {len(results)} result(s)",
        )
        state.wikipedia_results = results
        for item in results:
            source_tracker.add(
                label=f"Wikipedia - {item.title}",
                url=item.url,
                source_type="wikipedia",
            )


def _build_apple_music_client(
    config: AppConfig,
) -> AppleMusicClient | MockAppleMusicClient:
    if config.mode == "mock":
        return MockAppleMusicClient()
    return AppleMusicClient(
        developer_token=config.apple_music_developer_token,
        storefront=config.apple_music_storefront,
        timeout_seconds=config.apple_music_timeout_seconds,
    )


def _build_wikipedia_client(config: AppConfig) -> WikipediaClient | MockWikipediaClient:
    if config.mode == "mock":
        return MockWikipediaClient()
    return WikipediaClient(timeout_seconds=config.wikipedia_timeout_seconds)


def _build_writer(config: AppConfig) -> StoryWriter:
    if config.mode == "mock":
        return MockStoryWriter()
    return ClaudeStoryWriter(
        api_key=config.anthropic_api_key, model_name=config.model_name
    )


def _build_tool_loop_agent(config: AppConfig) -> ToolLoopAgent:
    if config.mode == "mock":
        return MockToolLoopAgent()
    return ClaudeToolLoopAgent(
        api_key=config.anthropic_api_key,
        model_name=config.model_name,
    )


def _inline_reference_confidence(wikipedia_results: list[WikipediaSummary]) -> float:
    if wikipedia_results:
        return 0.8
    return 0.5


def _build_live_user_prompt(
    request: CreateRunRequest,
    apple_music_results: list[AppleMusicResult],
    wikipedia_results: list[WikipediaSummary],
) -> str:
    template = request.starter_template or "custom"
    today = dt.date.today().isoformat()
    album_lines = "\n".join(
        f"- {item.title} - {item.artist} ({item.media_type}, id={item.apple_music_id}, key={item.key})"
        for item in apple_music_results
    )
    wiki_lines = "\n".join(
        f"- {item.title}: {item.summary[:240]} ({item.url})"
        for item in wikipedia_results
    )
    return (
        f"Date: {today}\n"
        f"Starter template: {template}\n"
        f"User prompt: {request.prompt}\n"
        f"Length hint: {request.length_hint or '10min'}\n"
        f"Tone hint: {request.tone_hint or 'critical + contextual'}\n\n"
        "Use these Apple Music retrieval results:\n"
        f"{album_lines}\n\n"
        "Use these Wikipedia summaries:\n"
        f"{wiki_lines}\n\n"
        "Output requirements:\n"
        "1) Return valid story.mdx with front matter and <Section> blocks only.\n"
        "2) Include required front matter fields: schema_version, id, title, authors, publish_date, sections, media.\n"
        "3) Ensure each media reference appears in media[] with key/type/apple_music_id/title/artist.\n"
        '4) Include at least two sections and at least one <MediaRef ref="..." />.\n'
    )


def _build_deterministic_story(
    request: CreateRunRequest,
    apple_music_results: list[AppleMusicResult],
    wikipedia_results: list[WikipediaSummary],
) -> str:
    today = dt.date.today().isoformat()
    slug = _slugify(request.prompt) or "music-story"
    story_id = f"story-{slug[:40]}"
    title = f"{request.prompt.strip().title()}"

    media_entries = []
    for item in apple_music_results:
        media_entries.append(
            "  - key: {key}\n"
            "    type: {media_type}\n"
            '    apple_music_id: "{apple_music_id}"\n'
            "    title: {title}\n"
            "    artist: {artist}\n"
            "    artwork_url: {artwork_url}".format(
                key=item.key,
                media_type=item.media_type,
                apple_music_id=item.apple_music_id,
                title=item.title.replace('"', "'"),
                artist=item.artist.replace('"', "'"),
                artwork_url=item.artwork_url or "",
            )
        )

    wiki_context = wikipedia_results[0].summary if wikipedia_results else ""
    lead_media_key = apple_music_results[0].key

    return (
        "---\n"
        'schema_version: "0.1"\n'
        f"id: {story_id}\n"
        f'title: "{title}"\n'
        "authors:\n"
        "  - Music Story Writer\n"
        f'publish_date: "{today}"\n'
        "sections:\n"
        "  - id: context\n"
        "    title: Context\n"
        f"    lead_media: {lead_media_key}\n"
        "  - id: listening\n"
        "    title: Listening Path\n"
        "media:\n" + "\n".join(media_entries) + "\n"
        "---\n\n"
        '<Section id="context" title="Context">\n'
        f"{request.prompt.strip()} is best understood through a few records that shaped the mood and production language of the scene. {wiki_context}\n"
        f'<MediaRef ref="{lead_media_key}" />\n'
        "</Section>\n\n"
        '<Section id="listening" title="Listening Path">\n'
        "Start with the lead album, then branch to the connected releases listed in this story. Focus on production texture, vocal approach, and sequencing choices to hear what changed over time.\n"
        "</Section>\n"
    )


def _slugify(value: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "-" for ch in value)
    while "--" in cleaned:
        cleaned = cleaned.replace("--", "-")
    return cleaned.strip("-")


def _candidate_queries(prompt: str) -> list[str]:
    candidates: list[str] = []
    stripped = prompt.strip()
    if stripped:
        candidates.append(stripped)

    lower = stripped.lower()
    if "prince" in lower:
        candidates.append("Prince")

    title_words = [token for token in stripped.split() if token[:1].isupper()]
    if title_words:
        candidates.append(" ".join(title_words[:3]))

    content_words = [
        token for token in stripped.split() if token.isalpha() and len(token) > 4
    ]
    if content_words:
        candidates.append(" ".join(content_words[:4]))

    deduped: list[str] = []
    seen: set[str] = set()
    for candidate in candidates:
        normalized = candidate.strip()
        if not normalized:
            continue
        key = normalized.lower()
        if key in seen:
            continue
        seen.add(key)
        deduped.append(normalized)
    return deduped or ["music"]
