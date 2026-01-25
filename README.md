# Apple Music Stories

This project is meant to facilitate ways of creating and consuming rich “music stories” where musical writing integrates with playback of music and videos from Apple Music’s streaming library. Some ideas at this point are:
- Create a display-independent document format that describes text alongside Apple Music links.
- Build agents that take a request and possibly some music background and create a “story” format for that information, linked with items from Apple Music.
- Build tools or agents that take a “music story” document and create a nice magazine-like web page, tailored for that story’s content, with integrated Apple Music playback.
- Build an iOS app that displays a “music story” document with integrated playback (now in `ios/`).

## Story format

Stories are authored as MDX with YAML front matter, stored as a package folder (see `backlog/docs/docs/design/doc-1 - Music-Story-Document-Format.md`).
The iOS renderer accepts a strict MDX subset so parsing stays deterministic (full spec: `backlog/docs/docs/design/doc-6 - MDX-Subset-Specification-for-iOS-Renderer.md`).

Key rules in the current subset:
- The body is a sequence of `<Section>` blocks only; no text outside a section.
- `<Section>` supports paragraphs plus `<MediaRef />` blocks; sections cannot be nested.
- Supported Markdown is limited to paragraphs, emphasis, strong emphasis, inline code, and links.
- Attributes must be double-quoted strings; no JSX expressions, imports, or other components.

## iOS app

The SwiftUI app now lives in `ios/` and ships the MDX parser, story renderer, and MusicKit playback UI.
Reference docs:
- Architecture overview: `ios/architecture.md`
- Development workflow: `ios/development.md`

## Renderer

### Static export
- Render a story to HTML: `source ~/.local/bin/env && uv run scripts/render_story.py examples/sample-story out/sample-story`

### Server mode (HTTPS recommended)
MusicKit JS requires a secure context. Start the server with HTTPS:
- Generate a local cert: `openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes -keyout certs/localhost.key -out certs/localhost.crt -subj "/CN=localhost"`
- Serve with TLS: `source ~/.local/bin/env && uv run scripts/render_story.py serve --host 0.0.0.0 --port 8443 --tls-cert certs/localhost.crt --tls-key certs/localhost.key`
- Visit: `https://<host>:8443`

Pass the Apple Music developer token via `APPLE_MUSIC_DEVELOPER_TOKEN` or `--developer-token`.

### Puppeteer smoke test
- Install Node dependencies: `npm install`
- Start the server: `uv run scripts/render_story.py serve --host 127.0.0.1 --port 8000`
- Run the test: `node scripts/puppeteer_story_test.js`

Override the base URL with `STORY_BASE_URL` if you are serving on a different host/port.

For Apple Music authentication, export `APPLE_MUSIC_DEVELOPER_TOKEN` (or set `APPLE_MUSIC_DEVELOPER_TOKEN_PATH`) and run `scripts/apple_music_auth_walkthrough.sh` once to establish a persistent session in `.auth/apple-music`, then rerun the Puppeteer test as needed.

To run the Puppeteer smoke test end-to-end with MusicKit enabled, start the server with `APPLE_MUSIC_DEVELOPER_TOKEN` (or `APPLE_MUSIC_DEVELOPER_TOKEN_PATH`) set and then run `node scripts/puppeteer_story_test.js`.

The playback check expects HTTPS and a previously authorized user profile; on failure the script prints page console logs to help diagnose MusicKit authorization issues. By default it plays `stories/hip-hop-changed-the-game/story.mdx` media key `trk-alright`; override with `APPLE_MUSIC_STORY_ID` and `APPLE_MUSIC_MEDIA_KEY` if needed.
