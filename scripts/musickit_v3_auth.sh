#!/usr/bin/env bash
# Interactive authorization for MusicKit v3
# Opens a browser window where you can sign in to Apple Music
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${APPLE_MUSIC_DEVELOPER_TOKEN:=}"
: "${APPLE_MUSIC_DEVELOPER_TOKEN_PATH:=}"
: "${PUPPETEER_USER_DATA_DIR:=$ROOT_DIR/.auth/apple-music}"

DEFAULT_TOKEN_PATH="$ROOT_DIR/.auth/apple-music/developer_token"

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
  echo "ERROR: No developer token found." >&2
  echo "Set APPLE_MUSIC_DEVELOPER_TOKEN or place token in .auth/apple-music/developer_token" >&2
  exit 1
fi

export APPLE_MUSIC_DEVELOPER_TOKEN
export PUPPETEER_USER_DATA_DIR

# Ensure certs exist
CERT_DIR="$ROOT_DIR/.auth/apple-music/certs"
mkdir -p "$CERT_DIR"
if [[ ! -f "$CERT_DIR/localhost.crt" ]]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 30 -nodes \
    -keyout "$CERT_DIR/localhost.key" \
    -out "$CERT_DIR/localhost.crt" \
    -subj "/CN=localhost" 2>/dev/null
fi

echo "Starting server on https://127.0.0.1:8443..."
uv run scripts/render_story.py serve --host 127.0.0.1 --port 8443 \
  --tls-cert "$CERT_DIR/localhost.crt" \
  --tls-key "$CERT_DIR/localhost.key" &
SERVER_PID=$!

cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

sleep 2

echo ""
echo "Opening browser for Apple Music authorization..."
echo "1. Click 'Authorize' button"
echo "2. Sign in with your Apple ID"
echo "3. Close the browser when done"
echo ""

# Open browser in non-headless mode
PUPPETEER_HEADLESS=false \
STORY_BASE_URL=https://127.0.0.1:8443 \
APPLE_MUSIC_INTERACTIVE=1 \
APPLE_MUSIC_SKIP_PLAYBACK=1 \
node scripts/puppeteer_story_test.js

echo ""
echo "Authorization complete! The session is stored in $PUPPETEER_USER_DATA_DIR"
echo "You can now run the playback test with:"
echo "  node scripts/puppeteer_story_test.js"
