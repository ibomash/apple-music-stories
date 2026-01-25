#!/usr/bin/env bash
# Serve all stories with MusicKit playback enabled
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${APPLE_MUSIC_DEVELOPER_TOKEN:=}"
: "${APPLE_MUSIC_DEVELOPER_TOKEN_PATH:=}"
: "${HOST:=127.0.0.1}"
: "${PORT:=8443}"

DEFAULT_TOKEN_PATH="$ROOT_DIR/.auth/apple-music/developer_token"
CERT_DIR="$ROOT_DIR/.auth/apple-music/certs"
CERT_PATH="$CERT_DIR/localhost.crt"
KEY_PATH="$CERT_DIR/localhost.key"

# Load developer token
if [[ -z "${APPLE_MUSIC_DEVELOPER_TOKEN}" ]]; then
  if [[ -z "${APPLE_MUSIC_DEVELOPER_TOKEN_PATH}" && -f "${DEFAULT_TOKEN_PATH}" ]]; then
    APPLE_MUSIC_DEVELOPER_TOKEN_PATH="${DEFAULT_TOKEN_PATH}"
  fi
  if [[ -n "${APPLE_MUSIC_DEVELOPER_TOKEN_PATH}" ]]; then
    APPLE_MUSIC_DEVELOPER_TOKEN="$(<"${APPLE_MUSIC_DEVELOPER_TOKEN_PATH}")"
  fi
fi

if [[ -z "${APPLE_MUSIC_DEVELOPER_TOKEN}" ]]; then
  echo "Warning: No developer token found. Playback will be disabled." >&2
  echo "Set APPLE_MUSIC_DEVELOPER_TOKEN or place token in .auth/apple-music/developer_token" >&2
fi

export APPLE_MUSIC_DEVELOPER_TOKEN

# Ensure TLS certs exist
mkdir -p "$CERT_DIR"
if [[ ! -f "$CERT_PATH" || ! -f "$KEY_PATH" ]]; then
  echo "Generating TLS certificates..."
  openssl req -x509 -newkey rsa:2048 -sha256 -days 30 -nodes \
    -keyout "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=localhost" 2>/dev/null
fi

echo "Serving stories at https://${HOST}:${PORT}"
echo "Developer token: ${APPLE_MUSIC_DEVELOPER_TOKEN:+present}${APPLE_MUSIC_DEVELOPER_TOKEN:-MISSING}"
echo ""
echo "Stories served from: stories/ and examples/"
echo ""
echo "NOTE: To enable Apple Music playback, click 'Authorize' in the browser"
echo "      and sign in with your Apple ID (requires Apple Music subscription)."
echo ""
echo "Press Ctrl+C to stop"
echo ""

exec uv run scripts/render_story.py serve \
  --host "$HOST" \
  --port "$PORT" \
  --tls-cert "$CERT_PATH" \
  --tls-key "$KEY_PATH"
