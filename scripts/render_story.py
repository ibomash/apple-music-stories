#!/usr/bin/env python3
# /// script
# requires-python = ">=3.13"
# dependencies = [
#   "markdown>=3.7",
#   "PyYAML>=6.0",
#   "jsonschema>=4.22",
# ]
# ///
from __future__ import annotations

import argparse
import html
import http.server
import importlib.util
import json
import mimetypes
import os
import pathlib
import re
import shutil
import ssl
import sys
import urllib.parse
from dataclasses import dataclass
from typing import Any, Iterable

import markdown
import yaml

FRONT_MATTER_DELIMITER = "---"
SECTION_RE = re.compile(r"<Section\s+([^>]+)>(.*?)</Section>", re.DOTALL)
MEDIA_REF_RE = re.compile(r"<MediaRef\s+([^/>]+?)\s*/>", re.DOTALL)
ATTR_RE = re.compile(r"(\w+)=\"([^\"]*)\"")
DEFAULT_STORY_DIRS = ("stories", "examples")

BASE_CSS = """
:root {
  color-scheme: light dark;
  font-synthesis: none;
  text-rendering: optimizeLegibility;
  --accent: #d64550;
  --ink: #111111;
  --muted: #6f6f6f;
  --surface: #f7f4f0;
}
* {
  box-sizing: border-box;
}
body {
  margin: 0;
  font-family: "Iowan Old Style", "Palatino", "Georgia", serif;
  color: var(--ink);
  background: #fcfbf9;
}
.hero {
  padding: 72px 96px 48px;
  background: linear-gradient(120deg, #101010 0%, #1c1c1c 100%);
  color: #ffffff;
}
.hero-image {
  margin-top: 32px;
  border-radius: 28px;
  overflow: hidden;
  box-shadow: 0 40px 120px rgba(0, 0, 0, 0.45);
}
.hero-image img {
  display: block;
  width: 100%;
  height: auto;
}
.hero-credit {
  font-size: 0.85rem;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 8px;
}
.container {
  max-width: 1100px;
  margin: 0 auto;
  padding: 56px 32px 96px;
}
.meta {
  text-transform: uppercase;
  letter-spacing: 0.18em;
  font-size: 0.8rem;
  color: rgba(255, 255, 255, 0.75);
}
.title {
  font-size: clamp(2.6rem, 4vw, 4.2rem);
  margin: 16px 0 8px;
}
.subtitle {
  font-size: 1.3rem;
  max-width: 700px;
  line-height: 1.5;
  color: rgba(255, 255, 255, 0.85);
}
.section {
  margin-bottom: 64px;
}
.section-header {
  font-size: 1.8rem;
  margin-bottom: 20px;
}
.section.lede .section-header {
  font-size: 2.2rem;
}
.section-body {
  font-size: 1.1rem;
  line-height: 1.8;
}
.section-body p {
  margin: 0 0 24px;
}
.media-card {
  display: grid;
  grid-template-columns: 120px 1fr;
  gap: 20px;
  padding: 20px;
  border-radius: 20px;
  background: var(--surface);
  margin: 24px 0;
  align-items: center;
}
.media-card img {
  width: 120px;
  height: 120px;
  border-radius: 16px;
  object-fit: cover;
  background: #e5e0da;
}
.media-meta {
  font-family: "SF Pro Display", "Inter", "Helvetica Neue", sans-serif;
}
.media-title {
  font-weight: 700;
  font-size: 1.1rem;
}
.media-artist {
  color: var(--muted);
}
.media-link {
  display: inline-block;
  margin-top: 12px;
  color: var(--accent);
  text-decoration: none;
  font-weight: 600;
}
.media-controls {
  margin-top: 12px;
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
}
.media-play {
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 999px;
  padding: 8px 16px;
  background: #111111;
  color: #ffffff;
  font-weight: 600;
  cursor: pointer;
}
.media-play:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.playback-bar {
  position: sticky;
  bottom: 0;
  width: 100%;
  backdrop-filter: blur(16px);
  background: rgba(20, 20, 20, 0.92);
  color: #ffffff;
  padding: 16px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  font-family: "SF Pro Display", "Inter", "Helvetica Neue", sans-serif;
}
.playback-main {
  display: flex;
  align-items: center;
  gap: 16px;
  flex: 1;
  min-width: 0;
}
.playback-artwork {
  width: 52px;
  height: 52px;
  border-radius: 12px;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.1);
  flex-shrink: 0;
}
.playback-artwork img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
.playback-meta {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}
.playback-title {
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.playback-artist {
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.9rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.playback-progress {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
  max-width: 420px;
}
.playback-time {
  font-size: 0.85rem;
  color: rgba(255, 255, 255, 0.75);
  min-width: 70px;
  text-align: right;
}
.playback-range {
  flex: 1;
  accent-color: #ffffff;
}
.playback-controls {
  display: flex;
  gap: 8px;
}
.playback-button {
  border: none;
  border-radius: 999px;
  padding: 8px 16px;
  background: #ffffff;
  color: #111111;
  font-weight: 600;
  cursor: pointer;
}
.playback-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.auth-banner {
  margin: -24px auto 0;
  padding: 16px 24px;
  max-width: 960px;
  background: rgba(255, 255, 255, 0.12);
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}
.auth-status {
  font-family: "SF Pro Display", "Inter", "Helvetica Neue", sans-serif;
  font-size: 0.95rem;
  letter-spacing: 0.02em;
}
.auth-button {
  border: none;
  border-radius: 999px;
  padding: 10px 18px;
  background: #ffffff;
  color: #111111;
  font-weight: 600;
  cursor: pointer;
}
.auth-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
@media (max-width: 720px) {
  .hero {
    padding: 48px 28px 36px;
  }
  .container {
    padding: 40px 24px 72px;
  }
  .media-card {
    grid-template-columns: 1fr;
    text-align: center;
  }
  .media-card img {
    margin: 0 auto;
  }
  .auth-banner {
    flex-direction: column;
    text-align: center;
  }
  .playback-bar {
    flex-direction: column;
    align-items: stretch;
  }
  .playback-controls {
    justify-content: center;
  }
}
"""

INDEX_CSS = """
body {
  margin: 0;
  font-family: "Iowan Old Style", "Palatino", "Georgia", serif;
  background: #0f0f10;
  color: #f5f3ef;
}
.index-hero {
  padding: 72px 96px 32px;
}
.index-title {
  font-size: clamp(2.6rem, 4vw, 4rem);
  margin: 0 0 12px;
}
.index-subtitle {
  max-width: 640px;
  line-height: 1.6;
  color: rgba(245, 243, 239, 0.7);
}
.story-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 24px;
  padding: 24px 96px 80px;
}
.story-card {
  background: #1c1c20;
  border-radius: 20px;
  overflow: hidden;
  text-decoration: none;
  color: inherit;
  display: flex;
  flex-direction: column;
  min-height: 320px;
}
.story-card img {
  width: 100%;
  height: 200px;
  object-fit: cover;
}
.story-card-placeholder {
  width: 100%;
  height: 200px;
  background: linear-gradient(120deg, #26262d, #3a2c2f);
}
.story-card-body {
  padding: 20px;
}
.story-card-title {
  font-size: 1.3rem;
  margin-bottom: 8px;
}
.story-card-subtitle {
  color: rgba(245, 243, 239, 0.7);
  margin-bottom: 12px;
}
.story-card-meta {
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: rgba(245, 243, 239, 0.55);
}
@media (max-width: 720px) {
  .index-hero {
    padding: 48px 28px 24px;
  }
  .story-grid {
    padding: 16px 24px 56px;
  }
}
"""


@dataclass(frozen=True)
class StorySection:
    id: str
    title: str
    layout: str | None
    body: str


@dataclass(frozen=True)
class StoryMedia:
    key: str
    type: str
    apple_music_id: str
    title: str
    artist: str
    artwork_url: str | None
    apple_music_url: str | None


@dataclass(frozen=True)
class Story:
    meta: dict[str, Any]
    sections: list[StorySection]
    media: dict[str, StoryMedia]


@dataclass(frozen=True)
class StoryIndexEntry:
    id: str
    title: str
    subtitle: str | None
    authors: list[str]
    hero_src: str | None
    tags: list[str]
    path: pathlib.Path


class StoryParseError(RuntimeError):
    pass


def load_story_text(path: pathlib.Path) -> tuple[dict[str, Any], str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0].strip() != FRONT_MATTER_DELIMITER:
        raise StoryParseError("Missing front matter header '---' at top of file.")

    end_index = None
    for index in range(1, len(lines)):
        if lines[index].strip() == FRONT_MATTER_DELIMITER:
            end_index = index
            break

    if end_index is None:
        raise StoryParseError("Missing closing front matter '---'.")

    front_matter_text = "\n".join(lines[1:end_index])
    body = "\n".join(lines[end_index + 1 :])
    data = yaml.safe_load(front_matter_text) or {}
    if not isinstance(data, dict):
        raise StoryParseError("Front matter must parse to a mapping/object.")
    return data, body


def parse_attrs(raw: str) -> dict[str, str]:
    return {key: value for key, value in ATTR_RE.findall(raw)}


def is_absolute_url(url: str) -> bool:
    if not url:
        return False
    parsed = urllib.parse.urlparse(url)
    return bool(parsed.scheme) or url.startswith("/") or url.startswith("#")


def resolve_asset_url(url: str | None, asset_prefix: str | None) -> str | None:
    if not url or not asset_prefix or is_absolute_url(url):
        return url
    cleaned = url.lstrip("./")
    if cleaned.startswith("assets/"):
        cleaned = cleaned[len("assets/") :]
    return f"{asset_prefix.rstrip('/')}/{cleaned}"


def rewrite_asset_urls(html_content: str, asset_prefix: str | None) -> str:
    if not asset_prefix:
        return html_content

    def replace_attr(match: re.Match[str]) -> str:
        attr = match.group(1)
        value = match.group(2)
        resolved = resolve_asset_url(value, asset_prefix)
        if resolved == value or resolved is None:
            return match.group(0)
        return f'{attr}="{resolved}"'

    return re.sub(r'(src|href)="([^"]+)"', replace_attr, html_content)


def build_media_lookup(raw_media: list[dict[str, Any]]) -> dict[str, StoryMedia]:
    lookup: dict[str, StoryMedia] = {}
    for item in raw_media:
        if not isinstance(item, dict):
            continue
        key = str(item.get("key", "")).strip()
        if not key:
            continue
        lookup[key] = StoryMedia(
            key=key,
            type=str(item.get("type", "")),
            apple_music_id=str(item.get("apple_music_id", "")),
            title=str(item.get("title", "")),
            artist=str(item.get("artist", "")),
            artwork_url=item.get("artwork_url"),
            apple_music_url=item.get("apple_music_url"),
        )
    return lookup


def render_media_card(
    ref: str, media: StoryMedia | None, asset_prefix: str | None = None
) -> str:
    if media is None:
        return (
            '<div class="media-card missing">'
            f'<div class="media-meta">Missing media reference: {html.escape(ref)}</div>'
            "</div>"
        )

    artwork_url = resolve_asset_url(media.artwork_url, asset_prefix)
    artwork_html = (
        f'<img src="{html.escape(artwork_url)}" alt="{html.escape(media.title)} artwork">'
        if artwork_url
        else '<img src="" alt="" style="opacity:0;">'
    )
    apple_link = build_apple_music_link(media)
    return (
        '<div class="media-card" data-media-key="{key}" data-media-type="{type}" '
        'data-apple-music-id="{id}">'
        "{artwork}"
        '<div class="media-meta">'
        '<div class="media-title">{title}</div>'
        '<div class="media-artist">{artist}</div>'
        '<div class="media-controls">'
        '<button class="media-play" data-action="play">Play</button>'
        '<a class="media-link" href="{link}" target="_blank" rel="noopener">'
        "Open in Apple Music"
        "</a>"
        "</div>"
        "</div>"
        "</div>"
    ).format(
        key=html.escape(media.key),
        type=html.escape(media.type),
        id=html.escape(media.apple_music_id),
        artwork=artwork_html,
        title=html.escape(media.title),
        artist=html.escape(media.artist),
        link=html.escape(apple_link),
    )


def build_apple_music_link(media: StoryMedia) -> str:
    if media.apple_music_url:
        return media.apple_music_url
    region = "us"
    type_map = {
        "track": "song",
        "album": "album",
        "playlist": "playlist",
        "music-video": "music-video",
    }
    kind = type_map.get(media.type, media.type)
    return f"https://music.apple.com/{region}/{kind}/{media.apple_music_id}"


def render_section_body(
    raw_body: str, media_lookup: dict[str, StoryMedia], asset_prefix: str | None = None
) -> str:
    parts: list[str] = []
    cursor = 0
    for match in MEDIA_REF_RE.finditer(raw_body):
        text = raw_body[cursor : match.start()].strip()
        if text:
            rendered = markdown.markdown(text, extensions=["extra"])
            parts.append(rewrite_asset_urls(rendered, asset_prefix))
        attrs = parse_attrs(match.group(1))
        ref = attrs.get("ref", "")
        parts.append(render_media_card(ref, media_lookup.get(ref), asset_prefix))
        cursor = match.end()

    tail = raw_body[cursor:].strip()
    if tail:
        rendered = markdown.markdown(tail, extensions=["extra"])
        parts.append(rewrite_asset_urls(rendered, asset_prefix))
    return "\n".join(parts)


def parse_sections(
    body: str, section_meta: dict[str, dict[str, Any]]
) -> list[StorySection]:
    sections: list[StorySection] = []
    for match in SECTION_RE.finditer(body):
        attrs = parse_attrs(match.group(1))
        content = match.group(2).strip()
        section_id = attrs.get("id") or ""
        meta = section_meta.get(section_id, {})
        title = attrs.get("title") or meta.get("title") or ""
        layout = attrs.get("layout") or meta.get("layout")
        sections.append(
            StorySection(id=section_id, title=title, layout=layout, body=content)
        )
    if not sections:
        raise StoryParseError("No <Section> blocks found in story body.")
    return sections


def validate_story_meta(meta: dict[str, Any]) -> list[str]:
    validator_path = pathlib.Path(__file__).with_name("validate_story.py")
    if not validator_path.exists():
        return []
    spec = importlib.util.spec_from_file_location("validate_story", validator_path)
    if spec is None or spec.loader is None:
        return []
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    validate = getattr(module, "validate_story", None)
    if callable(validate):
        result = validate(meta)
        if isinstance(result, Iterable):
            return list(result)
        return []
    return []


def build_story(path: pathlib.Path) -> Story:
    meta, body = load_story_text(path)
    errors = validate_story_meta(meta)
    if errors:
        raise StoryParseError("Schema validation failed: " + "; ".join(errors))
    section_meta = {
        str(item.get("id")): item
        for item in meta.get("sections", [])
        if isinstance(item, dict) and item.get("id")
    }
    sections = parse_sections(body, section_meta)
    media_lookup = build_media_lookup(meta.get("media", []))
    return Story(meta=meta, sections=sections, media=media_lookup)


def discover_story_paths(paths: Iterable[str | pathlib.Path]) -> list[pathlib.Path]:
    discovered: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()
    for root in paths:
        base = pathlib.Path(root)
        if not base.exists():
            continue
        if base.is_file() and base.name == "story.mdx":
            candidate = base.resolve()
            if candidate not in seen:
                seen.add(candidate)
                discovered.append(candidate)
            continue
        if base.is_dir():
            for candidate in base.rglob("story.mdx"):
                resolved = candidate.resolve()
                if resolved not in seen:
                    seen.add(resolved)
                    discovered.append(resolved)
    return discovered


def build_story_index(
    paths: Iterable[str | pathlib.Path],
) -> dict[str, StoryIndexEntry]:
    entries: dict[str, StoryIndexEntry] = {}
    for story_path in discover_story_paths(paths):
        try:
            meta, _ = load_story_text(story_path)
        except (OSError, StoryParseError):
            continue
        story_id = str(meta.get("id") or story_path.parent.name).strip()
        if not story_id or story_id in entries:
            continue
        hero = meta.get("hero_image") or {}
        entries[story_id] = StoryIndexEntry(
            id=story_id,
            title=str(meta.get("title", story_id)),
            subtitle=meta.get("subtitle"),
            authors=list(meta.get("authors", [])),
            hero_src=hero.get("src"),
            tags=list(meta.get("tags", [])),
            path=story_path,
        )
    return entries


def render_index_html(entries: dict[str, StoryIndexEntry]) -> str:
    cards: list[str] = []
    for entry in sorted(entries.values(), key=lambda item: item.title.lower()):
        hero_src = resolve_asset_url(entry.hero_src, f"/assets/{entry.id}")
        if hero_src:
            hero_html = (
                f'<img src="{html.escape(hero_src)}" alt="{html.escape(entry.title)}">'
            )
        else:
            hero_html = '<div class="story-card-placeholder"></div>'
        subtitle_html = (
            f'<div class="story-card-subtitle">{html.escape(str(entry.subtitle))}</div>'
            if entry.subtitle
            else ""
        )
        meta_parts = []
        if entry.authors:
            meta_parts.append(
                ", ".join(html.escape(author) for author in entry.authors)
            )
        if entry.tags:
            meta_parts.append(", ".join(html.escape(tag) for tag in entry.tags[:3]))
        meta_html = (
            f'<div class="story-card-meta">{" · ".join(meta_parts)}</div>'
            if meta_parts
            else ""
        )
        cards.append(
            '<a class="story-card" href="/stories/{id}">'
            "{hero}"
            '<div class="story-card-body">'
            '<div class="story-card-title">{title}</div>'
            "{subtitle}"
            "{meta}"
            "</div>"
            "</a>".format(
                id=html.escape(entry.id),
                hero=hero_html,
                title=html.escape(entry.title),
                subtitle=subtitle_html,
                meta=meta_html,
            )
        )

    return (
        "<!doctype html>"
        '<html lang="en">'
        "<head>"
        '<meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        "<title>Apple Music Stories</title>"
        "<style>"
        f"{INDEX_CSS}"
        "</style>"
        "</head>"
        "<body>"
        '<header class="index-hero">'
        '<div class="index-title">Apple Music Stories</div>'
        '<div class="index-subtitle">'
        "Browse available stories and launch the renderer with MusicKit playback."
        "</div>"
        "</header>"
        '<section class="story-grid">'
        f"{''.join(cards)}"
        "</section>"
        "</body>"
        "</html>"
    )


def render_story_html(
    story: Story, developer_token: str | None = None, asset_prefix: str | None = None
) -> str:
    title = html.escape(str(story.meta.get("title", "Untitled")))
    subtitle = story.meta.get("subtitle")
    authors = ", ".join(story.meta.get("authors", []))
    publish_date = html.escape(str(story.meta.get("publish_date", "")))
    hero = story.meta.get("hero_image") or {}
    hero_src = resolve_asset_url(hero.get("src"), asset_prefix)
    hero_alt = html.escape(str(hero.get("alt", "")))
    hero_credit = hero.get("credit")
    developer_token = developer_token or ""
    has_token = bool(developer_token)

    sections_html: list[str] = []
    for section in story.sections:
        content_html = render_section_body(section.body, story.media, asset_prefix)
        classes = ["section"]
        if section.layout:
            classes.append(section.layout)
        layout_class = " ".join(classes)
        sections_html.append(
            '<section class="{layout}">'
            '<h2 class="section-header">{title}</h2>'
            '<div class="section-body">{body}</div>'
            "</section>".format(
                layout=html.escape(layout_class),
                title=html.escape(section.title or ""),
                body=content_html,
            )
        )

    hero_block = ""
    if hero_src:
        hero_block = (
            '<div class="hero-image">'
            f'<img src="{html.escape(hero_src)}" alt="{hero_alt}">'
            "</div>"
        )
        if hero_credit:
            hero_block += (
                f'<div class="hero-credit">{html.escape(str(hero_credit))}</div>'
            )

    subtitle_html = (
        f'<div class="subtitle">{html.escape(str(subtitle))}</div>' if subtitle else ""
    )

    byline_parts: list[str] = []
    if authors:
        byline_parts.append(f"By {html.escape(authors)}")
    if publish_date:
        byline_parts.append(publish_date)
    byline = " · ".join(byline_parts)
    byline_html = f'<div class="meta">{byline}</div>' if byline else ""

    media_payload = [
        {
            "key": item.key,
            "type": item.type,
            "apple_music_id": item.apple_music_id,
            "title": item.title,
            "artist": item.artist,
            "artwork_url": item.artwork_url,
        }
        for item in story.media.values()
    ]
    media_json = json.dumps(media_payload).replace("</", "<\\/")
    media_json_tag = (
        f'<script type="application/json" id="story-media-data">{media_json}</script>'
    )
    playback_bar = (
        '<div class="playback-bar" data-playback-bar>'
        '<div class="playback-main">'
        '<div class="playback-artwork">'
        '<img data-playback-artwork alt="">'
        "</div>"
        '<div class="playback-meta">'
        '<div class="playback-title" data-playback-title>Nothing playing</div>'
        '<div class="playback-artist" data-playback-artist></div>'
        "</div>"
        "</div>"
        '<div class="playback-progress">'
        '<input class="playback-range" type="range" min="0" max="1" value="0" step="0.1" data-playback-range disabled>'
        '<div class="playback-time" data-playback-time>0:00 / 0:00</div>'
        "</div>"
        '<div class="playback-controls">'
        '<button class="playback-button" data-action="prev" disabled>Prev</button>'
        '<button class="playback-button" data-action="toggle" disabled>Play</button>'
        '<button class="playback-button" data-action="next" disabled>Next</button>'
        "</div>"
        "</div>"
    )

    auth_banner = (
        '<div class="auth-banner" data-auth-banner>'
        '<div class="auth-status" data-auth-status>Initializing playback…</div>'
        '<button class="auth-button" data-action="authorize" disabled>Authorize</button>'
        "</div>"
    )
    token_meta = (
        '<meta name="apple-music-developer-token" content="{token}">'
        '<meta name="apple-music-has-token" content="{has_token}">'
    ).format(token=html.escape(developer_token), has_token=str(has_token).lower())
    script_lines = [
        "<script>",
        "const banner = document.querySelector('[data-auth-banner]');",
        "const statusEl = document.querySelector('[data-auth-status]');",
        "const button = document.querySelector('[data-action=authorize]');",
        "const tokenMeta = document.querySelector('meta[name=apple-music-developer-token]');",
        "const hasTokenMeta = document.querySelector('meta[name=apple-music-has-token]');",
        "const mediaDataEl = document.getElementById('story-media-data');",
        "const mediaItems = mediaDataEl ? JSON.parse(mediaDataEl.textContent) : [];",
        "const playbackTitle = document.querySelector('[data-playback-title]');",
        "const playbackArtist = document.querySelector('[data-playback-artist]');",
        "const playbackArtwork = document.querySelector('[data-playback-artwork]');",
        "const playbackRange = document.querySelector('[data-playback-range]');",
        "const playbackTime = document.querySelector('[data-playback-time]');",
        "const prevButton = document.querySelector('[data-action=prev]');",
        "const nextButton = document.querySelector('[data-action=next]');",
        "const toggleButton = document.querySelector('[data-action=toggle]');",
        "const playButtons = Array.from(document.querySelectorAll('[data-action=play]'));",
        "const typeMap = { track: 'song', album: 'album', playlist: 'playlist', 'music-video': 'musicVideo' };",
        "let currentIndex = -1;",
        "let musicInstance = null;",
        "let progressTimer = null;",
        "const setPlaybackText = (item) => {",
        "  if (!playbackTitle || !playbackArtist) { return; }",
        "  if (!item) { playbackTitle.textContent = 'Nothing playing'; playbackArtist.textContent = ''; return; }",
        "  playbackTitle.textContent = item.title || 'Untitled';",
        "  playbackArtist.textContent = item.artist || '';",
        "};",
        "const setArtwork = (item) => {",
        "  if (!playbackArtwork) { return; }",
        "  if (!item) { playbackArtwork.removeAttribute('src'); return; }",
        "  const artworkFromItem = item.artworkURL ? (typeof item.artworkURL === 'function' ? item.artworkURL(200, 200) : item.artworkURL) : null;",
        "  const artwork = artworkFromItem || item.artwork_url || null;",
        "  if (artwork) { playbackArtwork.src = artwork; } else { playbackArtwork.removeAttribute('src'); }",
        "};",
        "const formatTime = (value) => {",
        "  const total = Math.max(0, Math.floor(value || 0));",
        "  const minutes = Math.floor(total / 60);",
        "  const seconds = total % 60;",
        "  return `${minutes}:${seconds.toString().padStart(2, '0')}`;",
        "};",
        "const updateProgress = (music) => {",
        "  if (!playbackRange || !playbackTime || !music) { return; }",
        "  const duration = music.currentPlaybackDuration || (music.nowPlayingItem ? music.nowPlayingItem.playbackDuration : 0) || 0;",
        "  const current = music.currentPlaybackTime || 0;",
        "  playbackRange.max = duration || 1;",
        "  playbackRange.value = current || 0;",
        "  playbackTime.textContent = `${formatTime(current)} / ${formatTime(duration)}`;",
        "};",
        "const setControlsEnabled = (enabled) => {",
        "  const controls = [prevButton, nextButton, toggleButton, playbackRange, ...playButtons];",
        "  controls.forEach((control) => { if (control) { control.disabled = !enabled; } });",
        "};",
        "const updateNowPlaying = (music) => {",
        "  if (!toggleButton) { return; }",
        "  toggleButton.textContent = music && music.isPlaying ? 'Pause' : 'Play';",
        "  if (!playbackTitle || !playbackArtist) { return; }",
        "  const nowPlaying = music ? music.nowPlayingItem : null;",
        "  if (nowPlaying) {",
        "    playbackTitle.textContent = nowPlaying.title || 'Now Playing';",
        "    playbackArtist.textContent = nowPlaying.artistName || '';",
        "    setArtwork(nowPlaying);",
        "  } else if (currentIndex >= 0 && mediaItems[currentIndex]) {",
        "    setPlaybackText(mediaItems[currentIndex]);",
        "    setArtwork(mediaItems[currentIndex]);",
        "  } else {",
        "    setPlaybackText(null);",
        "    setArtwork(null);",
        "  }",
        "  updateProgress(music);",
        "};",
        "const playItem = async (item, music) => {",
        "  if (!item || !music) { return; }",
        "  const kind = typeMap[item.type];",
        "  if (!kind || !item.apple_music_id) { return; }",
        "  const descriptor = {};",
        "  descriptor[kind] = item.apple_music_id;",
        "  await music.setQueue(descriptor);",
        "  await music.play();",
        "  currentIndex = mediaItems.findIndex((entry) => entry.key === item.key);",
        "  setPlaybackText(item);",
        "  updateNowPlaying(music);",
        "};",
        "const selectIndex = async (index, music) => {",
        "  if (index < 0 || index >= mediaItems.length) { return; }",
        "  await playItem(mediaItems[index], music);",
        "};",
        "const handlePrev = async (music) => {",
        "  if (!mediaItems.length) { return; }",
        "  const nextIndex = currentIndex > 0 ? currentIndex - 1 : mediaItems.length - 1;",
        "  await selectIndex(nextIndex, music);",
        "};",
        "const handleNext = async (music) => {",
        "  if (!mediaItems.length) { return; }",
        "  const nextIndex = currentIndex >= 0 && currentIndex < mediaItems.length - 1 ? currentIndex + 1 : 0;",
        "  await selectIndex(nextIndex, music);",
        "};",
        "const handleToggle = async (music) => {",
        "  if (!music) { return; }",
        "  if (music.isPlaying) {",
        "    await music.pause();",
        "    updateNowPlaying(music);",
        "    return;",
        "  }",
        "  if (music.nowPlayingItem) {",
        "    await music.play();",
        "    updateNowPlaying(music);",
        "    return;",
        "  }",
        "  if (currentIndex >= 0) {",
        "    await selectIndex(currentIndex, music);",
        "  } else if (mediaItems.length) {",
        "    await selectIndex(0, music);",
        "  }",
        "};",
        "const attachCardHandlers = (music) => {",
        "  playButtons.forEach((buttonEl) => {",
        "    buttonEl.addEventListener('click', async () => {",
        "      const card = buttonEl.closest('.media-card');",
        "      if (!card) { return; }",
        "      const key = card.dataset.mediaKey;",
        "      const index = mediaItems.findIndex((entry) => entry.key === key);",
        "      if (index >= 0) { await selectIndex(index, music); }",
        "    });",
        "  });",
        "};",
        "if (banner && statusEl && button && tokenMeta && hasTokenMeta) {",
        "  const hasToken = hasTokenMeta.content === 'true';",
        "  const developerToken = tokenMeta.content;",
        "  const setStatus = (message, enabled) => {",
        "    statusEl.textContent = message;",
        "    button.disabled = !enabled;",
        "  };",
        "  setControlsEnabled(false);",
        "  const timeoutId = window.setTimeout(() => {",
        "    if (!hasToken) { return; }",
        "    console.warn('MusicKit did not finish loading.');",
        "    setStatus('MusicKit JS did not finish loading. Check HTTPS and console.', false);",
        "  }, 4000);",
        "  if (!hasToken) {",
        "    setStatus('Provide a developer token to enable playback.', false);",
        "    setPlaybackText(null);",
        "  }",
        "  const bootstrapMusicKit = () => {",
        "    if (!hasToken) { return false; }",
        "    if (musicInstance) { return true; }",
        "    if (!window.MusicKit || !MusicKit.configure) { return false; }",
        "    musicInstance = MusicKit.configure({",
        "      developerToken: developerToken,",
        "      app: { name: 'Apple Music Stories', build: 'renderer' },",
        "    });",
        "    const updateAuth = () => {",
        "      if (musicInstance.isAuthorized) {",
        "        setStatus('Playback connected.', true);",
        "        button.textContent = 'Sign out';",
        "        setControlsEnabled(true);",
        "        if (!progressTimer) {",
        "          progressTimer = window.setInterval(() => updateProgress(musicInstance), 1000);",
        "        }",
        "      } else {",
        "        setStatus('Connect to enable playback.', true);",
        "        button.textContent = 'Authorize';",
        "        setControlsEnabled(false);",
        "        if (progressTimer) {",
        "          window.clearInterval(progressTimer);",
        "          progressTimer = null;",
        "        }",
        "      }",
        "      updateNowPlaying(musicInstance);",
        "    };",
        "    button.addEventListener('click', async () => {",
        "      try {",
        "        if (musicInstance.isAuthorized) {",
        "          await musicInstance.unauthorize();",
        "        } else {",
        "          await musicInstance.authorize();",
        "        }",
        "      } catch (error) {",
        "        console.error(error);",
        "        setStatus('Authorization failed. Try again.', true);",
        "      }",
        "      updateAuth();",
        "    });",
        "    if (toggleButton) {",
        "      toggleButton.addEventListener('click', async () => { await handleToggle(musicInstance); });",
        "    }",
        "    if (prevButton) {",
        "      prevButton.addEventListener('click', async () => { await handlePrev(musicInstance); });",
        "    }",
        "    if (nextButton) {",
        "      nextButton.addEventListener('click', async () => { await handleNext(musicInstance); });",
        "    }",
        "    attachCardHandlers(musicInstance);",
        "    if (playbackRange) {",
        "      playbackRange.addEventListener('input', () => {",
        "        if (!musicInstance) { return; }",
        "        const value = Number(playbackRange.value);",
        "        if (!Number.isFinite(value)) { return; }",
        "        const seek = musicInstance.seekToTime || (musicInstance.player && musicInstance.player.seekToTime);",
        "        if (seek) { seek.call(musicInstance, value); }",
        "      });",
        "    }",
        "    musicInstance.addEventListener(MusicKit.Events.playbackStateDidChange, () => updateNowPlaying(musicInstance));",
        "    musicInstance.addEventListener(MusicKit.Events.mediaItemDidChange, () => updateNowPlaying(musicInstance));",
        "    updateAuth();",
        "    return true;",
        "  };",
        "  const started = bootstrapMusicKit();",
        "  if (started) {",
        "    window.clearTimeout(timeoutId);",
        "    console.info('MusicKit loaded.');",
        "  }",
        "  document.addEventListener('musickitloaded', () => {",
        "    window.clearTimeout(timeoutId);",
        "    console.info('MusicKit loaded.');",
        "    bootstrapMusicKit();",
        "  });",
        "}",
        "</script>",
    ]
    musickit_script = "\n".join(script_lines)

    return (
        "<!doctype html>"
        '<html lang="en">'
        "<head>"
        '<meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        f"<title>{title}</title>"
        f"{token_meta}"
        '<script src="https://js-cdn.music.apple.com/musickit/v1/musickit.js"></script>'
        "<style>"
        f"{BASE_CSS}"
        "</style>"
        "</head>"
        "<body>"
        '<header class="hero">'
        '<div class="meta">Music Story</div>'
        f'<h1 class="title">{title}</h1>'
        f"{subtitle_html}"
        f"{byline_html}"
        f"{hero_block}"
        f"{auth_banner}"
        "</header>"
        '<main class="container">'
        f"{''.join(sections_html)}"
        "</main>"
        f"{media_json_tag}"
        f"{playback_bar}"
        f"{musickit_script}"
        "</body>"
        "</html>"
    )


def make_story_handler(
    entries: dict[str, StoryIndexEntry], developer_token: str
) -> type[http.server.BaseHTTPRequestHandler]:
    class StoryHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path
            if path in ("", "/", "/index.html"):
                self.send_html(render_index_html(entries))
                return
            if path.startswith("/stories/"):
                story_id = path.split("/", 2)[2]
                entry = entries.get(story_id)
                if entry is None:
                    self.send_not_found("Story not found")
                    return
                try:
                    story = build_story(entry.path)
                    html_text = render_story_html(
                        story,
                        developer_token=developer_token,
                        asset_prefix=f"/assets/{story_id}",
                    )
                except (OSError, StoryParseError) as exc:
                    self.send_server_error(str(exc))
                    return
                self.send_html(html_text)
                return
            if path.startswith("/assets/"):
                parts = path.strip("/").split("/", 2)
                if len(parts) < 3:
                    self.send_not_found("Asset not found")
                    return
                story_id, asset_path = parts[1], parts[2]
                entry = entries.get(story_id)
                if entry is None:
                    self.send_not_found("Asset not found")
                    return
                asset_root = (entry.path.parent / "assets").resolve()
                candidate = (asset_root / asset_path).resolve()
                if asset_root not in candidate.parents and candidate != asset_root:
                    self.send_not_found("Asset not found")
                    return
                if not candidate.exists() or not candidate.is_file():
                    self.send_not_found("Asset not found")
                    return
                self.send_file(candidate)
                return
            self.send_not_found("Not found")

        def send_html(self, html_text: str, status: int = 200) -> None:
            payload = html_text.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def send_file(self, path: pathlib.Path) -> None:
            mime_type, _ = mimetypes.guess_type(str(path))
            payload = path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", mime_type or "application/octet-stream")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def send_not_found(self, message: str) -> None:
            self.send_html(f"<h1>404</h1><p>{html.escape(message)}</p>", status=404)

        def send_server_error(self, message: str) -> None:
            self.send_html(f"<h1>500</h1><p>{html.escape(message)}</p>", status=500)

        def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
            return

    return StoryHandler


def resolve_story_path(path: pathlib.Path) -> pathlib.Path:
    if path.is_dir():
        story_path = path / "story.mdx"
        if story_path.exists():
            return story_path
        raise FileNotFoundError(f"No story.mdx found in {path}.")
    return path


def copy_assets(source: pathlib.Path, destination: pathlib.Path) -> None:
    assets = source.parent / "assets"
    if assets.exists() and assets.is_dir():
        shutil.copytree(assets, destination / "assets", dirs_exist_ok=True)


def parse_render_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render a music story to HTML.")
    parser.add_argument("input", help="Path to story.mdx or story directory")
    parser.add_argument("output", help="Output directory")
    parser.add_argument(
        "--developer-token",
        default=os.environ.get("APPLE_MUSIC_DEVELOPER_TOKEN", ""),
        help="Apple Music developer token",
    )
    return parser.parse_args(argv)


def parse_serve_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve rendered music stories.")
    parser.add_argument(
        "--stories",
        nargs="*",
        default=None,
        help="Story directories or story.mdx paths",
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument(
        "--developer-token",
        default=os.environ.get("APPLE_MUSIC_DEVELOPER_TOKEN", ""),
        help="Apple Music developer token",
    )
    parser.add_argument("--tls-cert", help="Path to TLS certificate (PEM)")
    parser.add_argument("--tls-key", help="Path to TLS private key (PEM)")
    return parser.parse_args(argv)


def run_render(args: argparse.Namespace) -> int:
    try:
        story_path = resolve_story_path(pathlib.Path(args.input))
        story = build_story(story_path)
        output_dir = pathlib.Path(args.output)
        output_dir.mkdir(parents=True, exist_ok=True)
        output_file = output_dir / "index.html"
        output_file.write_text(
            render_story_html(story, developer_token=args.developer_token),
            encoding="utf-8",
        )
        copy_assets(story_path, output_dir)
    except (OSError, StoryParseError) as exc:
        print(f"Error: {exc}")
        return 1

    print(f"Rendered {story_path} -> {output_file}")
    return 0


def run_serve(args: argparse.Namespace) -> int:
    story_paths = args.stories or list(DEFAULT_STORY_DIRS)
    entries = build_story_index(story_paths)
    if not entries:
        print("No stories found to serve.")
        return 1
    handler = make_story_handler(entries, args.developer_token)
    server = http.server.ThreadingHTTPServer((args.host, args.port), handler)
    scheme = "http"
    if args.tls_cert and args.tls_key:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(args.tls_cert, args.tls_key)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        scheme = "https"
    print(f"Serving {len(entries)} stories at {scheme}://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down server.")
    return 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] in {"serve", "render"}:
        command = sys.argv[1]
        argv = sys.argv[2:]
    else:
        command = "render"
        argv = sys.argv[1:]

    if command == "serve":
        return run_serve(parse_serve_args(argv))
    return run_render(parse_render_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
