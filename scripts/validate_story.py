#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import sys

import yaml
from jsonschema import Draft202012Validator

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
        "subtitle": {"type": "string"},
        "authors": {
            "type": "array",
            "items": {"type": "string", "minLength": 1},
            "minItems": 1,
        },
        "editors": {"type": "array", "items": {"type": "string", "minLength": 1}},
        "publish_date": {"type": "string", "pattern": "^\\d{4}-\\d{2}-\\d{2}$"},
        "tags": {"type": "array", "items": {"type": "string", "minLength": 1}},
        "locale": {"type": "string"},
        "hero_image": {
            "type": "object",
            "required": ["src", "alt"],
            "properties": {
                "src": {"type": "string", "minLength": 1},
                "alt": {"type": "string", "minLength": 1},
                "credit": {"type": "string"},
            },
            "additionalProperties": True,
        },
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
                    "artwork_url": {"type": "string"},
                    "duration_ms": {"type": "number", "minimum": 1},
                },
                "additionalProperties": True,
            },
        },
    },
    "additionalProperties": True,
}


def load_front_matter(path: pathlib.Path) -> dict:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("Missing front matter header '---' at top of file.")

    end_index = None
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            end_index = index
            break

    if end_index is None:
        raise ValueError("Missing closing front matter '---'.")

    front_matter_text = "\n".join(lines[1:end_index])
    data = yaml.safe_load(front_matter_text) or {}
    if not isinstance(data, dict):
        raise ValueError("Front matter must parse to a mapping/object.")
    return data


def validate_story(data: dict) -> list[str]:
    errors: list[str] = []
    validator = Draft202012Validator(SCHEMA)
    for error in sorted(validator.iter_errors(data), key=lambda err: err.path):
        path = "/".join(str(item) for item in error.path)
        location = f"{path}: " if path else ""
        errors.append(f"{location}{error.message}")

    media = [item for item in data.get("media", []) if isinstance(item, dict)]
    media_keys = [
        key for key in (item.get("key") for item in media) if isinstance(key, str)
    ]
    duplicates = sorted({key for key in media_keys if media_keys.count(key) > 1})
    if duplicates:
        errors.append(f"Duplicate media keys found: {duplicates}")

    sections = [item for item in data.get("sections", []) if isinstance(item, dict)]
    section_ids = [
        key for key in (item.get("id") for item in sections) if isinstance(key, str)
    ]
    duplicates = sorted({key for key in section_ids if section_ids.count(key) > 1})
    if duplicates:
        errors.append(f"Duplicate section ids found: {duplicates}")

    media_lookup = set(media_keys)
    for section in sections:
        lead_media = section.get("lead_media")
        if lead_media and lead_media not in media_lookup:
            errors.append(
                f"Section '{section.get('id')}' references missing lead_media '{lead_media}'."
            )

    return errors


def resolve_story_path(path: pathlib.Path) -> pathlib.Path:
    if path.is_dir():
        story_path = path / "story.mdx"
        if story_path.exists():
            return story_path
        raise FileNotFoundError(f"No story.mdx found in {path}.")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a music story MDX file.")
    parser.add_argument("path", help="Path to story.mdx or its directory")
    args = parser.parse_args()

    try:
        story_path = resolve_story_path(pathlib.Path(args.path))
        data = load_front_matter(story_path)
    except (OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    errors = validate_story(data)
    if errors:
        print("Validation errors:", file=sys.stderr)
        for item in errors:
            print(f"- {item}", file=sys.stderr)
        return 1

    print(f"OK: {story_path} passes schema validation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
