#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Serve the MusicKit sample app with developer token injection.

Usage:
    uv run examples/musickit-sample/serve.py [--port PORT] [--host HOST] [--tls]

Environment variables:
    APPLE_MUSIC_DEVELOPER_TOKEN: The developer token to inject
    APPLE_MUSIC_DEVELOPER_TOKEN_PATH: Path to file containing the token
"""

from __future__ import annotations

import argparse
import http.server
import os
import pathlib
import ssl
import sys


def get_developer_token() -> str:
    """Get the developer token from environment or file."""
    token = os.environ.get("APPLE_MUSIC_DEVELOPER_TOKEN", "")
    if token:
        return token

    token_path = os.environ.get("APPLE_MUSIC_DEVELOPER_TOKEN_PATH", "")
    if not token_path:
        # Check default path
        root = pathlib.Path(__file__).parent.parent.parent
        default_path = root / ".auth" / "apple-music" / "developer_token"
        if default_path.exists():
            token_path = str(default_path)

    if token_path:
        return pathlib.Path(token_path).read_text().strip()

    return ""


def make_handler(
    sample_dir: pathlib.Path, developer_token: str
) -> type[http.server.BaseHTTPRequestHandler]:
    """Create a request handler that injects the developer token."""

    class SampleHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            path = self.path.split("?")[0]

            if path in ("", "/", "/index.html"):
                self.serve_index()
                return

            # Serve static files
            file_path = sample_dir / path.lstrip("/")
            if file_path.exists() and file_path.is_file():
                self.serve_file(file_path)
                return

            self.send_error(404, "Not found")

        def serve_index(self) -> None:
            index_path = sample_dir / "index.html"
            html = index_path.read_text()

            # Inject the developer token
            html = html.replace(
                'name="apple-music-developer-token" content=""',
                f'name="apple-music-developer-token" content="{developer_token}"',
            )
            # Set has-token meta
            has_token = "true" if developer_token else "false"
            html = html.replace(
                'name="apple-music-has-token" content="false"',
                f'name="apple-music-has-token" content="{has_token}"',
            )

            payload = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def serve_file(self, path: pathlib.Path) -> None:
            import mimetypes

            mime_type, _ = mimetypes.guess_type(str(path))
            payload = path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", mime_type or "application/octet-stream")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format: str, *args) -> None:
            return  # Suppress logging

    return SampleHandler


def ensure_certs(cert_dir: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path]:
    """Ensure TLS certificates exist, creating them if needed."""
    cert_dir.mkdir(parents=True, exist_ok=True)
    cert_path = cert_dir / "localhost.crt"
    key_path = cert_dir / "localhost.key"

    if not cert_path.exists() or not key_path.exists():
        import subprocess

        subprocess.run(
            [
                "openssl",
                "req",
                "-x509",
                "-newkey",
                "rsa:2048",
                "-sha256",
                "-days",
                "30",
                "-nodes",
                "-keyout",
                str(key_path),
                "-out",
                str(cert_path),
                "-subj",
                "/CN=localhost",
            ],
            check=True,
            capture_output=True,
        )

    return cert_path, key_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve MusicKit sample app")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--tls", action="store_true", help="Enable HTTPS")
    args = parser.parse_args()

    sample_dir = pathlib.Path(__file__).parent
    developer_token = get_developer_token()

    if not developer_token:
        print("Warning: No developer token found. Set APPLE_MUSIC_DEVELOPER_TOKEN")
        print("or APPLE_MUSIC_DEVELOPER_TOKEN_PATH, or place token in")
        print(".auth/apple-music/developer_token")

    handler = make_handler(sample_dir, developer_token)
    server = http.server.ThreadingHTTPServer((args.host, args.port), handler)

    scheme = "http"
    if args.tls:
        cert_dir = sample_dir.parent.parent / ".auth" / "apple-music" / "certs"
        cert_path, key_path = ensure_certs(cert_dir)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert_path, key_path)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        scheme = "https"

    print(f"Serving MusicKit sample at {scheme}://{args.host}:{args.port}")
    print(f"Developer token: {'present' if developer_token else 'MISSING'}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down")

    return 0


if __name__ == "__main__":
    sys.exit(main())
