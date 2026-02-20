from __future__ import annotations

from dataclasses import dataclass

from story_writer.models import InlineReference, SourceNote


@dataclass(frozen=True)
class SourceRecord:
    source_id: str
    label: str
    url: str
    source_type: str


class SourceTracker:
    def __init__(self) -> None:
        self._records: dict[str, SourceRecord] = {}
        self._next_id = 1

    def add(self, *, label: str, url: str, source_type: str) -> str:
        key = url.strip().lower()
        existing = self._records.get(key)
        if existing:
            return existing.source_id

        source_id = f"src-{self._next_id}"
        self._next_id += 1
        record = SourceRecord(
            source_id=source_id, label=label, url=url, source_type=source_type
        )
        self._records[key] = record
        return source_id

    def end_notes(self) -> list[SourceNote]:
        return [
            SourceNote(
                source_id=record.source_id,
                label=record.label,
                url=record.url,
                source_type=record.source_type,
            )
            for record in self._records.values()
        ]


def maybe_inline_reference(
    section_id: str, source_ids: list[str], confidence: float
) -> InlineReference | None:
    if confidence < 0.75 or not source_ids:
        return None
    return InlineReference(section_id=section_id, source_ids=source_ids)
