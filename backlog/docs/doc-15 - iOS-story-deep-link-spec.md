---
id: doc-15
title: 'Technical Spec: iOS story deep links and shareable story codes'
type: spec
created_date: '2026-02-23 00:00'
---

## Summary
- Add a custom iOS URL scheme that can open a specific story from the launch catalog.
- Generate deterministic, compact story codes so links stay stable for the same story source.
- Expose a long-press action on story cards to copy that story's deep link.

## URL format
- Canonical format: `apple-music-stories://story/<code>`
- Supported fallback format: `apple-music-stories:/story/<code>`
- `<code>` is a versioned story code (current version: `S1-...`).

## Story code design
- Codes are deterministic from a canonical identity: source type + story id + source locator.
- Source locator strategy:
  - Bundled stories: path relative to bundled `stories/` root (stable across app sandbox paths).
  - Saved remote stories: full source URL.
  - Recent local stories: standardized local path.
- Hashing: 64-bit FNV-1a of the canonical identity.
- Encoding: Crockford-style Base32 alphabet (`0-9 A-Z` without ambiguous letters) padded to 13 chars.
- Final code shape: `S1-<source-prefix><base32-hash>` where source prefix is one of `B`, `R`, `L`.

## Resolution behavior
- App listens for incoming URLs via `onOpenURL`.
- If the URL matches the story route and code format, the app resolves the code against `availableStories`.
- On a match, the store loads and opens that story.
- On a miss, the app keeps current state unchanged and logs a diagnostic event.

## Long-press action
- Story cards in the launch catalog include `Copy Story Link` in the context menu.
- Action copies the canonical deep link URL to the system pasteboard.

## Validation plan
- Unit tests verify:
  - Code generation round-trips through canonical and single-slash URL formats.
  - Different source types produce different codes.
  - Store lookup by deep-link code returns the matching available story.
  - Invalid codes are rejected.
