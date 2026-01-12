---
id: doc-2
title: Story renderer fallback tests
type: spec
created_date: '2026-01-12 16:58'
---

## Purpose
Define the minimum fallback behavior each story renderer must support when optional fields are missing from a story document.

## Scope
- Applies to any renderer (web, iOS, native, experimental) that consumes the MDX story format.
- Focuses on UI fallbacks and graceful degradation, not validation logic.

## Required Test Cases
- **Missing subtitle**: Renderer hides dek block and collapses spacing between title and body.
- **Missing hero image**: Renderer uses a neutral fallback (gradient, color, or brand art) and omits image credit.
- **Missing editors**: Renderer omits editor byline section without leaving blank labels.
- **Missing tags**: Renderer omits tag pills/list without leaving extra spacing.
- **Missing locale**: Renderer defaults to app or system locale for date formatting and UI strings.
- **Missing section layout**: Renderer treats section as `body` layout.
- **Missing section lead_media**: Renderer omits section hero player without placeholder gap.
- **Missing media artwork_url**: Renderer shows generic artwork placeholder but still shows title/artist.
- **Missing media duration_ms**: Renderer hides duration metadata and uses metadata-only layout.
- **Missing media entry for MediaRef**: Renderer shows a non-blocking inline warning or omits the player, but keeps narrative text.

## Optional Test Cases
- **Missing editors + tags**: Renderer keeps byline block compact without empty lines.
- **Missing hero image + subtitle**: Renderer uses fallback hero styling and maintains readable title spacing.
- **Missing lead_media + missing artwork**: Renderer skips hero player and does not render secondary media chrome.

## Reporting
- Each renderer reports outcomes per test case with screenshot or UI snapshot.
- Record failures as actionable tickets with the failing story sample and expected behavior.
