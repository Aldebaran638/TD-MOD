"""Pure CM2_TEST_V1 protocol helpers used by the local MCP and unit tests."""

from __future__ import annotations

from copy import deepcopy
import json
from typing import Any, Iterable


PROTOCOL = "CM2_TEST_V1"


def build_request(
    nonce: str,
    command: str,
    after_seq: int = 0,
    target_body_id: int = 0,
    amount: float = 0.0,
    client_after_seq: int = 0,
) -> str:
    fields = [PROTOCOL, "request", f"nonce={nonce}", f"command={command}"]
    if command == "damage":
        fields.extend(
            [f"target_body_id={int(target_body_id)}", f"amount={float(amount):.6f}"]
        )
    else:
        fields.extend([
            f"after_seq={max(0, int(after_seq))}",
            f"client_after_seq={max(0, int(client_after_seq))}",
        ])
    return "|".join(fields)


def parse_response(text: str) -> dict[str, Any] | None:
    marker = f"{PROTOCOL}|response="
    if not isinstance(text, str) or not text.startswith(marker):
        return None
    try:
        value = json.loads(text[len(marker) :])
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def deduplicate_events(events: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[tuple[str, int, str]] = set()
    for event in events:
        if not isinstance(event, dict):
            continue
        source = str(event.get("source", "server"))
        sequence = int(event.get("seq", 0) or 0)
        event_type = str(event.get("type", "event"))
        key = (source, sequence, event_type)
        if key in seen:
            continue
        seen.add(key)
        result.append(event)
    return result


def next_server_sequence(events: Iterable[dict[str, Any]], fallback: int) -> int:
    current = int(fallback)
    for event in events:
        if not isinstance(event, dict) or str(event.get("source", "server")) == "client":
            continue
        try:
            current = max(current, int(event.get("seq", 0) or 0))
        except (TypeError, ValueError):
            continue
    return current


def truncate_response(
    payload: dict[str, Any],
    prefix: str = f"{PROTOCOL}|response=",
    max_bytes: int = 49152,
    max_events: int = 64,
    max_ships: int = 64,
) -> tuple[str, dict[str, Any]]:
    result = deepcopy(payload)
    result.setdefault("events", [])
    result.setdefault("snapshot", {}).setdefault("ships", [])
    result["events"] = deduplicate_events(result["events"])
    result["truncated"] = bool(result.get("truncated", False))

    def encode() -> str:
        return prefix + json.dumps(result, ensure_ascii=False, separators=(",", ":"))

    while len(result["events"]) > max_events:
        result["events"].pop()
        result["truncated"] = True
    while len(encode().encode("utf-8")) > max_bytes and result["events"]:
        result["events"].pop()
        result["truncated"] = True
    while len(result["snapshot"]["ships"]) > max_ships:
        result["snapshot"]["ships"].pop()
        result["truncated"] = True
    while len(encode().encode("utf-8")) > max_bytes and result["snapshot"]["ships"]:
        result["snapshot"]["ships"].pop()
        result["truncated"] = True
    if len(encode().encode("utf-8")) > max_bytes:
        result["events"] = []
        result["snapshot"]["ships"] = []
        result["truncated"] = True
        result["error"] = "response exceeds 48KB limit"
    return encode(), result


def clipboard_restore_allowed(
    original: str,
    request: str,
    current: str,
    response: str,
    observed_unexpected_change: bool = False,
) -> bool:
    """Return whether restoring *original* can safely avoid overwriting user data."""

    return not observed_unexpected_change and current in {request, response}
