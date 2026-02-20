from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import httpx


class AppleMusicError(RuntimeError):
    pass


class AppleMusicAuthError(AppleMusicError):
    pass


@dataclass(frozen=True)
class AppleMusicResult:
    key: str
    media_type: str
    apple_music_id: str
    title: str
    artist: str
    artwork_url: str | None
    url: str | None


class AppleMusicClient:
    def __init__(
        self,
        *,
        developer_token: str | None,
        storefront: str,
        timeout_seconds: float,
    ) -> None:
        self.developer_token = developer_token
        self.storefront = storefront
        self.timeout_seconds = timeout_seconds

    async def search_catalog(
        self, query: str, limit: int = 5
    ) -> list[AppleMusicResult]:
        if not self.developer_token:
            raise AppleMusicAuthError(
                "APPLE_MUSIC_DEVELOPER_TOKEN (or APPLE_MUSIC_DEVELOPER_TOKEN_PATH) is required."
            )

        endpoint = f"https://api.music.apple.com/v1/catalog/{self.storefront}/search"
        headers = {
            "Authorization": f"Bearer {self.developer_token}",
            "Accept": "application/json",
        }
        params = {
            "term": query,
            "types": "albums,songs",
            "limit": str(limit),
        }

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.get(endpoint, headers=headers, params=params)

        if response.status_code in {401, 403}:
            raise AppleMusicAuthError(
                f"Apple Music request failed with status {response.status_code}; check token/storefront."
            )
        if response.status_code >= 400:
            raise AppleMusicError(
                f"Apple Music request failed with status {response.status_code}: {response.text}"
            )

        payload = response.json()
        return _extract_results(payload)


def _extract_results(payload: dict[str, Any]) -> list[AppleMusicResult]:
    results: list[AppleMusicResult] = []
    results_root = payload.get("results", {})
    if not isinstance(results_root, dict):
        return results

    album_data = _result_entries(results_root.get("albums"))
    song_data = _result_entries(results_root.get("songs"))

    for index, item in enumerate(album_data, start=1):
        parsed = _parse_result(item, media_type="album", key=f"album-{index}")
        if parsed:
            results.append(parsed)

    for index, item in enumerate(song_data, start=1):
        parsed = _parse_result(item, media_type="track", key=f"track-{index}")
        if parsed:
            results.append(parsed)

    return results


def _result_entries(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, dict):
        return []
    data = value.get("data")
    if not isinstance(data, list):
        return []
    entries: list[dict[str, Any]] = []
    for item in data:
        if isinstance(item, dict):
            entries.append(item)
    return entries


def _parse_result(
    item: dict[str, Any], *, media_type: str, key: str
) -> AppleMusicResult | None:
    attributes = item.get("attributes")
    apple_music_id = item.get("id")
    if not isinstance(attributes, dict) or not isinstance(apple_music_id, str):
        return None

    title = attributes.get("name")
    artist = attributes.get("artistName")
    if not isinstance(title, str) or not isinstance(artist, str):
        return None

    artwork_url = None
    artwork = attributes.get("artwork")
    if isinstance(artwork, dict):
        template = artwork.get("url")
        if isinstance(template, str):
            artwork_url = template.replace("{w}", "600").replace("{h}", "600")

    canonical_url = attributes.get("url")
    if not isinstance(canonical_url, str):
        canonical_url = None

    return AppleMusicResult(
        key=key,
        media_type=media_type,
        apple_music_id=apple_music_id,
        title=title,
        artist=artist,
        artwork_url=artwork_url,
        url=canonical_url,
    )


class MockAppleMusicClient:
    async def search_catalog(
        self, query: str, limit: int = 5
    ) -> list[AppleMusicResult]:
        normalized = query.strip() or "music"
        base = normalized.replace(" ", "-").lower()[:24]
        return [
            AppleMusicResult(
                key="album-1",
                media_type="album",
                apple_music_id="310730204",
                title=f"{normalized.title()} Essentials",
                artist="Various Artists",
                artwork_url="https://is1-ssl.mzstatic.com/image/thumb/Music/v4/sample/600x600bb.jpg",
                url=f"https://music.apple.com/us/album/{base}/310730204",
            ),
            AppleMusicResult(
                key="track-1",
                media_type="track",
                apple_music_id="1440833083",
                title="Teardrop",
                artist="Massive Attack",
                artwork_url="https://is1-ssl.mzstatic.com/image/thumb/Music/v4/sample/600x600bb.jpg",
                url="https://music.apple.com/us/album/teardrop/1440833083?i=1440833095",
            ),
        ][:limit]
