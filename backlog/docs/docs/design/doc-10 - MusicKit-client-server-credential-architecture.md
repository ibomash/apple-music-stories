---
id: doc-10
title: MusicKit client/server credential architecture
type: other
created_date: '2026-01-25 22:31'
---

## Purpose

Document a minimal client/server split for MusicKit JS playback in static story HTML, with safe handling of Apple Music developer credentials.

## Summary

MusicKit JS runs in the browser. The developer token (JWT signed with the Apple Music private key) should be minted server-side and returned to the client over HTTPS. The private key never ships to the browser. The client still performs user authorization via MusicKit JS to obtain a user token.

## Client responsibilities

- Load the static story HTML and MusicKit JS.
- Fetch a short-lived developer token from the server.
- Initialize MusicKit with the developer token and call authorize for the user token.
- Play catalog items via MusicKit JS APIs.

## Server responsibilities

- Store the Apple Music private key securely.
- Mint short-lived developer tokens on demand.
- Return the token over HTTPS.
- Apply rate limiting and basic logging.

## API shape (example)

- Endpoint: `GET /api/apple-music/developer-token`
- Response: `{ "token": "<jwt>" }`
- Headers: `Cache-Control: no-store`

## Security notes

- Do not embed the private key or long-lived developer token in static HTML.
- Origin or Referer checks help reduce casual misuse but are not a strong security boundary.
- Short token TTLs reduce risk if a token is leaked.
- HTTPS is required for MusicKit JS and protects the token in transit.

## DreamHost-friendly setup

- Host static HTML on `https://illya.bomash.net`.
- Implement a small CGI/WSGI endpoint for token minting.
- Validate `Origin: https://illya.bomash.net` (optionally `https://www.illya.bomash.net`).
- Return short-lived tokens (15-60 minutes) and apply rate limiting.

## Notes for this repo

- The renderer supports a developer token via `APPLE_MUSIC_DEVELOPER_TOKEN` or `--developer-token` for server mode.
- For static export, prefer client-side token fetch instead of embedding the token in HTML.
