from __future__ import annotations

import argparse
import json
import time
from typing import Any

import httpx


def main() -> int:
    parser = argparse.ArgumentParser(description="Music Story Writer API CLI")
    parser.add_argument(
        "--base-url",
        default="http://127.0.0.1:8787",
        help="Story writer API base URL",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    create_parser = subparsers.add_parser("create", help="Create a run")
    create_parser.add_argument("--prompt", required=True, help="User prompt")
    create_parser.add_argument("--template", help="Starter template")
    create_parser.add_argument("--length-hint", help="Length hint")
    create_parser.add_argument("--tone-hint", help="Tone hint")
    create_parser.add_argument("--locale", help="Locale")
    create_parser.add_argument(
        "--watch", action="store_true", help="Watch run until terminal state"
    )

    watch_parser = subparsers.add_parser("watch", help="Watch a run")
    watch_parser.add_argument("run_id", help="Run id")
    watch_parser.add_argument(
        "--interval", type=float, default=1.0, help="Polling interval in seconds"
    )

    artifact_parser = subparsers.add_parser("artifact", help="Fetch run artifact")
    artifact_parser.add_argument("run_id", help="Run id")

    cancel_parser = subparsers.add_parser("cancel", help="Cancel run")
    cancel_parser.add_argument("run_id", help="Run id")

    args = parser.parse_args()

    client = httpx.Client(timeout=30.0)
    base_url = args.base_url.rstrip("/")

    try:
        if args.command == "create":
            payload: dict[str, Any] = {
                "prompt": args.prompt,
            }
            if args.template:
                payload["starter_template"] = args.template
            if args.length_hint:
                payload["length_hint"] = args.length_hint
            if args.tone_hint:
                payload["tone_hint"] = args.tone_hint
            if args.locale:
                payload["locale"] = args.locale

            response = client.post(f"{base_url}/v0/runs", json=payload)
            _raise_for_status(response)
            data = response.json()
            run_id = data["run_id"]
            print(json.dumps(data, indent=2))
            if args.watch:
                return _watch_run(client, base_url, run_id, interval_seconds=1.0)
            return 0

        if args.command == "watch":
            return _watch_run(
                client, base_url, args.run_id, interval_seconds=args.interval
            )

        if args.command == "artifact":
            response = client.get(f"{base_url}/v0/runs/{args.run_id}/artifact")
            _raise_for_status(response)
            print(json.dumps(response.json(), indent=2))
            return 0

        if args.command == "cancel":
            response = client.post(f"{base_url}/v0/runs/{args.run_id}/cancel")
            _raise_for_status(response)
            print(json.dumps(response.json(), indent=2))
            return 0

        parser.error("unknown command")
        return 2
    except httpx.HTTPError as exc:
        print(f"Error: {exc}")
        return 1
    finally:
        client.close()


def _watch_run(
    client: httpx.Client, base_url: str, run_id: str, interval_seconds: float
) -> int:
    last_event_idx = 0
    while True:
        events_response = client.get(f"{base_url}/v0/runs/{run_id}/events")
        _raise_for_status(events_response)
        events_payload = events_response.json()
        for event in events_payload.get("events", []):
            idx = int(event.get("idx", 0))
            if idx > last_event_idx:
                print(f"[{event.get('type')}] {event.get('message')}")
                last_event_idx = idx

        status_response = client.get(f"{base_url}/v0/runs/{run_id}")
        _raise_for_status(status_response)
        status_payload = status_response.json()
        status = status_payload.get("status")
        if status in {"completed", "failed", "cancelled"}:
            print(json.dumps(status_payload, indent=2))
            if status == "completed":
                artifact_response = client.get(f"{base_url}/v0/runs/{run_id}/artifact")
                if artifact_response.status_code == 200:
                    print(json.dumps(artifact_response.json(), indent=2))
            return 0 if status == "completed" else 1

        time.sleep(interval_seconds)


def _raise_for_status(response: httpx.Response) -> None:
    if response.status_code >= 400:
        raise httpx.HTTPStatusError(
            f"{response.status_code}: {response.text}",
            request=response.request,
            response=response,
        )


if __name__ == "__main__":
    raise SystemExit(main())
