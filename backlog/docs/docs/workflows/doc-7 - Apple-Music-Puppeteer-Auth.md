---
id: doc-7
title: Apple Music Puppeteer Auth
type: guide
created_date: '2026-01-24 21:46'
---

## Goal
Provide a repeatable way to authenticate Apple Music in a Puppeteer session so local tests and CI can exercise MusicKit JS playback flows without hard-coding credentials.

## Local manual sign-in workflow
1. Ensure dependencies are ready.
   - `npm install`
   - `uv run scripts/render_story.py serve --host 127.0.0.1 --port 8000`
2. Run the walkthrough script.
   - `APPLE_MUSIC_DEVELOPER_TOKEN_PATH=/path/to/token scripts/apple_music_auth_walkthrough.sh`
3. When the browser opens, sign into Apple Music in the rendered story page.
4. Press Enter in the terminal once sign-in succeeds.
5. The session is persisted for future Puppeteer runs.

## Persistence strategy
Primary persistence uses a Chromium user data directory (profile), stored outside git:
- `PUPPETEER_USER_DATA_DIR=.auth/apple-music`

Optional fallback persistence captures cookies into a JSON blob:
- `APPLE_MUSIC_SESSION_PATH=.auth/apple-music/session.json`
- The test script can load and apply cookies on startup and will refresh the file after a successful run.

## Environment variables
- `STORY_BASE_URL`: Base URL for the renderer server. Default `http://127.0.0.1:8000`.
- `PUPPETEER_USER_DATA_DIR`: Persistent Chromium profile directory.
- `PUPPETEER_HEADLESS`: `false` for manual sign-in, `new`/`true` for CI.
- `APPLE_MUSIC_INTERACTIVE`: `1` to pause and wait for manual sign-in.
- `APPLE_MUSIC_SESSION_PATH`: Optional cookie dump path for CI fallback.
- `APPLE_MUSIC_DEVELOPER_TOKEN`: Apple Music developer token (preferred).
- `APPLE_MUSIC_DEVELOPER_TOKEN_PATH`: Path to a file containing the developer token.

## CI/CD plan
1. Store a dedicated Apple Music test account session as a secret artifact.
   - Zip `.auth/apple-music` or store `session.json` as a secret.
2. CI job restores the session before running Puppeteer.
   - Set `PUPPETEER_USER_DATA_DIR` to the restored directory.
   - Set `PUPPETEER_HEADLESS=new`.
3. If no session is available, skip Apple Music auth checks and run non-auth smoke checks only.
4. Refresh cadence: re-run the walkthrough locally (or via a secure manual CI job) when the session expires.

## Security notes
- Never commit `.auth/` or `session.json`.
- Prefer a dedicated test account with minimal permissions.
- Rotate the session by re-running the walkthrough script on expiration.

## Troubleshooting
- If sign-in is blocked, verify HTTPS is used for MusicKit JS and that the developer token is present.
- If cookies fail to restore, delete `.auth/apple-music` and re-run the walkthrough.
- If CI is failing, confirm the secret is restoring to the expected path and that the test script runs headless.
