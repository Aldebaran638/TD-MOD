#!/usr/bin/env python3
"""Validate embedded or standalone CM2 verification contracts."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any


ALLOWED_PROFILES = {
    "STATIC", "FIXTURE", "SCENE", "REAL_INPUT", "TELEMETRY",
    "VISUAL", "LOG", "MULTIPLAYER", "CONSUMER_MOD",
}
ALLOWED_EYES = {"EYE_TELEMETRY", "EYE_SCREENSHOT", "EYE_LOG"}
ALLOWED_HANDS = {"HAND_REAL_INPUT", "HAND_TEST_SETUP"}
ALLOWED_AUTOMATION = {
    "FULL_AUTO", "AUTO_WITH_VISUAL_REVIEW", "PARTIAL_AUTO", "MANUAL_REQUIRED",
}
V2_REQUIRED = {
    "schema", "plan_fingerprint", "task", "behavior_under_test", "profiles", "eyes", "hands",
    "setup", "reload", "trigger", "telemetry_assertions", "state_assertions",
    "visual_assertions", "log_assertions", "cleanup_assertions", "regression",
    "evidence", "automation_level", "automation_gaps",
}
V2_ARRAY_FIELDS = {
    "profiles", "eyes", "hands", "trigger", "telemetry_assertions",
    "state_assertions", "visual_assertions", "log_assertions",
    "cleanup_assertions", "regression", "evidence", "automation_gaps",
}
V1_REQUIRED = {
    "schema", "task", "behavior_under_test", "test_profiles", "setup",
    "trigger", "expected_telemetry", "expected_state", "expected_visual",
    "expected_log", "cleanup", "reload_requirement", "regression", "evidence",
}
V1_ARRAY_FIELDS = {
    "test_profiles", "trigger", "expected_telemetry", "expected_state",
    "expected_visual", "expected_log", "cleanup", "regression", "evidence",
}


def _nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _require_items(value: dict[str, Any], field: str, reason: str, issues: list[str]) -> None:
    data = value.get(field)
    if not isinstance(data, list) or not data:
        issues.append(f"{field} must contain assertions for {reason}")


def _validate_v1(value: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    missing = sorted(V1_REQUIRED - set(value))
    if missing:
        issues.append("missing required fields: " + ", ".join(missing))
    for field in ("task", "behavior_under_test", "reload_requirement"):
        if field in value and not _nonempty_string(value[field]):
            issues.append(f"{field} must be a non-empty string")
    for field in V1_ARRAY_FIELDS:
        if field in value and not isinstance(value[field], list):
            issues.append(f"{field} must be an array")
    profiles = value.get("test_profiles", [])
    if isinstance(profiles, list):
        _validate_profiles(profiles, issues)
    profile_set = set(profiles) if isinstance(profiles, list) else set()
    if "REAL_INPUT" in profile_set:
        _require_items(value, "trigger", "REAL_INPUT", issues)
    if "TELEMETRY" in profile_set and not value.get("expected_telemetry") and not value.get("expected_state"):
        issues.append("TELEMETRY requires expected_telemetry or expected_state")
    if "VISUAL" in profile_set:
        _require_items(value, "expected_visual", "VISUAL", issues)
    if "LOG" in profile_set:
        _require_items(value, "expected_log", "LOG", issues)
    _validate_topology(profile_set, value.get("setup", {}), issues)
    _require_items(value, "cleanup", "all contracts", issues)
    _require_items(value, "evidence", "all contracts", issues)
    return issues


def _validate_profiles(profiles: list[Any], issues: list[str]) -> None:
    if not profiles:
        issues.append("profiles must not be empty")
    normalized = list(map(str, profiles))
    unknown = sorted(set(normalized) - ALLOWED_PROFILES)
    if unknown:
        issues.append("unknown profiles: " + ", ".join(unknown))
    if len(normalized) != len(set(normalized)):
        issues.append("profiles contains duplicates")


def _validate_topology(profile_set: set[str], setup: Any, issues: list[str]) -> None:
    text = json.dumps(setup, ensure_ascii=False).lower()
    if "MULTIPLAYER" in profile_set and ("host" not in text or "client" not in text):
        issues.append("MULTIPLAYER setup must identify both Host and Client")
    if "CONSUMER_MOD" in profile_set and "mod" not in text:
        issues.append("CONSUMER_MOD setup must identify the external Mod")


def _validate_v2(value: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    missing = sorted(V2_REQUIRED - set(value))
    if missing:
        issues.append("missing required fields: " + ", ".join(missing))
    for field in ("task", "behavior_under_test"):
        if field in value and not _nonempty_string(value[field]):
            issues.append(f"{field} must be a non-empty string")
    fingerprint = value.get("plan_fingerprint")
    if not isinstance(fingerprint, str) or len(fingerprint) != 64 or any(ch not in "0123456789abcdef" for ch in fingerprint):
        issues.append("plan_fingerprint must be a lowercase SHA-256 hex string")
    for field in V2_ARRAY_FIELDS:
        if field in value and not isinstance(value[field], list):
            issues.append(f"{field} must be an array")
    setup = value.get("setup")
    if not isinstance(setup, dict):
        issues.append("setup must be an object")
    else:
        for field in ("description", "fixture", "determinism"):
            if not _nonempty_string(setup.get(field)):
                issues.append(f"setup.{field} must be a non-empty string")
        _require_items(setup, "forbidden_shortcuts", "behavior-boundary policy", issues)
    reload_value = value.get("reload")
    if not isinstance(reload_value, dict):
        issues.append("reload must be an object")
    else:
        for field in ("mode", "reason"):
            if not _nonempty_string(reload_value.get(field)):
                issues.append(f"reload.{field} must be a non-empty string")
        if not isinstance(reload_value.get("session_reset_expected"), bool):
            issues.append("reload.session_reset_expected must be boolean")
    profiles = value.get("profiles", [])
    if isinstance(profiles, list):
        _validate_profiles(profiles, issues)
    profile_set = set(profiles) if isinstance(profiles, list) else set()
    eyes = value.get("eyes", [])
    hands = value.get("hands", [])
    if isinstance(eyes, list):
        unknown = sorted(set(map(str, eyes)) - ALLOWED_EYES)
        if unknown:
            issues.append("unknown eyes: " + ", ".join(unknown))
    if isinstance(hands, list):
        unknown = sorted(set(map(str, hands)) - ALLOWED_HANDS)
        if unknown:
            issues.append("unknown hands: " + ", ".join(unknown))
    expected_eyes = {
        profile: eye for profile, eye in {
            "TELEMETRY": "EYE_TELEMETRY", "VISUAL": "EYE_SCREENSHOT", "LOG": "EYE_LOG",
        }.items()
    }
    eye_set = set(eyes) if isinstance(eyes, list) else set()
    for profile, eye in expected_eyes.items():
        if (profile in profile_set) != (eye in eye_set):
            issues.append(f"{profile} and {eye} must be declared together")
    hand_set = set(hands) if isinstance(hands, list) else set()
    if ("REAL_INPUT" in profile_set) != ("HAND_REAL_INPUT" in hand_set):
        issues.append("REAL_INPUT and HAND_REAL_INPUT must be declared together")
    setup_profiles = {"FIXTURE", "SCENE", "CONSUMER_MOD"}
    if bool(setup_profiles.intersection(profile_set)) != ("HAND_TEST_SETUP" in hand_set):
        issues.append("FIXTURE/SCENE/CONSUMER_MOD requires HAND_TEST_SETUP, and vice versa")
    if "TELEMETRY" in profile_set:
        _require_items(value, "telemetry_assertions", "TELEMETRY", issues)
    if "VISUAL" in profile_set:
        _require_items(value, "visual_assertions", "VISUAL", issues)
    if "LOG" in profile_set:
        _require_items(value, "log_assertions", "LOG", issues)
    if "REAL_INPUT" in profile_set:
        _require_items(value, "trigger", "REAL_INPUT", issues)
    _validate_topology(profile_set, setup or {}, issues)
    for field in ("state_assertions", "cleanup_assertions", "regression", "evidence"):
        _require_items(value, field, "all contracts", issues)
    automation = value.get("automation_level")
    if automation not in ALLOWED_AUTOMATION:
        issues.append("automation_level must be one of: " + ", ".join(sorted(ALLOWED_AUTOMATION)))
    gaps = value.get("automation_gaps")
    if automation in {"PARTIAL_AUTO", "MANUAL_REQUIRED", "AUTO_WITH_VISUAL_REVIEW"} and (not isinstance(gaps, list) or not gaps):
        issues.append(f"{automation} requires at least one automation_gaps explanation")
    if automation == "FULL_AUTO" and gaps:
        issues.append("FULL_AUTO must not declare automation_gaps")
    return issues


def validate(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["root must be a JSON object"]
    schema = value.get("schema")
    if schema == "cm2.verification-contract/1":
        return _validate_v1(value)
    if schema == "cm2.verification-contract/2":
        return _validate_v2(value)
    return ["schema must be cm2.verification-contract/1 or cm2.verification-contract/2"]


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_contract.py <contract.json>", file=sys.stderr)
        return 2
    path = Path(argv[1])
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
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
