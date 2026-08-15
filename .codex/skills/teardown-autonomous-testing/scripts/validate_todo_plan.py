#!/usr/bin/env python3
"""Fail-closed validation for the authoritative CM2 executable 80-Step plan."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
from typing import Any

from validate_contract import validate as validate_contract


IMPLEMENTATION = {"not_started", "in_progress", "finish", "unable"}
VERIFICATION = {"verified", "needs_regression", "pending", "human_visual_review"}
AUTOMATION = {"FULL_AUTO", "AUTO_WITH_VISUAL_REVIEW", "PARTIAL_AUTO", "MANUAL_REQUIRED"}
GATE_COUNTS = [5, 7, 8, 6, 6, 8, 7, 7, 6, 8, 6, 6]


def _hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def _business_projection(tasks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    fields = (
        "id", "stage", "title", "task_goal", "expected_outcome", "prerequisites",
        "implementation_scope", "acceptance_criteria", "source_plan", "plan_order",
    )
    return [{field: task.get(field) for field in fields} for task in tasks]


def _plan_source(task: dict[str, Any]) -> dict[str, Any]:
    fields = (
        "id", "title", "task_goal", "expected_outcome", "prerequisites",
        "implementation_scope", "acceptance_criteria",
    )
    return {field: task.get(field) for field in fields}


def _valid_unable_exception(task: dict[str, Any], document: dict[str, Any]) -> bool:
    policy = document.get("unable_exception_policy")
    if not isinstance(policy, dict) or policy.get("enabled") is not True:
        return False
    field = policy.get("field") if isinstance(policy.get("field"), str) and policy.get("field").strip() else "unable_exception"
    exception = task.get(field)
    if not isinstance(exception, dict):
        return False
    allowed = policy.get("allowed_markers")
    required = policy.get("required_fields")
    if not isinstance(allowed, list) or not allowed or not isinstance(required, list) or not required:
        return False
    if not isinstance(exception.get("marker"), str) or exception.get("marker") not in allowed:
        return False
    return all(isinstance(exception.get(name), str) and exception[name].strip() for name in required)


def expected_ids() -> list[str]:
    return [f"Step {gate}.{step}" for gate, count in enumerate(GATE_COUNTS) for step in range(1, count + 1)]


def validate(document: Any) -> list[str]:
    issues: list[str] = []
    if not isinstance(document, dict):
        return ["root must be an object"]
    if document.get("schema_version") != "cm2.todo/2":
        issues.append("schema_version must be cm2.todo/2")
    tasks = document.get("tasks")
    if not isinstance(tasks, list):
        return issues + ["tasks must be an array"]
    if document.get("task_count") != 80 or len(tasks) != 80:
        issues.append(f"task_count and tasks length must both be 80 (found {document.get('task_count')} and {len(tasks)})")
    ids = [task.get("id") if isinstance(task, dict) else None for task in tasks]
    if ids != expected_ids():
        issues.append("task IDs/order must remain the original Gate 0–11, 80-Step sequence")
    if len(set(ids)) != len(ids):
        issues.append("task IDs must be unique")
    for required, expected in (
        ("allowed_implementation_statuses", IMPLEMENTATION),
        ("allowed_verification_statuses", VERIFICATION),
        ("allowed_automation_levels", AUTOMATION),
    ):
        if set(document.get(required, [])) != expected:
            issues.append(f"{required} does not match the executable plan contract")
    policy = document.get("execution_policy")
    if not isinstance(policy, dict) or policy.get("contract_before_implementation") is not True:
        issues.append("execution_policy.contract_before_implementation must be true")
    dependency = document.get("dependency_review")
    if not isinstance(dependency, dict) or dependency.get("business_order_changed") is not False:
        issues.append("dependency_review must explicitly preserve the original business order")
    developer = document.get("developer_confirmed_unable")
    developer_ids = set(developer.get("task_ids", [])) if isinstance(developer, dict) else set()
    for index, task in enumerate(tasks, start=1):
        prefix = task.get("id", f"task[{index}]") if isinstance(task, dict) else f"task[{index}]"
        if not isinstance(task, dict):
            issues.append(f"{prefix}: task must be an object")
            continue
        if task.get("plan_order") != index:
            issues.append(f"{prefix}: plan_order must be {index}")
        match = re.fullmatch(r"Step (\d+)\.(\d+)", str(task.get("id", "")))
        if match and task.get("stage") != f"Gate {match.group(1)}":
            issues.append(f"{prefix}: stage does not match id")
        for field in ("title", "task_goal", "expected_outcome", "rollback", "source_plan"):
            if not isinstance(task.get(field), str) or not task[field].strip():
                issues.append(f"{prefix}: {field} must be a non-empty string")
        for field in ("prerequisites", "implementation_scope", "acceptance_criteria", "test_infrastructure_prerequisites"):
            if not isinstance(task.get(field), list) or not task[field]:
                issues.append(f"{prefix}: {field} must be a non-empty array")
        implementation = task.get("implementation_status")
        verification = task.get("verification_status")
        if implementation not in IMPLEMENTATION:
            issues.append(f"{prefix}: invalid implementation_status {implementation!r}")
        if verification not in VERIFICATION:
            issues.append(f"{prefix}: invalid verification_status {verification!r}")
        if not isinstance(task.get("verification_status_reason"), str) or not task["verification_status_reason"].strip():
            issues.append(f"{prefix}: verification_status_reason must be non-empty")
        contract = task.get("verification")
        contract_issues = validate_contract(contract)
        issues.extend(f"{prefix}.verification: {issue}" for issue in contract_issues)
        if isinstance(contract, dict):
            if contract.get("task") != f"{task.get('id')}: {task.get('title')}":
                issues.append(f"{prefix}: verification.task does not match task identity")
            if contract.get("behavior_under_test") != task.get("expected_outcome"):
                issues.append(f"{prefix}: behavior_under_test must match expected_outcome")
            if contract.get("plan_fingerprint") != _hash(_plan_source(task)):
                issues.append(f"{prefix}: verification plan_fingerprint is stale")
            if contract.get("automation_level") not in AUTOMATION:
                issues.append(f"{prefix}: invalid automation level")
        if implementation == "unable" and task.get("id") not in developer_ids and not task.get("developer_confirmed"):
            if not _valid_unable_exception(task, document):
                issues.append(f"{prefix}: unable implementation lacks a valid unable_exception or historical developer confirmation")
        evidence = task.get("evidence")
        evidence_fields = ("code_or_document", "automated_tests", "harness", "runtime_or_performance", "rollback_record")
        if not isinstance(evidence, dict) or any(not isinstance(evidence.get(field), str) or not evidence[field].strip() for field in evidence_fields):
            issues.append(f"{prefix}: historical evidence record is incomplete")
    expected_business = _hash(_business_projection(tasks))
    if document.get("business_plan_fingerprint") != expected_business:
        issues.append("business_plan_fingerprint does not match the ordered business plan")
    return issues


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("todo", type=Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    try:
        document = json.loads(args.todo.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL {args.todo}: {exc}")
        return 1
    issues = validate(document)
    if issues:
        print(f"FAIL {args.todo}")
        for issue in issues:
            print(f"- {issue}")
        return 1
    if not args.quiet:
        print(f"PASS {args.todo}: 80 executable Step contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
