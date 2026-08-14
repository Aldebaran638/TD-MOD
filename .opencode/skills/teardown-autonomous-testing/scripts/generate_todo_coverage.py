#!/usr/bin/env python3
"""Build CM2 verification contracts and a read-only report from the Todo SSOT."""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
from typing import Any

from validate_contract import validate


PROFILE_ORDER = [
    "STATIC", "FIXTURE", "SCENE", "REAL_INPUT", "TELEMETRY",
    "VISUAL", "LOG", "MULTIPLAYER", "CONSUMER_MOD",
]
RUNTIME = {"SCENE", "REAL_INPUT", "TELEMETRY", "VISUAL", "LOG", "MULTIPLAYER"}
NEEDS_REGRESSION = {
    "Step 8.3", "Step 8.4", "Step 8.5", "Step 8.6",
    "Step 9.1", "Step 9.2", "Step 9.5", "Step 9.6",
    "Step 10.2", "Step 10.3", "Step 10.4", "Step 10.5",
}
STAGE_SCENARIOS = {
    0: "smoke/s0_entry_lifecycle",
    1: "compiler/four_vertical_slices",
    2: "presentation/s5_budget_pressure",
    3: "catalog/s1_definition_parity",
    4: "multiplayer/two_ship_two_context",
    5: "battlefield/s2_s3_s4_density",
    6: "lifecycle/s6_entity_graph_cleanup",
    7: "turret/known_arc_target",
    8: "creator/disposable_preview",
    9: "consumer/clean_room_mod",
    10: "consumer/ai_candidate_preview",
    11: "release/s0_s8_golden",
}


def _stage(step_id: str) -> int:
    return int(step_id.split()[1].split(".")[0])


def profiles(step_id: str, title: str) -> list[str]:
    stage = _stage(step_id)
    result: set[str] = {"STATIC", "FIXTURE"}
    if stage == 0:
        result = {"STATIC"} if step_id in {"Step 0.2", "Step 0.5"} else {"STATIC", "SCENE", "TELEMETRY", "LOG"}
        if step_id in {"Step 0.1", "Step 0.3"}:
            result |= {"REAL_INPUT", "VISUAL"}
    elif stage == 1:
        if step_id in {"Step 1.5", "Step 1.7"}:
            result |= {"SCENE", "TELEMETRY", "LOG"}
    elif stage == 2:
        result |= {"SCENE", "TELEMETRY", "LOG"}
        if step_id != "Step 2.2":
            result.add("VISUAL")
        if step_id in {"Step 2.1", "Step 2.5", "Step 2.6", "Step 2.7", "Step 2.8"}:
            result.add("REAL_INPUT")
    elif stage == 3:
        result |= {"SCENE", "TELEMETRY", "LOG"}
        if step_id in {"Step 3.1", "Step 3.2", "Step 3.3", "Step 3.4"}:
            result.add("VISUAL")
        if step_id in {"Step 3.2", "Step 3.4"}:
            result.add("REAL_INPUT")
    elif stage == 4:
        result |= {"SCENE", "TELEMETRY", "LOG", "MULTIPLAYER"}
        if step_id in {"Step 4.1", "Step 4.2", "Step 4.3", "Step 4.4", "Step 4.6"}:
            result.add("REAL_INPUT")
        if step_id in {"Step 4.1", "Step 4.3", "Step 4.4"}:
            result.add("VISUAL")
    elif stage == 5:
        result |= {"SCENE", "TELEMETRY", "LOG"}
        if step_id in {"Step 5.3", "Step 5.4", "Step 5.5", "Step 5.6", "Step 5.7"}:
            result.add("VISUAL")
    elif stage == 6:
        result |= {"SCENE", "TELEMETRY", "VISUAL", "LOG"}
        if step_id in {"Step 6.4", "Step 6.7"}:
            result.add("REAL_INPUT")
    elif stage == 7:
        result |= {"SCENE", "TELEMETRY", "VISUAL", "LOG"}
        if step_id in {"Step 7.4", "Step 7.7"}:
            result.add("REAL_INPUT")
        if step_id == "Step 7.4":
            result.add("MULTIPLAYER")
    elif stage == 8:
        if step_id in {"Step 8.3", "Step 8.4", "Step 8.5", "Step 8.6"}:
            result |= {"SCENE", "REAL_INPUT", "VISUAL", "LOG"}
    elif stage == 9:
        if step_id in {"Step 9.1", "Step 9.2", "Step 9.3", "Step 9.5", "Step 9.6", "Step 9.7", "Step 9.8"}:
            result.add("CONSUMER_MOD")
        if step_id in {"Step 9.3", "Step 9.7", "Step 9.8"}:
            result |= {"SCENE", "TELEMETRY", "VISUAL", "LOG"}
        if step_id in {"Step 9.3", "Step 9.8"}:
            result.add("REAL_INPUT")
        if step_id == "Step 9.7":
            result.add("MULTIPLAYER")
    elif stage == 10:
        if step_id != "Step 10.1":
            result.add("CONSUMER_MOD")
            result |= {"SCENE", "VISUAL", "LOG"}
        if step_id in {"Step 10.2", "Step 10.3", "Step 10.4", "Step 10.6"}:
            result |= {"REAL_INPUT", "TELEMETRY"}
    elif stage == 11:
        result |= {"CONSUMER_MOD", "SCENE", "TELEMETRY", "VISUAL", "LOG"}
        if step_id in {"Step 11.2", "Step 11.3", "Step 11.6"}:
            result.add("MULTIPLAYER")
        if step_id in {"Step 11.1", "Step 11.2", "Step 11.6"}:
            result.add("REAL_INPUT")
    return [item for item in PROFILE_ORDER if item in result]


def eyes(selected: list[str]) -> list[str]:
    result = []
    if "TELEMETRY" in selected:
        result.append("EYE_TELEMETRY")
    if "VISUAL" in selected:
        result.append("EYE_SCREENSHOT")
    if "LOG" in selected:
        result.append("EYE_LOG")
    return result


def hands(selected: list[str]) -> list[str]:
    result = []
    if "REAL_INPUT" in selected:
        result.append("HAND_REAL_INPUT")
    if {"FIXTURE", "SCENE", "CONSUMER_MOD"}.intersection(selected):
        result.append("HAND_TEST_SETUP")
    return result


def _automation(step_id: str, title: str, selected: list[str]) -> tuple[str, list[str]]:
    stage = _stage(step_id)
    text = title.lower()
    gaps: list[str] = []
    if "MULTIPLAYER" in selected:
        gaps.append(
            "Harness can enumerate Host/Client and control Host, but Client foreground input, screenshot, and per-client telemetry are not yet reliable."
        )
    if step_id == "Step 0.4" or stage == 5 or step_id == "Step 11.3":
        gaps.append(
            "Authoritative frame-time, GC, query, and allocation telemetry must be completed and baselined before the performance claim is fully automatic."
        )
    if gaps:
        return "PARTIAL_AUTO", gaps
    visual_review_words = (
        "presentation", "effect", "表现", "audio", "preview", "editor", "wizard",
        "vox", "3d", "视觉", "特效", "炮塔", "ship dock",
    )
    if "VISUAL" in selected and any(word in text for word in visual_review_words):
        return "AUTO_WITH_VISUAL_REVIEW", [
            "AI owns objective visibility, count, clipping, alignment, and budget checks; subjective visual quality remains a human review."
        ]
    return "FULL_AUTO", []


def verification_status(task: dict[str, Any]) -> tuple[str, str]:
    implementation = task.get("implementation_status", task.get("status", "not_started"))
    if implementation == "finish" and task["id"] in NEEDS_REGRESSION:
        return (
            "needs_regression",
            "Implementation completion is retained, but evidence predates the autonomous policy or explicitly deferred a now-required live, multiplayer, visual, or consumer-path assertion.",
        )
    if implementation == "finish":
        return (
            "verified",
            "Existing static/fixture evidence satisfies the current contract; rerun the listed regression when an adjacent authority changes.",
        )
    return (
        "pending",
        "Implementation status is preserved. Run this embedded contract before changing implementation status; historical missing-Teardown assumptions must be reassessed with the current Harness.",
    )


def _stage_detail(stage: int) -> dict[str, Any]:
    base = {
        "setup": "Use versioned valid/invalid fixtures in an isolated output directory; do not mutate the last valid generated artifact.",
        "trigger": "Run the owning checker or fixture twice and compare deterministic output plus structured diagnostics.",
        "state": "Valid input is deterministic; invalid, missing, future, duplicate, or out-of-range input fails closed with stable field diagnostics.",
        "reload": ("NONE", "Static and fixture execution does not load Teardown."),
        "regression": "Entry closure, source-of-truth, schema/compiler/catalog, and affected definition suites.",
        "evidence": "Contract result, fixture inputs, command trace, structured diagnostics, hashes, and full Harness output.",
    }
    if stage in {2, 3}:
        base.update(
            setup="Build a legacy/candidate pair and a deterministic two-ship scene containing only the affected definitions and presentation paths.",
            trigger="Run parity first, reload the scene, then issue only the minimum real fire or preview input required by the behavior.",
            state="Compiled identity and legacy semantic golden match or have an approved diff; no legacy/candidate double authority appears.",
            reload=("F4_TO_F5_OR_REOPEN_LEVEL_XML", "Use F4→F5 for Lua and reopen the level XML for catalog/entity placement changes."),
            regression="Four vertical slices, the 109-weapon snapshot, presentation sequence/generation guards, and legacy fallback.",
            evidence="Compiler/parity reports, telemetry chain, budget counters, screenshots, incremental log, and Harness.",
        )
    elif stage == 4:
        base.update(
            setup="Use two pre-placed ships in two contexts with one identified Host and at least one Client; freeze owner, capability, generation, and command sequence.",
            trigger="Start official local multiplayer; send one minimal real command from the owner and one invalid or non-owner command.",
            state="Only Host authority mutates world state; rejected commands stay inert; Host and Client converge without duplicate effects, damage, or stale resurrection.",
            reload=("RESTART_MOD_SESSION", "Terminate and relaunch every teardown_modtest Host/Client instance after multiplayer runtime changes."),
            regression="Single-player authority, presentation order, registry lifecycle, reconnect, and late join where claimed.",
            evidence="Per-window PID/HWND, Host/Client action and event traces, screenshots, logs, cleanup counts, and Harness.",
        )
    elif stage == 5:
        base.update(
            setup="Construct seeded low/high-density battlefield fixtures with fixed ships, projectiles, cells, mounts, targets, and budgets; never fly to create load.",
            trigger="Run identical seeded actions at baseline and pressure scale and collect authoritative counts and timings.",
            state="Selection, hit, and collision semantics remain equal while stores and queries stay bounded; no P×S fallback, stale handle, or unbounded allocation remains.",
            reload=("F4_TO_F5_OR_REOPEN_LEVEL_XML", "Use F4→F5 for runtime Lua and reopen XML when density or placement changes."),
            regression="Direct/guided/PD/interceptor collision golden, lifecycle cleanup, and S0–S8 performance baselines.",
            evidence="Seed/config, telemetry counters, before/after p95/p99 samples, hit traces, screenshots, logs, and Harness.",
        )
    elif stage == 6:
        base.update(
            setup="Use pre-placed single-body and minimal multi-body/joint fixtures with named parts and anchors, fixed transforms, and bounded spawn/dispose repetitions.",
            trigger="Resolve anchors, use one real move/fire/enter action only where it is under test, then spawn and dispose the graph.",
            state="Stable entity/part identity and parent-local transforms resolve within tolerance; every body, joint, anchor, and registry item disposes exactly once.",
            reload=("REOPEN_LEVEL_XML_OR_F4_TO_F5", "Reopen XML for graph/prefab changes and use F4→F5 for resolver Lua."),
            regression="Existing single-body ships, muzzle/effect/camera anchors, damage, and lifecycle cleanup.",
            evidence="Graph snapshot, transform tolerance report, lifecycle events, screenshots, logs, and Harness.",
        )
    elif stage == 7:
        base.update(
            setup="Pre-place a turret and target at known azimuth, elevation, and range, including limit, LOD, and joint-budget boundary fixtures.",
            trigger="Run solver golden, then issue only the real aim/fire action required; repeat in Host/Client contexts when network authority is claimed.",
            state="Angles, limits, and convergence match tolerance; actuator follows logical state; muzzle and hit align; sequence is monotonic and fallback respects budget.",
            reload=("REOPEN_LEVEL_XML_OR_RESTART_MOD_SESSION", "Reopen turret XML, F4→F5 solver Lua, and relaunch multiplayer for network changes."),
            regression="Fixed mounts, anchor resolver, projectile/hit chain, LOD, joint budget, and multiplayer ownership.",
            evidence="Solver vectors, telemetry angles/owners/hits, screenshots, budget metrics, logs, and Harness.",
        )
    elif stage == 8:
        base.update(
            setup="Use read-only source assets and disposable editor/preview projects covering valid, invalid, mirrored, and round-trip cases.",
            trigger="Import, build, edit, or wizard-generate twice; validate output; then open the generated artifact in its deterministic preview scene.",
            state="Source remains unchanged; output is deterministic and cache-correct; schema, axes, anchors, and mounts round-trip without runtime catalog mutation.",
            reload=("NONE_OR_REOPEN_LEVEL_XML", "Tool-only work needs no Teardown reload; reopen XML for an in-game preview artifact."),
            regression="Asset manifest/provenance, compiler/schema, VOX orientation, anchors, and preview budgets.",
            evidence="Source/output hashes, generated definitions, UI action trace, preview screenshot/log, and Harness.",
        )
    elif stage == 9:
        base.update(
            setup="Build a clean-room disposable consumer Mod/package that uses only the published manifest, SDK, schema, or broker surface and no private CM2 include.",
            trigger="Build/install twice, reopen Mod Manager, start the consumer, and invoke one valid plus one invalid public operation.",
            state="Dependencies, versions, and capabilities are explicit; compatible use succeeds; incompatible use fails closed; release hashes match the manifest.",
            reload=("REOPEN_MOD_MANAGER_OR_RESTART_MOD_SESSION", "Reopen Mod Manager for new/metadata Mods and restart the Mod session for runtime changes."),
            regression="Basic consumer fixture, clean-room package, compatibility matrix, Core-only build, and exact rollback.",
            evidence="Consumer source, package manifest/hash, install/start trace, telemetry/screenshot/log where runtime applies, and Harness.",
        )
    elif stage == 10:
        base.update(
            setup="Use a fixed AI evaluation corpus and disposable consumer output with undeclared network, filesystem, generated, Core, and runtime writes denied.",
            trigger="Generate twice from identical input, run provenance/schema/policy checks, then preview and package only the accepted candidate through production tools.",
            state="Normalized output is deterministic and attributable; no path escape, private code, arbitrary Lua, renderer, or budget bypass occurs.",
            reload=("NONE_OR_REOPEN_PREVIEW", "Generation is engine-free; reopen Mod Manager or level XML only for consumer preview."),
            regression="AI negative corpus, compiler/schema, asset provenance, package security, and Core semantic invariance.",
            evidence="Prompt/input/provider hashes, normalized diff, validator result, consumer preview screenshot/log, and Harness.",
        )
    elif stage == 11:
        base.update(
            setup="Use immutable release candidates and independent consumer Mods for baseline, upgrade, rollback, S0–S8, and required soak topologies.",
            trigger="Run every gate from a clean install, execute live single-player and required Host/Client scenarios, then repeat after upgrade and exact rollback.",
            state="All component and negative gates pass; live samples are not fixtures; package/save compatibility and exact rollback hashes hold; missing evidence remains no-go.",
            reload=("RESTART_TEARDOWN_AND_MOD_SESSION", "Restart Teardown between immutable package versions and restart all multiplayer processes for each topology."),
            regression="Golden packages, S0–S8, lifecycle/save soak, p95/p99 budgets, clean-room consumers, upgrade/rollback, support, and security gates.",
            evidence="Immutable hashes, machine identity, live telemetry/screenshots/logs/replays, per-gate reports, sign-off, and Harness.",
        )
    return base


def _telemetry_assertions(title: str, selected: list[str]) -> list[str]:
    if "TELEMETRY" not in selected:
        return []
    text = title.lower()
    result = ["Snapshot and events use one fresh CM2_TEST_V1 session; cursor continuation has no unexplained gap or duplicate."]
    if any(word in text for word in ("weapon", "武器", "projectile", "弹丸", "guided", "炮塔", "point defense", "interceptor")):
        result.append("The real path reaches the applicable ordered boundaries: input_edge/fire_request → weapon_released → hit → damage_applied → hp_changed; omitted boundaries require a weapon-specific explanation.")
    if any(word in text for word in ("lifecycle", "销毁", "死亡", "cleanup", "dispose", "entitygraph", "vehicle")):
        result.append("Registration and lifecycle reach a terminal ship_destroyed → ship_unregistered → ship_cleanup or the task's documented equivalent exactly once.")
    if "MULTIPLAYER" in selected:
        result.append("Host/Client source, player, owner, generation, and sequence are explicit and converge without duplicate authority mutation.")
    if any(word in text for word in ("anchor", "transform", "body", "joint", "turret", "移动", "坐标")):
        result.append("Authoritative transforms, linear/angular velocity, owner, and registered state match the deterministic fixture within its numeric tolerance.")
    return result


def _visual_assertions(title: str, selected: list[str]) -> list[str]:
    if "VISUAL" not in selected:
        return []
    text = title.lower()
    result = ["A timestamped client-area screenshot proves the expected page, scene, HUD, or production presentation is visible and not black/constant."]
    if any(word in text for word in ("weapon", "武器", "projectile", "弹丸", "炮塔")):
        result.append("Muzzle/beam/projectile/impact appears once at the authoritative anchor and target without obvious clipping or duplicate legacy playback.")
    if any(word in text for word in ("editor", "wizard", "preview", "3d", "vox")):
        result.append("The generated asset/editor surface opens through the real UI path and shows the expected orientation, scale, anchors, controls, and diagnostics.")
    return result


def build_contract(task: dict[str, Any]) -> dict[str, Any]:
    step_id = task["id"]
    title = task["title"]
    selected = profiles(step_id, title)
    stage = _stage(step_id)
    detail = _stage_detail(stage)
    setup_description = detail["setup"]
    if stage == 0 and step_id in {"Step 0.1", "Step 0.3"}:
        setup_description = "Load the formal CM2 entry and a disposable S0/S6/S7 smoke level with telemetry enabled; preserve a pre-run log cursor."
    forbidden = ["Test setup may establish initial conditions but may not invoke the behavior under test directly."]
    if any(word in title.lower() for word in ("weapon", "武器", "projectile", "弹丸", "炮塔")):
        forbidden.append("damage_probe may isolate damage core but cannot prove weapon release, collision, hit, or presentation.")
    if "MULTIPLAYER" in selected:
        forbidden.append("A single-process fixture or Host-only trace cannot prove Client replication, ownership, reconnect, or late join.")
    if "CONSUMER_MOD" in selected:
        forbidden.append("CM2 calling its own private API cannot prove an external public contract; use an independent disposable Mod/package.")
    automation_level, automation_gaps = _automation(step_id, title, selected)
    reload_mode, reload_reason = detail["reload"]
    if RUNTIME.intersection(selected) and reload_mode == "NONE":
        if stage == 0:
            reload_mode = "RESTART_MOD_SESSION_OR_REOPEN_LEVEL_XML"
            reload_reason = "Restart the Mod session for entry/runtime changes and reopen the level XML when scene placement changes."
        elif stage == 1:
            reload_mode = "F4_TO_F5_OR_REOPEN_LEVEL_XML"
            reload_reason = "Use F4→F5 for Lua and reopen the level XML for generated catalog placement changes."
    trigger = [detail["trigger"]]
    scope = " ".join(str(item) for item in task.get("implementation_scope", []) if str(item).strip())
    if scope:
        trigger.insert(0, f"Exercise the minimum operation that proves this exact implementation scope: {scope}")
    if "REAL_INPUT" in selected:
        trigger.append("Use a fresh frame_id/target_id and the minimum real keyboard or mouse action; record the action trace and release input afterward.")
    if "MULTIPLAYER" in selected and "Host" not in setup_description:
        setup_description += " Include one identified Host and at least one identified Client."
    if "CONSUMER_MOD" in selected and "Mod" not in setup_description:
        setup_description += " Use an independent disposable consumer Mod."
    cleanup = ["Dispose temporary fixtures and preserve the formal source plus last valid generated authority."]
    if RUNTIME.intersection(selected):
        cleanup += [
            "Release every tracked key/button with emergency release and confirm the held-input set is empty.",
            "Confirm the next session contains no stale scenario entities, registrations, cursors, or events.",
        ]
    if "MULTIPLAYER" in selected:
        cleanup.append("Terminate every test Host/Client child instance and re-enumerate processes to prove no multiplayer process remains.")
    state_assertions = [
        task.get("expected_outcome", "The task's expected outcome is satisfied."),
        *task.get("acceptance_criteria", []),
        detail["state"],
    ]
    plan_source = {
        "id": step_id,
        "title": title,
        "task_goal": task.get("task_goal"),
        "expected_outcome": task.get("expected_outcome"),
        "prerequisites": task.get("prerequisites"),
        "implementation_scope": task.get("implementation_scope"),
        "acceptance_criteria": task.get("acceptance_criteria"),
    }
    plan_fingerprint = hashlib.sha256(
        json.dumps(plan_source, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    contract = {
        "schema": "cm2.verification-contract/2",
        "plan_fingerprint": plan_fingerprint,
        "task": f"{step_id}: {title}",
        "behavior_under_test": task.get("expected_outcome", title),
        "profiles": selected,
        "eyes": eyes(selected),
        "hands": hands(selected),
        "setup": {
            "description": setup_description,
            "fixture": STAGE_SCENARIOS[stage] if "SCENE" in selected else "engine_free/versioned_fixture" if "FIXTURE" in selected else "none",
            "determinism": "Use fixed IDs, transforms, velocities, HP/loadout/budgets, seed, and version hashes wherever those fields apply.",
            "forbidden_shortcuts": forbidden,
        },
        "reload": {
            "mode": reload_mode,
            "reason": reload_reason,
            "session_reset_expected": bool(RUNTIME.intersection(selected)),
        },
        "trigger": trigger,
        "telemetry_assertions": _telemetry_assertions(title, selected),
        "state_assertions": state_assertions,
        "visual_assertions": _visual_assertions(title, selected),
        "log_assertions": [
            "No new in-scope Lua, engine, protocol, or resource ERROR appears after the baseline byte cursor; every warning is attributed."
        ] if "LOG" in selected else [],
        "cleanup_assertions": cleanup,
        "regression": [detail["regression"]],
        "evidence": [detail["evidence"]],
        "automation_level": automation_level,
        "automation_gaps": automation_gaps,
    }
    issues = validate(contract)
    if issues:
        raise ValueError(f"invalid generated contract for {step_id}: {issues}")
    return contract


def report(todo: dict[str, Any]) -> str:
    tasks = todo.get("tasks", [])
    impl = Counter(task["implementation_status"] for task in tasks)
    verify = Counter(task["verification_status"] for task in tasks)
    automation = Counter(task["verification"]["automation_level"] for task in tasks)
    profiles_index: dict[str, list[str]] = defaultdict(list)
    for task in tasks:
        for profile in task["verification"]["profiles"]:
            profiles_index[profile].append(task["id"])
    lines = [
        "# CM2 executable 80-Step verification report",
        "",
        "Generated from the authoritative `TEARDOWN_SHIP_PLATFORM_TODO.json` (`cm2.todo/2`). This Markdown is a read-only view; edit the root Todo, not this file.",
        "",
        f"Total: {len(tasks)}",
        "",
        "- Implementation: " + "; ".join(f"{key}={impl.get(key, 0)}" for key in todo["allowed_implementation_statuses"]),
        "- Verification: " + "; ".join(f"{key}={verify.get(key, 0)}" for key in todo["allowed_verification_statuses"]),
        "- Automation: " + "; ".join(f"{key}={automation.get(key, 0)}" for key in todo["allowed_automation_levels"]),
        "",
        "## Profile index",
        "",
    ]
    for profile in PROFILE_ORDER:
        ids = profiles_index.get(profile, [])
        lines.append(f"- `{profile}` ({len(ids)}): {', '.join(ids) if ids else 'none'}")
    lines += ["", "## Step contracts", ""]
    for task in tasks:
        contract = task["verification"]
        lines += [
            f"### {task['id']} — {task['title']}",
            "",
            f"- Implementation: `{task['implementation_status']}`",
            f"- Verification: `{task['verification_status']}` — {task['verification_status_reason']}",
            f"- Automation: `{contract['automation_level']}`",
            f"- Profiles: `{' + '.join(contract['profiles'])}`",
            f"- Eyes: `{' + '.join(contract['eyes']) if contract['eyes'] else 'none'}`",
            f"- Hands: `{' + '.join(contract['hands']) if contract['hands'] else 'none'}`",
            f"- Setup: {contract['setup']['description']}",
            f"- Trigger: {' '.join(contract['trigger'])}",
            f"- Reload: `{contract['reload']['mode']}` — {contract['reload']['reason']}",
            f"- State assertions: {' '.join(contract['state_assertions'])}",
            f"- Telemetry: {' '.join(contract['telemetry_assertions']) if contract['telemetry_assertions'] else 'not required'}",
            f"- Visual: {' '.join(contract['visual_assertions']) if contract['visual_assertions'] else 'not required'}",
            f"- Log: {' '.join(contract['log_assertions']) if contract['log_assertions'] else 'not required'}",
            f"- Cleanup: {' '.join(contract['cleanup_assertions'])}",
            f"- Regression: {' '.join(contract['regression'])}",
            f"- Evidence: {' '.join(contract['evidence'])}",
        ]
        if contract["automation_gaps"]:
            lines.append(f"- Automation gaps: {' '.join(contract['automation_gaps'])}")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("todo", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    todo = json.loads(args.todo.read_text(encoding="utf-8-sig"))
    if todo.get("schema_version") != "cm2.todo/2":
        raise SystemExit("expected authoritative cm2.todo/2 plan")
    if todo.get("task_count") != 80 or len(todo.get("tasks", [])) != 80:
        raise SystemExit("expected authoritative 80-Step plan")
    args.output.write_text(report(todo).rstrip() + "\n", encoding="utf-8", newline="\n")
    print(f"wrote read-only report {args.output}: {len(todo['tasks'])} Steps")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
