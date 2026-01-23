# Apple Music Stories

This project is meant to facilitate ways of creating and consuming rich “music stories” where musical writing integrates with playback of music and videos from Apple Music’s streaming library. Some ideas at this point are:
- Create a display-independent document format that describes text alongside Apple Music links.
- Build agents that take a request and possibly some music background and create a “story” format for that information, linked with items from Apple Music.
- Build tools or agents that take a “music story” document and create a nice magazine-like web page, tailored for that story’s content, with integrated Apple Music playback.
- Build an iOS app that displays a “music story” document with integrated playback.

## Renderer

### Static export
- Render a story to HTML: `source ~/.local/bin/env && uv run scripts/render_story.py examples/sample-story out/sample-story`

### Server mode (HTTPS recommended)
MusicKit JS requires a secure context. Start the server with HTTPS:
- Generate a local cert: `openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes -keyout certs/localhost.key -out certs/localhost.crt -subj "/CN=localhost"`
- Serve with TLS: `source ~/.local/bin/env && uv run scripts/render_story.py serve --host 0.0.0.0 --port 8443 --tls-cert certs/localhost.crt --tls-key certs/localhost.key`
- Visit: `https://<host>:8443`

Pass the Apple Music developer token via `APPLE_MUSIC_DEVELOPER_TOKEN` or `--developer-token`.
