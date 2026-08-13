#!/usr/bin/env python3
"""Upgrade or refresh the authoritative CM2 Todo without losing task history."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from generate_todo_coverage import build_contract, verification_status


ALLOWED_VERIFICATION = {"verified", "needs_regression", "pending", "human_visual_review"}


def infrastructure_prerequisites(contract: dict[str, Any]) -> list[str]:
    profiles = set(contract["profiles"])
    result = ["A valid embedded Verification Contract and the full repository Harness are available before implementation begins."]
    if "FIXTURE" in profiles:
        result.append("The owning deterministic fixture runner and negative cases are available before product changes.")
    if "SCENE" in profiles:
        result.append("A disposable deterministic Scenario with revision identity and CM2_TEST_V1 telemetry is available before runtime work.")
    if "REAL_INPUT" in profiles:
        result.append("Targeted fresh-frame keyboard/mouse control and emergency release are available; setup removes unrelated travel and aiming.")
    if "MULTIPLAYER" in profiles:
        result.append("Host/Client instance enumeration and per-role evidence are available; unresolved Client focus/telemetry gaps block only the affected assertion.")
    if "CONSUMER_MOD" in profiles:
        result.append("An independent clean-room disposable consumer Mod/package is available and contains no private CM2 implementation include.")
    return result


def upgrade(document: dict[str, Any], reassess: bool = False) -> dict[str, Any]:
    result = copy.deepcopy(document)
    old_schema = result.get("schema_version")
    tasks = result.get("tasks", [])
    if len(tasks) != 80:
        raise ValueError(f"expected 80 tasks, found {len(tasks)}")
    for index, task in enumerate(tasks, start=1):
        implementation = task.pop("status", task.get("implementation_status", "not_started"))
        task["implementation_status"] = implementation
        old_contract = task.get("verification") if isinstance(task.get("verification"), dict) else None
        new_contract = build_contract(task)
        fingerprint_changed = bool(old_contract) and old_contract.get("plan_fingerprint") != new_contract.get("plan_fingerprint")
        prior_status = task.get("verification_status")
        if reassess or old_schema != "cm2.todo/2" or prior_status not in ALLOWED_VERIFICATION or fingerprint_changed:
            assessed, reason = verification_status(task)
            if fingerprint_changed:
                assessed = "needs_regression" if implementation == "finish" else "pending"
                reason = "The task definition changed after its prior contract; implementation status is retained and the regenerated contract must run again."
            task["verification_status"] = assessed
            task["verification_status_reason"] = reason
        task["verification"] = new_contract
        task["test_infrastructure_prerequisites"] = infrastructure_prerequisites(new_contract)
        task["plan_order"] = index

    result["schema_version"] = "cm2.todo/2"
    result["implementation_status_field"] = "implementation_status"
    result["verification_status_field"] = "verification_status"
    result["automation_level_path"] = "verification.automation_level"
    result.pop("status_field", None)
    result["finish_value"] = "finish"
    result["allowed_implementation_statuses"] = result.pop(
        "allowed_statuses", ["not_started", "in_progress", "finish", "unable"]
    )
    result["allowed_verification_statuses"] = [
        "verified", "needs_regression", "pending", "human_visual_review"
    ]
    result["allowed_automation_levels"] = [
        "FULL_AUTO", "AUTO_WITH_VISUAL_REVIEW", "PARTIAL_AUTO", "MANUAL_REQUIRED"
    ]
    result["completion_statuses"] = ["finish", "unable"]
    result["verification_completion_statuses"] = ["verified", "human_visual_review"]
    result["execution_policy"] = {
        "contract_before_implementation": True,
        "workflow": [
            "read_step", "validate_embedded_contract", "determine_reload",
            "prepare_fixture_or_scenario", "implement", "targeted_checks",
            "full_harness", "runtime_test_if_profiled", "regression",
            "persist_evidence", "update_verification_status", "update_implementation_status",
        ],
        "evidence_authority": {
            "EYE_TELEMETRY": "authoritative gameplay state and event boundaries",
            "EYE_SCREENSHOT": "visible UI, scene, presentation, camera, and clipping facts only",
            "EYE_LOG": "incremental runtime health, error, warning, and protocol facts only",
        },
        "hands_policy": {
            "HAND_REAL_INPUT": "minimum real player input when the input-facing production path is under test",
            "HAND_TEST_SETUP": "deterministic preconditions only; never bypass the behavior under test",
        },
        "ordering": "Original 80-Step order and business dependencies are preserved. Test infrastructure prerequisites may be completed early without changing a later Step's business implementation order.",
    }
    result["dependency_review"] = {
        "business_order_changed": False,
        "original_order": "Gate 0 through Gate 11; Step IDs and prerequisite text are unchanged.",
        "decision": "Do not reorder business work. Front-load only reusable test infrastructure named by each Step's test_infrastructure_prerequisites.",
        "benefit": "Later runtime Steps reuse deterministic Scenarios, telemetry, multi-window targeting, consumer fixtures, reload automation, and fail-closed contracts without bypassing their production behavior.",
        "risk_control": "Test infrastructure may not promote a candidate Runtime, change catalog authority, or satisfy a gameplay assertion through an internal shortcut.",
    }
    result["hook_contract"] = {
        "stop_event": "Stop",
        "rule": "Fail closed on malformed/missing contracts. Finished tasks require verified or human_visual_review; developer-confirmed unable tasks may retain pending verification but still require a valid executable contract. Any needs_regression task is the next continuation target.",
        "checker": ".codex/hooks/check-todo-stop.ps1",
    }
    result["task_count"] = len(tasks)
    business_projection = [
        {
            "id": task["id"],
            "stage": task["stage"],
            "title": task["title"],
            "task_goal": task["task_goal"],
            "expected_outcome": task["expected_outcome"],
            "prerequisites": task["prerequisites"],
            "implementation_scope": task["implementation_scope"],
            "acceptance_criteria": task["acceptance_criteria"],
            "source_plan": task["source_plan"],
            "plan_order": task["plan_order"],
        }
        for task in tasks
    ]
    result["business_plan_fingerprint"] = hashlib.sha256(
        json.dumps(business_projection, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    # Keep stable, policy-first root ordering when serialized.
    ordered: dict[str, Any] = {}
    keys = [
        "schema_version", "project", "implementation_status_field",
        "verification_status_field", "automation_level_path", "finish_value",
        "allowed_implementation_statuses", "allowed_verification_statuses",
        "allowed_automation_levels", "completion_statuses",
        "verification_completion_statuses", "developer_confirmed_unable",
        "execution_policy", "dependency_review", "hook_contract", "source_plan", "task_count",
        "business_plan_fingerprint", "tasks",
    ]
    for key in keys:
        if key in result:
            ordered[key] = result[key]
    for key, value in result.items():
        if key not in ordered:
            ordered[key] = value
    return ordered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("todo", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--reassess", action="store_true")
    args = parser.parse_args()
    output = args.output or args.todo
    document = json.loads(args.todo.read_text(encoding="utf-8-sig"))
    updated = upgrade(document, reassess=args.reassess)
    output.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {output}: {len(updated['tasks'])} executable Steps")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
