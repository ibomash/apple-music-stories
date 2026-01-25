#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${APPLE_MUSIC_USE_TLS:=1}"
: "${STORY_BASE_URL:=}"
: "${PUPPETEER_USER_DATA_DIR:=$ROOT_DIR/.auth/apple-music}"
: "${APPLE_MUSIC_SESSION_PATH:=$ROOT_DIR/.auth/apple-music/session.json}"
: "${APPLE_MUSIC_DEVELOPER_TOKEN:=}"
: "${APPLE_MUSIC_DEVELOPER_TOKEN_PATH:=}"

DEFAULT_TOKEN_PATH="$ROOT_DIR/.auth/apple-music/developer_token"
CERT_DIR="$ROOT_DIR/.auth/apple-music/certs"
CERT_PATH="$CERT_DIR/localhost.crt"
KEY_PATH="$CERT_DIR/localhost.key"

if [[ -z "${STORY_BASE_URL}" ]]; then
  if [[ "${APPLE_MUSIC_USE_TLS}" == "1" ]]; then
    STORY_BASE_URL="https://127.0.0.1:8443"
  else
    STORY_BASE_URL="http://127.0.0.1:8000"
  fi
fi

if [[ -z "${APPLE_MUSIC_DEVELOPER_TOKEN}" ]]; then
  if [[ -z "${APPLE_MUSIC_DEVELOPER_TOKEN_PATH}" && -f "${DEFAULT_TOKEN_PATH}" ]]; then
    APPLE_MUSIC_DEVELOPER_TOKEN_PATH="${DEFAULT_TOKEN_PATH}"
  fi

  if [[ -n "${APPLE_MUSIC_DEVELOPER_TOKEN_PATH}" ]]; then
    APPLE_MUSIC_DEVELOPER_TOKEN="$(<"${APPLE_MUSIC_DEVELOPER_TOKEN_PATH}")"
  fi
fi

if [[ -z "${APPLE_MUSIC_DEVELOPER_TOKEN}" ]]; then
  echo "APPLE_MUSIC_DEVELOPER_TOKEN is required for MusicKit playback." >&2
  echo "Set APPLE_MUSIC_DEVELOPER_TOKEN or APPLE_MUSIC_DEVELOPER_TOKEN_PATH and retry." >&2
  exit 1
fi

export STORY_BASE_URL
export PUPPETEER_USER_DATA_DIR
export APPLE_MUSIC_SESSION_PATH
export APPLE_MUSIC_DEVELOPER_TOKEN

echo "Starting story server on ${STORY_BASE_URL}..."
if [[ "${STORY_BASE_URL}" == https://* ]]; then
  mkdir -p "${CERT_DIR}"
  if [[ ! -f "${CERT_PATH}" || ! -f "${KEY_PATH}" ]]; then
    openssl req -x509 -newkey rsa:2048 -sha256 -days 30 -nodes \
      -keyout "${KEY_PATH}" -out "${CERT_PATH}" -subj "/CN=localhost" >/dev/null 2>&1
  fi
  uv run scripts/render_story.py serve --host 127.0.0.1 --port 8443 \
    --tls-cert "${CERT_PATH}" --tls-key "${KEY_PATH}" &
else
  uv run scripts/render_story.py serve --host 127.0.0.1 --port 8000 &
fi
SERVER_PID=$!

cleanup() {
  kill "${SERVER_PID}" >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "Launching Puppeteer for manual Apple Music sign-in..."
PUPPETEER_HEADLESS=false APPLE_MUSIC_INTERACTIVE=1 APPLE_MUSIC_SKIP_PLAYBACK=1 \
  node scripts/puppeteer_story_test.js

echo "Session saved in ${PUPPETEER_USER_DATA_DIR}."
echo "Cookie snapshot saved to ${APPLE_MUSIC_SESSION_PATH}."
