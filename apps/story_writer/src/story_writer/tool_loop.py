from __future__ import annotations

import json
import asyncio
from dataclasses import dataclass, field
from typing import Literal

import httpx
from pydantic import BaseModel, Field

from story_writer.models import CreateRunRequest
from story_writer.tools.apple_music import AppleMusicResult
from story_writer.tools.wikipedia import WikipediaSummary


ToolAction = Literal["search_apple_music", "search_wikipedia", "finalize"]


class ToolDecision(BaseModel):
    action: ToolAction
    query: str | None = None
    reason: str = Field(default="")


@dataclass
class ToolLoopState:
    request: CreateRunRequest
    max_steps: int
    step: int = 0
    apple_music_results: list[AppleMusicResult] = field(default_factory=list)
    wikipedia_results: list[WikipediaSummary] = field(default_factory=list)
    attempted_queries: list[str] = field(default_factory=list)


class ToolLoopAgent:
    async def decide(self, state: ToolLoopState) -> ToolDecision:
        raise NotImplementedError


class MockToolLoopAgent(ToolLoopAgent):
    async def decide(self, state: ToolLoopState) -> ToolDecision:
        if not state.apple_music_results:
            query = _fallback_query(state.request.prompt, state.attempted_queries)
            return ToolDecision(
                action="search_apple_music",
                query=query,
                reason="need anchor albums",
            )

        if (
            not state.wikipedia_results
            and "search_wikipedia" not in state.attempted_queries
        ):
            return ToolDecision(
                action="search_wikipedia",
                query=state.request.prompt,
                reason="need contextual source",
            )

        return ToolDecision(action="finalize", reason="enough context collected")


class ClaudeToolLoopAgent(ToolLoopAgent):
    def __init__(self, *, api_key: str | None, model_name: str) -> None:
        self.api_key = api_key
        self.model_name = model_name

    async def decide(self, state: ToolLoopState) -> ToolDecision:
        if not self.api_key:
            raise RuntimeError(
                "ANTHROPIC_API_KEY is required when STORY_WRITER_MODE=live."
            )

        system_prompt = (
            "You are a retrieval planner for a music story pipeline. "
            "Choose exactly one next action as JSON. "
            "Allowed actions: search_apple_music, search_wikipedia, finalize. "
            "Before finalize, ensure Apple Music has been queried at least once. "
            "Return JSON only with keys: action, query, reason."
        )

        summary = {
            "prompt": state.request.prompt,
            "step": state.step,
            "max_steps": state.max_steps,
            "apple_music_count": len(state.apple_music_results),
            "wikipedia_count": len(state.wikipedia_results),
            "attempted_queries": state.attempted_queries,
        }

        user_prompt = (
            "Decide the next retrieval action for this run:\n"
            f"{json.dumps(summary, ensure_ascii=True)}\n"
            "If enough information exists, choose finalize."
        )

        raw = await self._call_model(
            system_prompt=system_prompt, user_prompt=user_prompt
        )
        return _parse_decision(raw, fallback_prompt=state.request.prompt)

    async def _call_model(self, *, system_prompt: str, user_prompt: str) -> str:
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        payload = {
            "model": self.model_name,
            "max_tokens": 220,
            "temperature": 0.0,
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
        async with httpx.AsyncClient(timeout=45.0) as client:
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
            raise RuntimeError("Anthropic planner returned no response")

        if response.status_code >= 400:
            raise RuntimeError(
                f"Anthropic planner failed with status {response.status_code}: {response.text}"
            )

        body = response.json()
        chunks: list[str] = []
        for item in body.get("content", []):
            if isinstance(item, dict) and item.get("type") == "text":
                text = item.get("text")
                if isinstance(text, str):
                    chunks.append(text)
        text = "\n".join(chunks).strip()
        if not text:
            raise RuntimeError("Anthropic planner returned empty decision")
        return text


def _parse_decision(raw: str, *, fallback_prompt: str) -> ToolDecision:
    text = raw.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.startswith("json"):
            text = text[4:].strip()

    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        return ToolDecision(
            action="search_apple_music", query=fallback_prompt, reason="fallback parse"
        )

    if not isinstance(payload, dict):
        return ToolDecision(
            action="search_apple_music",
            query=fallback_prompt,
            reason="fallback non-object",
        )

    action = payload.get("action")
    query = payload.get("query")
    reason = payload.get("reason")

    if action not in {"search_apple_music", "search_wikipedia", "finalize"}:
        return ToolDecision(
            action="search_apple_music",
            query=fallback_prompt,
            reason="fallback bad action",
        )

    if action != "finalize" and not isinstance(query, str):
        query = fallback_prompt

    return ToolDecision(
        action=action,
        query=query if isinstance(query, str) else None,
        reason=reason if isinstance(reason, str) else "",
    )


def _fallback_query(prompt: str, attempted: list[str]) -> str:
    if prompt not in attempted:
        return prompt
    lowered = prompt.lower()
    if "prince" in lowered and "Prince" not in attempted:
        return "Prince"
    words = [token for token in prompt.split() if token[:1].isupper()]
    candidate = " ".join(words[:3]).strip()
    if candidate and candidate not in attempted:
        return candidate
    return "music"
