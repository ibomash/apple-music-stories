---
id: TASK-133
title: 'iOS: Add Last.fm scrobbling support'
status: Done
assignee: []
created_date: '2026-01-26 23:29'
updated_date: '2026-01-28 20:57'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add Last.fm auth, scrobbling, and visibility tooling to the iOS app.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Settings entry is reachable from the front page and includes Last.fm sign-in/out with clear state.
- [x] #2 Tracks scrobble once per playback completion; duplicates are prevented across app restarts.
- [x] #3 Scrobble activity is visible via console logs and an in-app scrobble log.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Review the iOS design guideline doc `backlog/docs/docs/design/doc-4 - iOS-story-renderer-design-principles.md` and current front page layout; define where a Settings entry lives and how it fits the narrative flow.
- Design the Last.fm Settings screen using the repo design process: user goal mapping, rough layout sketch, component inventory, visual pass, and accessibility pass (Dynamic Type, Reduce Transparency). Include signed-out, signing-in, signed-in, and error states.
- Secrets approach (simple text): add `Config/Secrets.xcconfig` with `LASTFM_API_KEY` and `LASTFM_API_SECRET`, add it to Xcode build configurations (Base Configuration), and add `Config/Secrets.xcconfig` to `.gitignore`. Commit `Config/Secrets.xcconfig.example` with placeholder values and document local setup. Add `Info.plist` keys like `LastfmApiKey`/`LastfmApiSecret` set to `$(LASTFM_API_KEY)` and `$(LASTFM_API_SECRET)` and read them via `Bundle.main.object(forInfoDictionaryKey:)`.
- Obtain Last.fm API key/secret by registering an app. Treat the secret as public and document rotation/abuse risk.
- Decide and document auth flow (web auth, iOS-friendly):
  - Request token: `auth.getToken` with `api_key` (no session key required). Persist token briefly.
  - Launch sign-in: open `https://www.last.fm/api/auth/?api_key=...&token=...&cb=<callback>` via `ASWebAuthenticationSession` (or `SFSafariViewController` fallback) with a custom URL scheme callback.
  - Handle callback: on success, exchange token for session via `auth.getSession` (signed request) and store `sk` in Keychain; on cancel/deny, show error state and allow retry.
  - Auth state model: `signedOut` → `authorizing` → `exchanging` → `signedIn` (with `sk`), plus error state; allow sign-out (Keychain delete + clear local caches).
  - Document required URL scheme and Info.plist entries, plus the exact callback URL pattern used.
- Define scrobble criteria based on reliable iOS lifecycle signals:
  - Create a scrobble candidate on playback start with `startedAt`, track metadata, and duration; persist to disk so it survives app termination.
  - Commit scrobble on a definitive end signal (player item finished or playback state ended). If end signal is missing (background/interrupt), only scrobble when progress >= threshold and playback stops naturally. Prefer a conservative rule (e.g., finished or >= 60% duration) to avoid double-scrobbling; document the chosen rule.
  - Deduping: maintain a persistent ledger keyed by `trackId + startedAt + duration + artist` (or stable MusicKit ID if available) with a time window; skip duplicates across restarts.
  - Offline/retry queue: enqueue pending scrobbles, retry with backoff on network errors, and flush on app foreground and on playback end. Log when items are dropped due to staleness or duplicate detection.
- Implement Last.fm API calls (signed POSTs to `https://ws.audioscrobbler.com/2.0/`):
  - Signing: build param dictionary (exclude `format`/`callback`), sort alphabetically by param name, concat `key + value` pairs, append shared secret, MD5 hash for `api_sig`.
  - `track.updateNowPlaying`: params `method=track.updateNowPlaying`, `artist`, `track`, `album` (optional), `duration` (seconds), `api_key`, `sk`, `api_sig`, `format=json`. Call on playback start.
  - `track.scrobble`: params `method=track.scrobble`, `artist`, `track`, `timestamp` (Unix start time), `album` (optional), `duration` (optional), `api_key`, `sk`, `api_sig`, `format=json`. Call on commit. Support batch scrobbles with indexed params (`artist[0]`, `track[0]`, `timestamp[0]`, etc.) for queued items.
  - Error handling: parse JSON error codes even on 200 responses; map auth errors to sign-out, rate limit to retry, and validation errors to drop with log entry.
- Add visibility: console logs for auth/scrobble pipeline and an in-app "Scrobble Log" list (last N entries with status, timestamp, track) inside Settings.
- Tests: unit tests for scrobble criteria, dedupe ledger, queue persistence/retry, auth state transitions, and API signing.

References:
- Last.fm auth spec: https://www.last.fm/api/authspec
- Web auth flow: https://www.last.fm/api/webauth
- track.scrobble: https://www.last.fm/api/show/track.scrobble
- Scrobbling guidance: https://www.last.fm/pt/api/scrobbling
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Follow-up Beads tasks: apple-music-stories-93e (treat all plays as full intent), apple-music-stories-607 (playback event architecture write-up).

Additional Beads tasks: apple-music-stories-9s0 (playback sampling), apple-music-stories-c1f (playback diagnostics), apple-music-stories-1x4 (scrobble completion guard).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented Last.fm settings, auth, scrobble manager, logging, and tests. Tests: SNAPSHOT_RECORDING=1 ./scripts/ios.sh test.
<!-- SECTION:FINAL_SUMMARY:END -->

## Execution
- Beads: apple-music-stories-7af
- Status: Done
