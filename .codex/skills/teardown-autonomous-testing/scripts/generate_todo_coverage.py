#!/usr/bin/env python3
"""Generate the CM2 80-Step verification coverage audit from the authoritative Todo."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from validate_contract import validate


RUNTIME = {"SCENE", "REAL_INPUT", "TELEMETRY", "VISUAL", "LOG", "MULTIPLAYER", "CONSUMER_MOD"}


def profiles(step_id: str, title: str) -> list[str]:
    stage = int(step_id.split()[1].split(".")[0])
    text = title.lower()
    result: set[str] = {"STATIC", "FIXTURE"}
    if stage == 0:
        result = {"STATIC"} if step_id in {"Step 0.2", "Step 0.5"} else {"STATIC", "SCENE", "TELEMETRY", "LOG"}
        if step_id in {"Step 0.1", "Step 0.3"}: result |= {"REAL_INPUT", "VISUAL"}
    elif stage == 1:
        if step_id in {"Step 1.5", "Step 1.7"}: result |= {"SCENE", "TELEMETRY", "LOG"}
        if step_id == "Step 1.6": result |= {"MULTIPLAYER"}
    elif stage in {2, 3}:
        result |= {"SCENE", "TELEMETRY", "LOG"}
        if any(word in text for word in ("presentation", "effect", "表现", "preview", "武器", "projectile", "audio", "舰载机")):
            result |= {"REAL_INPUT", "VISUAL"}
        if "多人" in text: result.add("MULTIPLAYER")
    elif stage == 4:
        result |= {"SCENE", "REAL_INPUT", "TELEMETRY", "LOG", "MULTIPLAYER"}
        if any(word in text for word in ("presentation", "audio", "舰")): result.add("VISUAL")
    elif stage == 5:
        result |= {"SCENE", "TELEMETRY", "LOG"}
        if any(word in text for word in ("point defense", "projectile", "弹丸", "guided", "interceptor")):
            result |= {"REAL_INPUT", "VISUAL"}
    elif stage == 6:
        result |= {"SCENE", "TELEMETRY", "VISUAL", "LOG"}
        if any(word in text for word in ("spawn", "dispose", "切换")): result.add("REAL_INPUT")
    elif stage == 7:
        result |= {"SCENE", "TELEMETRY", "VISUAL", "LOG"}
        if step_id != "Step 7.2": result.add("REAL_INPUT")
        if "多人" in text or "network" in text: result.add("MULTIPLAYER")
    elif stage == 8:
        if any(word in text for word in ("preview", "3d", "wizard", "editor")):
            result |= {"SCENE", "REAL_INPUT", "VISUAL", "LOG"}
        if "importer" in text or "pipeline" in text: result.add("CONSUMER_MOD")
    elif stage == 9:
        result.add("CONSUMER_MOD")
        if any(word in text for word in ("hello-ship", "global mod", "beta")):
            result |= {"SCENE", "TELEMETRY", "VISUAL", "LOG"}
        if "global mod" in text: result.add("MULTIPLAYER")
    elif stage == 10:
        result |= {"CONSUMER_MOD"}
        if step_id not in {"Step 10.1"}:
            result |= {"SCENE", "VISUAL", "LOG"}
    elif stage == 11:
        result |= {"CONSUMER_MOD", "SCENE", "TELEMETRY", "VISUAL", "LOG"}
        if step_id in {"Step 11.2", "Step 11.3", "Step 11.6"}: result.add("MULTIPLAYER")
        if step_id == "Step 11.2": result.add("REAL_INPUT")
    order = ["STATIC", "FIXTURE", "SCENE", "REAL_INPUT", "TELEMETRY", "VISUAL", "LOG", "MULTIPLAYER", "CONSUMER_MOD"]
    return [item for item in order if item in result]


def contract_text(step_id: str, title: str, selected: list[str]) -> dict[str, str]:
    stage = int(step_id.split()[1].split(".")[0])
    text = title.lower()
    setup = "Use versioned golden source plus valid/invalid deterministic fixtures in an isolated output directory."
    trigger = "Run the owning checker/fixture twice; compare byte output and structured diagnostics."
    assertions = "Valid input is deterministic; invalid/missing/future/duplicate input fails closed with stable field diagnostics; source and generated authority do not diverge."
    reload_mode = "NONE"
    regression = "Entry closure, source-of-truth, schema/compiler/catalog and relevant definition suites."
    evidence = "Contract JSON, fixture inputs, command trace, structured report, deterministic hashes and full Harness result."

    if stage in {2, 3}:
        setup = "Build a representative legacy/candidate pair and a deterministic scene containing only the affected definitions/effects."
        trigger = "Run static parity first, reload the scenario, then use the minimum real fire/preview action required by the profile."
        assertions = "Compiled identity and legacy semantic golden match or have an approved diff; telemetry names the versioned definition; presentation instances stay within budget and visual output is present; no legacy double-publish."
        reload_mode = "F4_TO_F5 for Lua; REOPEN_LEVEL_XML for XML/catalog placement"
        regression = "Four vertical slices, 109-weapon definition snapshot, presentation sequence/generation guards and legacy fallback."
        evidence = "Compiler/parity reports, telemetry event chain, budget counters, screenshots, log slice and Harness."
    if stage == 4:
        setup = "Use a two-ship, two-context fixture with one Host and at least one Client; fixed ownership, generations and command sequence."
        trigger = "Start official two-player local mode; issue one real command from the owning player and one invalid/non-owner command."
        assertions = "Host alone mutates world state; invalid owner/capability/generation/sequence is rejected; Host/Client converge without duplicate presentation, damage or stale resurrection."
        reload_mode = "RESTART_MOD_SESSION (terminate and relaunch every teardown_modtest instance)"
        regression = "Single-player authority, presentation ordering, registry lifecycle and multiplayer reconnect/late-join where claimed."
        evidence = "Per-window PID/HWND/status, Host and Client traces/screenshots, event generations/sequences, logs, cleanup counts and Harness."
    if stage == 5:
        setup = "Construct low/high-density deterministic battlefield fixtures with fixed projectiles, ships, cells, mounts and budgets."
        trigger = "Run identical seeded actions at baseline and pressure scale; collect authoritative counts/timings without manual flight."
        assertions = "Semantic hit/selection/collision parity holds; stores/queries remain bounded; no P×S fallback or stale handle; p95/p99 and allocation/GC metrics meet the declared budget."
        reload_mode = "F4_TO_F5; REOPEN_LEVEL_XML when entity density/placement changes"
        regression = "Direct/guided/PD/interceptor collision golden, lifecycle cleanup and S0–S8 performance baselines."
        evidence = "Seed/config, telemetry counts, before/after performance samples, hit traces, screenshots, logs and Harness."
    if stage == 6:
        setup = "Use single-body and minimal multi-body/joint fixtures with named parts/anchors, fixed transforms and spawn/dispose repetitions."
        trigger = "Resolve anchors, move/fire once where relevant, then repeatedly spawn and dispose the entity graph."
        assertions = "Stable entity/part identity and parent-local transforms resolve correctly; no root-body authority fallback remains; all bodies/joints/anchors/register entries are disposed exactly once."
        reload_mode = "REOPEN_LEVEL_XML for graph/prefab changes; F4_TO_F5 for resolver Lua"
        regression = "Existing single-body ships, weapon muzzle/effect/camera anchors, damage and lifecycle cleanup."
        evidence = "Graph snapshot, transform tolerances, spawn/dispose event trace, screenshots, logs and Harness."
    if stage == 7:
        setup = "Place a turret fixture and target at known azimuth/elevation/range, including limits, LOD and joint-budget pressure cases."
        trigger = "Run solver golden, then use real aim/fire/movement; for network work repeat from Host and Client authority contexts."
        assertions = "Angles/limits/convergence match solver tolerance; visual/physical actuator follows logical state; muzzle anchor and hit align; network sequence is monotonic; joint fallback respects budget."
        reload_mode = "REOPEN_LEVEL_XML for turret/joint fixture; F4_TO_F5 for solver/runtime Lua; multiplayer relaunch for network"
        regression = "Fixed-mount weapons, anchor resolver, projectile/hit chain, LOD and multiplayer ownership."
        evidence = "Solver vectors, telemetry angles/owners/hits, screenshots/video frames, budget metrics, logs and Harness."
    if stage == 8:
        setup = "Use read-only source assets plus disposable editor/preview projects covering valid, invalid and round-trip cases."
        trigger = "Import/build/edit/wizard-generate twice, validate outputs, then open the generated artifact in the appropriate preview scene."
        assertions = "Source is unchanged; outputs are deterministic/cache-correct; schema and anchors/mounts are valid; UI operations round-trip; preview loads and renders without runtime errors."
        reload_mode = "NONE for tools; RESTART_MCP/tool process for code; REOPEN_LEVEL_XML for Teardown preview"
        regression = "Asset manifest, provenance, compiler/schema, VOX orientation/anchors and preview budget."
        evidence = "Source/output hashes, cache report, generated definitions, UI screenshots, preview screenshot/log and Harness."
    if stage == 9:
        setup = "Install a clean-room disposable consumer package/Mod that depends only on the published manifest, SDK, schema or broker surface."
        trigger = "Build/install in a clean output, discover it in Mod Manager, start it and invoke one valid plus one invalid public operation."
        assertions = "No private CM2 path is copied; dependency/version/capability checks are explicit; compatible package runs; incompatible input fails closed; release contents and hashes match manifest."
        reload_mode = "REOPEN_MOD_MANAGER for new/metadata Mod; RESTART_MOD_SESSION for runtime; NONE for CLI-only"
        regression = "Basic consumer fixture, package compatibility, clean-room build, Core-only and rollback package."
        evidence = "Consumer source, package manifest/hash, install trace, runtime telemetry/screenshot/log when applicable and Harness."
    if stage == 10:
        setup = "Use a fixed AI evaluation corpus and disposable consumer output; deny undeclared network/file/runtime authority."
        trigger = "Generate twice from identical prompt/input, run policy/schema/provenance checks, then preview/package the accepted artifact through production tools."
        assertions = "Deterministic normalized result, explicit provenance and manual fields; no path escape/private code/runtime Lua/budget bypass; output compiles and consumer preview matches declared semantics."
        reload_mode = "NONE for generation; REOPEN_MOD_MANAGER/REOPEN_LEVEL_XML for consumer preview"
        regression = "AI eval negatives, compiler/schema, asset provenance, package security and Core semantic invariance."
        evidence = "Prompt/input hash, provider/provenance record, normalized outputs/diff, validator report, consumer preview screenshot/log and Harness."
    if stage == 11:
        setup = "Use immutable versioned release candidates plus independent consumer Mods; include baseline/upgrade/rollback and declared S0–S8 or soak topology."
        trigger = "Run every gate from a clean install; execute live single-player and required Host/Client scenarios; repeat after upgrade and exact rollback."
        assertions = "All component gates and negative cases pass; live runtime/soak/performance samples are real, not fixtures; package/save compatibility and exact rollback hashes hold; no-go remains enforced for any missing evidence."
        reload_mode = "RESTART_TEARDOWN between immutable package versions; RESTART_MOD_SESSION for each multiplayer/soak scenario"
        regression = "Golden packages, S0–S8, lifecycle/Save soak, p95/p99 budget, clean-room consumers, upgrade/rollback and support/security gates."
        evidence = "Immutable artifacts/hashes, machine/hardware identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off and Harness."

    if RUNTIME.intersection(selected) and any(word in text for word in ("入口", "smoke")):
        setup = "Load the formal CM2 entry and a disposable smoke level with telemetry enabled; preserve a pre-run log cursor."
        trigger = "Start through the real Mod Manager/editor path, exercise config/UI and one minimal gameplay action."
        assertions = "Every entry/include/resource loads, correct scenario/session appears, UI opens/closes through real input and no new runtime error occurs."
        reload_mode = "RESTART_MOD_SESSION; REOPEN_LEVEL_XML for editor XML changes"
    if "diagnostic" in text or "诊断" in text or "性能" in text:
        assertions += " Diagnostics are dormant by default, bounded when enabled and add no material disabled-path overhead."
    if "loadout" in text or "configuration" in text:
        trigger = "Load V0/V1 valid and invalid loadouts, exercise one real selection/fire, save/reload and compare normalized state."
        assertions += " Migration is idempotent; selected group/mount survives reload; invalid references fail closed."
    if "presentation" in text or "effect" in text or "表现" in text:
        assertions += " A published presentation_event has one visible consumer result and cleanup returns the fixed-capacity store to baseline."
    if "多人" in text or "network" in text:
        assertions += " Server/Client source, player, generation and sequence are explicit in evidence."
    return {"setup": setup, "trigger": trigger, "assertions": assertions, "reload": reload_mode, "regression": regression, "evidence": evidence}


def evidence_text(task: dict[str, Any]) -> str:
    return json.dumps(task.get("evidence", {}), ensure_ascii=False).lower()


def assessment(task: dict[str, Any], selected: list[str]) -> str:
    status = task.get("status", "unknown")
    old = evidence_text(task)
    missing_runtime = "teardown" in old and ("unavailable" in old or "unable" in old or "无法" in old)
    if status == "finish" and RUNTIME.intersection(selected) and missing_runtime:
        return "NEEDS REGRESSION — completion is retained, but current policy requires missing live evidence."
    if status == "unable" and missing_runtime:
        return "READY TO REASSESS — original unable status is retained; the former missing-Teardown premise is no longer true."
    if status == "finish":
        return "CURRENTLY COVERED — rerun the listed regression when adjacent contracts change."
    return "REQUIRES VERIFICATION — preserve the original status until this contract passes."


def generate(todo: dict[str, Any]) -> str:
    tasks = todo.get("tasks", [])
    lines = [
        "# CM2 80-Step test coverage audit",
        "",
        "Generated from `TEARDOWN_SHIP_PLATFORM_TODO.json`. This file adds test policy; it does not mutate historical task status. Regenerate with `generate_todo_coverage.py` after the plan changes.",
        "",
    ]
    counts: dict[str, int] = {}
    entries: list[tuple[dict[str, Any], list[str], dict[str, str], str]] = []
    for task in tasks:
        selected = profiles(task["id"], task["title"])
        detail = contract_text(task["id"], task["title"], selected)
        state = assessment(task, selected)
        key = state.split(" —", 1)[0]
        counts[key] = counts.get(key, 0) + 1
        entries.append((task, selected, detail, state))
    lines += [
        f"Inventory: {len(tasks)} Steps; " + "; ".join(f"{key}={value}" for key, value in sorted(counts.items())),
        "",
        "Every entry below supplies Profiles, Setup, Trigger, Assertions, Reload Mode, Regression and Evidence. Convert it into a concrete `cm2.verification-contract/1` before implementation.",
        "",
    ]
    for task, selected, detail, state in entries:
        lines += [
            f"## {task['id']} — {task['title']}",
            "",
            f"- Historical status: `{task.get('status', 'unknown')}`",
            f"- Audit: **{state}**",
            f"- Test Profiles: `{' + '.join(selected)}`",
            f"- Setup: {detail['setup']}",
            f"- Trigger: {detail['trigger']}",
            f"- Assertions: {detail['assertions']}",
            f"- Reload Mode: `{detail['reload']}`",
            f"- Regression: {detail['regression']}",
            f"- Evidence: {detail['evidence']}",
            "",
        ]
    return "\n".join(lines)


def machine_coverage(todo: dict[str, Any]) -> dict[str, Any]:
    contracts: list[dict[str, Any]] = []
    for task in todo.get("tasks", []):
        selected = profiles(task["id"], task["title"])
        detail = contract_text(task["id"], task["title"], selected)
        setup = detail["setup"]
        if "MULTIPLAYER" in selected and ("host" not in setup.lower() or "client" not in setup.lower()):
            setup += " Include an identified Host and Client topology."
        if "CONSUMER_MOD" in selected and "mod" not in setup.lower():
            setup += " Run the artifact through an independent consumer Mod."
        live = bool(RUNTIME.intersection(selected))
        contract = {
            "schema": "cm2.verification-contract/1",
            "task": f"{task['id']}: {task['title']}",
            "behavior_under_test": f"The production outcome claimed by {task['title']} satisfies its versioned contract without bypassing the behavior under test.",
            "test_profiles": selected,
            "setup": {"description": setup},
            "trigger": [detail["trigger"]],
            "expected_telemetry": [detail["assertions"]] if "TELEMETRY" in selected else [],
            "expected_state": [detail["assertions"]],
            "expected_visual": [detail["assertions"]] if "VISUAL" in selected else [],
            "expected_log": ["No new in-scope Lua or engine error appears after the baseline cursor."] if "LOG" in selected else [],
            "cleanup": (["Release every tracked key/button and confirm empty held-input state."] if live else []) + ["Dispose temporary fixtures and preserve formal source plus generated authority."],
            "reload_requirement": detail["reload"],
            "regression": [detail["regression"]],
            "evidence": [detail["evidence"]],
            "coverage_metadata": {
                "historical_status": task.get("status", "unknown"),
                "audit": assessment(task, selected),
                "source": "TEARDOWN_SHIP_PLATFORM_TODO.json",
            },
        }
        issues = validate(contract)
        if issues:
            raise ValueError(f"invalid generated contract for {task['id']}: {issues}")
        contracts.append(contract)
    return {
        "schema": "cm2.todo-verification-coverage/1",
        "source": "TEARDOWN_SHIP_PLATFORM_TODO.json",
        "task_count": len(contracts),
        "contracts": contracts,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("todo", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    todo = json.loads(args.todo.read_text(encoding="utf-8-sig"))
    if todo.get("task_count") != 80 or len(todo.get("tasks", [])) != 80:
        raise SystemExit("expected authoritative 80-Step plan")
    args.output.write_text(generate(todo), encoding="utf-8", newline="\n")
    json_path = args.output.with_suffix(".json")
    json_path.write_text(
        json.dumps(machine_coverage(todo), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"wrote {args.output} and {json_path}: {len(todo['tasks'])} Steps")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
