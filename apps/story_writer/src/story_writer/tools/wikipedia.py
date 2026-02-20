from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from urllib.parse import quote

import httpx


class WikipediaError(RuntimeError):
    pass


@dataclass(frozen=True)
class WikipediaSummary:
    title: str
    url: str
    summary: str


class WikipediaClient:
    def __init__(self, *, timeout_seconds: float = 10.0) -> None:
        self.timeout_seconds = timeout_seconds
        self.user_agent = "apple-music-stories-story-writer/0.1 (local-dev)"

    async def search(self, query: str, limit: int = 3) -> list[WikipediaSummary]:
        endpoint = "https://en.wikipedia.org/w/rest.php/v1/search/title"
        params = {"q": query, "limit": str(limit)}
        headers = {"User-Agent": self.user_agent}

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            search_response = await client.get(endpoint, params=params, headers=headers)
        if search_response.status_code >= 400:
            raise WikipediaError(
                f"Wikipedia search failed with status {search_response.status_code}: {search_response.text}"
            )

        payload = search_response.json()
        pages = payload.get("pages")
        if not isinstance(pages, list):
            return []

        summaries: list[WikipediaSummary] = []
        for page in pages:
            title = _extract_title(page)
            if not title:
                continue
            summary = await self.fetch_summary(title)
            if summary:
                summaries.append(summary)
        return summaries

    async def fetch_summary(self, title: str) -> WikipediaSummary | None:
        endpoint = f"https://en.wikipedia.org/api/rest_v1/page/summary/{quote(title)}"
        headers = {"User-Agent": self.user_agent}

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.get(endpoint, headers=headers)
        if response.status_code == 404:
            return None
        if response.status_code >= 400:
            raise WikipediaError(
                f"Wikipedia summary failed with status {response.status_code}: {response.text}"
            )

        payload = response.json()
        parsed_title = payload.get("title")
        extract = payload.get("extract")
        content_urls = payload.get("content_urls")
        if not isinstance(parsed_title, str) or not isinstance(extract, str):
            return None

        url = f"https://en.wikipedia.org/wiki/{quote(parsed_title.replace(' ', '_'))}"
        if isinstance(content_urls, dict):
            desktop = content_urls.get("desktop")
            if isinstance(desktop, dict):
                page_url = desktop.get("page")
                if isinstance(page_url, str):
                    url = page_url

        return WikipediaSummary(title=parsed_title, url=url, summary=extract)


def _extract_title(page: Any) -> str | None:
    if not isinstance(page, dict):
        return None
    title = page.get("title")
    if isinstance(title, str) and title.strip():
        return title.strip()
    return None


class MockWikipediaClient:
    async def search(self, query: str, limit: int = 3) -> list[WikipediaSummary]:
        topic = query.strip().title() or "Music"
        return [
            WikipediaSummary(
                title=f"{topic} (music)",
                url=f"https://en.wikipedia.org/wiki/{quote(topic.replace(' ', '_'))}",
                summary=(
                    f"{topic} is described as a music movement with notable albums and artists. "
                    "Its influence includes shifts in production style, mood, and listening culture."
                ),
            )
        ][:limit]
