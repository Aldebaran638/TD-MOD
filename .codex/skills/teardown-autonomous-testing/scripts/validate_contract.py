#!/usr/bin/env python3
"""Validate a cm2.verification-contract/1 JSON file without engine access."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any


ALLOWED_PROFILES = {
    "STATIC", "FIXTURE", "SCENE", "REAL_INPUT", "TELEMETRY",
    "VISUAL", "LOG", "MULTIPLAYER", "CONSUMER_MOD",
}
REQUIRED = {
    "schema", "task", "behavior_under_test", "test_profiles", "setup",
    "trigger", "expected_telemetry", "expected_state", "expected_visual",
    "expected_log", "cleanup", "reload_requirement", "regression", "evidence",
}
ARRAY_FIELDS = {
    "test_profiles", "trigger", "expected_telemetry", "expected_state",
    "expected_visual", "expected_log", "cleanup", "regression", "evidence",
}


def _nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(value: Any) -> list[str]:
    issues: list[str] = []
    if not isinstance(value, dict):
        return ["root must be a JSON object"]
    missing = sorted(REQUIRED - set(value))
    if missing:
        issues.append("missing required fields: " + ", ".join(missing))
    if value.get("schema") != "cm2.verification-contract/1":
        issues.append("schema must be cm2.verification-contract/1")
    for field in ("task", "behavior_under_test", "reload_requirement"):
        if field in value and not _nonempty_string(value[field]):
            issues.append(f"{field} must be a non-empty string")
    for field in ARRAY_FIELDS:
        if field in value and not isinstance(value[field], list):
            issues.append(f"{field} must be an array")
    profiles = value.get("test_profiles", [])
    if isinstance(profiles, list):
        if not profiles:
            issues.append("test_profiles must not be empty")
        unknown = sorted({str(item) for item in profiles} - ALLOWED_PROFILES)
        if unknown:
            issues.append("unknown test profiles: " + ", ".join(unknown))
        if len(profiles) != len(set(map(str, profiles))):
            issues.append("test_profiles contains duplicates")

    def require_items(field: str, reason: str) -> None:
        data = value.get(field)
        if not isinstance(data, list) or not data:
            issues.append(f"{field} must contain assertions for {reason}")

    profile_set = set(profiles) if isinstance(profiles, list) else set()
    if "REAL_INPUT" in profile_set:
        require_items("trigger", "REAL_INPUT")
    if "TELEMETRY" in profile_set:
        if not value.get("expected_telemetry") and not value.get("expected_state"):
            issues.append("TELEMETRY requires expected_telemetry or expected_state")
    if "VISUAL" in profile_set:
        require_items("expected_visual", "VISUAL")
    if "LOG" in profile_set:
        require_items("expected_log", "LOG")
    if "MULTIPLAYER" in profile_set:
        text = json.dumps(value.get("setup", {}), ensure_ascii=False).lower()
        if "host" not in text or "client" not in text:
            issues.append("MULTIPLAYER setup must identify both Host and Client")
    if "CONSUMER_MOD" in profile_set:
        text = json.dumps(value.get("setup", {}), ensure_ascii=False).lower()
        if "mod" not in text:
            issues.append("CONSUMER_MOD setup must identify the external Mod")
    require_items("cleanup", "all contracts")
    require_items("evidence", "all contracts")
    return issues


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_contract.py <contract.json>", file=sys.stderr)
        return 2
    path = Path(argv[1])
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL {path}: {exc}", file=sys.stderr)
        return 1
    issues = validate(value)
    if issues:
        print(f"FAIL {path}")
        for issue in issues:
            print(f"- {issue}")
        return 1
    print(f"PASS {path}: {value['task']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
