from __future__ import annotations

from story_writer.validation import validate_story_document


VALID_STORY = """---
schema_version: "0.1"
id: test-story
title: Test Story
authors:
  - Music Story Writer
publish_date: "2026-02-20"
sections:
  - id: intro
    title: Intro
media:
  - key: album-main
    type: album
    apple_music_id: "12345"
    title: Dummy Album
    artist: Dummy Artist
---

<Section id=\"intro\" title=\"Intro\">
Paragraph about the album.
<MediaRef ref=\"album-main\" />
</Section>
"""


def test_validate_story_document_accepts_valid_story() -> None:
    result = validate_story_document(VALID_STORY)

    assert result.schema_valid is True
    assert result.parser_compatible is True
    assert result.diagnostics == []
