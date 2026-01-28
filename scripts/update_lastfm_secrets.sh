#!/usr/bin/env bash
set -euo pipefail

if ! command -v op >/dev/null 2>&1; then
  echo "Error: 1Password CLI (op) is not installed or not on PATH." >&2
  exit 1
fi

api_key=$(op read "op://Private/Last.fm API key for Music Stories/API key")
api_secret=$(op read "op://Private/Last.fm API key for Music Stories/Shared secret")

secrets_path="ios/MusicStoryRenderer/Config/Secrets.xcconfig"

umask 077
tmpfile="$(mktemp)"
{
  printf 'LASTFM_API_KEY = %s\n' "$api_key"
  printf 'LASTFM_API_SECRET = %s\n' "$api_secret"
} > "$tmpfile"
mv "$tmpfile" "$secrets_path"

echo "Wrote Last.fm secrets to $secrets_path"
