from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

import yaml
from jsonschema import Draft202012Validator

from story_writer.models import ValidationPayload


SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": [
        "schema_version",
        "id",
        "title",
        "authors",
        "publish_date",
        "sections",
        "media",
    ],
    "properties": {
        "schema_version": {"type": ["number", "string"]},
        "id": {"type": "string", "minLength": 1},
        "title": {"type": "string", "minLength": 1},
        "authors": {
            "type": "array",
            "items": {"type": "string", "minLength": 1},
            "minItems": 1,
        },
        "publish_date": {"type": "string", "pattern": "^\\d{4}-\\d{2}-\\d{2}$"},
        "sections": {
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "required": ["id", "title"],
                "properties": {
                    "id": {"type": "string", "minLength": 1},
                    "title": {"type": "string", "minLength": 1},
                    "layout": {"type": "string"},
                    "lead_media": {"type": "string"},
                },
                "additionalProperties": True,
            },
        },
        "media": {
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "required": ["key", "type", "apple_music_id", "title", "artist"],
                "properties": {
                    "key": {"type": "string", "minLength": 1},
                    "type": {
                        "type": "string",
                        "enum": ["track", "album", "playlist", "music-video"],
                    },
                    "apple_music_id": {"type": "string", "minLength": 1},
                    "title": {"type": "string", "minLength": 1},
                    "artist": {"type": "string", "minLength": 1},
                },
                "additionalProperties": True,
            },
        },
    },
    "additionalProperties": True,
}


SECTION_RE = re.compile(r"<Section\s+([^>]+)>(.*?)</Section>", re.DOTALL)
MEDIA_REF_RE = re.compile(r"<MediaRef\s+([^/>]+?)\s*/>", re.DOTALL)
ATTR_RE = re.compile(r"(\w+)=(?:\"([^\"]*)\"|'([^']*)')")


@dataclass(frozen=True)
class ParsedStory:
    front_matter: dict[str, Any]
    body: str


def validate_story_document(story_mdx: str) -> ValidationPayload:
    diagnostics: list[str] = []
    parsed = _parse_front_matter(story_mdx)
    if not parsed:
        return ValidationPayload(
            schema_valid=False,
            parser_compatible=False,
            diagnostics=["Missing or invalid front matter block."],
        )

    schema_errors = _validate_schema(parsed.front_matter)
    diagnostics.extend(schema_errors)

    parser_errors = _validate_parser_compatibility(parsed.front_matter, parsed.body)
    diagnostics.extend(parser_errors)

    return ValidationPayload(
        schema_valid=len(schema_errors) == 0,
        parser_compatible=len(parser_errors) == 0,
        diagnostics=diagnostics,
    )


def _parse_front_matter(text: str) -> ParsedStory | None:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    end_index = None
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            end_index = index
            break
    if end_index is None:
        return None

    front_text = "\n".join(lines[1:end_index])
    body = "\n".join(lines[end_index + 1 :]).strip()

    try:
        front_data = yaml.safe_load(front_text) or {}
    except yaml.YAMLError:
        return None
    if not isinstance(front_data, dict):
        return None
    return ParsedStory(front_matter=front_data, body=body)


def _validate_schema(front_matter: dict[str, Any]) -> list[str]:
    diagnostics: list[str] = []
    validator = Draft202012Validator(SCHEMA)
    for error in sorted(validator.iter_errors(front_matter), key=lambda err: err.path):
        path = "/".join(str(part) for part in error.path)
        location = f"{path}: " if path else ""
        diagnostics.append(f"{location}{error.message}")

    section_ids = [
        item.get("id")
        for item in front_matter.get("sections", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    ]
    duplicate_sections = sorted(
        {value for value in section_ids if section_ids.count(value) > 1}
    )
    if duplicate_sections:
        diagnostics.append(f"Duplicate section ids found: {duplicate_sections}")

    media_keys = [
        item.get("key")
        for item in front_matter.get("media", [])
        if isinstance(item, dict) and isinstance(item.get("key"), str)
    ]
    duplicate_media = sorted(
        {value for value in media_keys if media_keys.count(value) > 1}
    )
    if duplicate_media:
        diagnostics.append(f"Duplicate media keys found: {duplicate_media}")

    media_lookup = set(media_keys)
    for section in front_matter.get("sections", []):
        if not isinstance(section, dict):
            continue
        lead_media = section.get("lead_media")
        if (
            isinstance(lead_media, str)
            and lead_media
            and lead_media not in media_lookup
        ):
            diagnostics.append(
                f"Section '{section.get('id')}' references missing lead_media '{lead_media}'."
            )
    return diagnostics


def _validate_parser_compatibility(
    front_matter: dict[str, Any], body: str
) -> list[str]:
    diagnostics: list[str] = []
    section_matches = list(SECTION_RE.finditer(body))
    if not section_matches:
        return ["No <Section> blocks found in story body."]

    stripped_body = SECTION_RE.sub("", body).strip()
    if stripped_body:
        diagnostics.append("Story body contains text outside <Section> blocks.")

    section_ids_in_body: set[str] = set()
    for match in section_matches:
        attrs = _parse_attrs(match.group(1))
        section_id = attrs.get("id")
        if not section_id:
            diagnostics.append("Each <Section> requires an id attribute.")
            continue
        section_ids_in_body.add(section_id)

        media_lookup = {
            item.get("key")
            for item in front_matter.get("media", [])
            if isinstance(item, dict) and isinstance(item.get("key"), str)
        }
        for media_match in MEDIA_REF_RE.finditer(match.group(2)):
            media_attrs = _parse_attrs(media_match.group(1))
            ref = media_attrs.get("ref")
            if ref and ref not in media_lookup:
                diagnostics.append(
                    f"Section '{section_id}' references missing media key '{ref}'."
                )

    front_section_ids = {
        item.get("id")
        for item in front_matter.get("sections", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    missing_sections = sorted(front_section_ids - section_ids_in_body)
    if missing_sections:
        diagnostics.append(
            "Front matter includes sections not present in body: "
            + ", ".join(missing_sections)
        )

    return diagnostics


def _parse_attrs(raw_attrs: str) -> dict[str, str]:
    attrs: dict[str, str] = {}
    for key, value_a, value_b in ATTR_RE.findall(raw_attrs):
        attrs[key] = value_a or value_b
    return attrs
