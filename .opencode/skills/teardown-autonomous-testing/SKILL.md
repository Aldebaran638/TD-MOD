---
name: teardown-autonomous-testing
description: Autonomously plan, operate, verify, diagnose, reload, and regress-test the Teardown Content Mod 2 framework. Use for any CM2 runtime, weapon, damage, ship, input, movement, lifecycle, multiplayer, loadout, public API, presentation, UI, VFX, strike-craft, cloak, battlefield, registration, networking, Todo Step, bug-fix, regression, validation, test, or "确认是否正常" task.
---

# Teardown Autonomous Testing & Operation

Use this skill to close the loop from code change to authoritative live evidence. Never mark a behavior complete merely because code compiles or looks plausible.

## Non-negotiable policy

1. For a planned Todo Step, use its embedded `cm2.verification-contract/2` in the authoritative root `TEARDOWN_SHIP_PLATFORM_TODO.json`; validate it before implementation. A standalone one-off contract may still use backward-compatible `cm2.verification-contract/1`. Classify with one or more profiles: `STATIC`, `FIXTURE`, `SCENE`, `REAL_INPUT`, `TELEMETRY`, `VISUAL`, `LOG`, `MULTIPLAYER`, `CONSUMER_MOD`.
2. Setup may cheat; behavior under test may not. Pre-place ships, aim them, zero velocity, select loadouts, set HP and ready cooldowns. If firing is under test, still use real LMB and require the real weapon runtime chain. If movement is under test, still use real movement input.
3. Use each evidence source only for facts it owns:
   - telemetry: authoritative gameplay state and event boundaries;
   - screenshot: visual/UI/current-page facts;
   - log: runtime health, errors and warnings.
4. A test RPC may prepare state or isolate a core subsystem. It cannot prove the production path it bypasses. `teardown_damage_probe` cannot prove a weapon works and is currently `UNAVAILABLE` in live CM2 until its end-to-end dispatch is repaired and re-verified.
5. Never inject input blindly. Identify state, observe a fresh frame, require exact `frame_id` and `target_id`, then act. Release inputs on every error or handoff.
6. Select the least expensive valid refresh from the verified reload matrix. When uncertain, escalate to the next stronger mode and verify the session/revision changed.
7. A task passes only after its contract assertions, runtime health, cleanup, relevant regression, evidence persistence, and the repository's full Harness all pass.

## Mandatory workflow

1. Read the task, relevant product code, `AGENTS.md`, and existing tests. Read [testing-policy.md](references/testing-policy.md); for runtime work also read [harness.md](references/harness.md).
2. Read or update the Step's embedded `cm2.verification-contract/2` contract. Validate the complete executable plan with:

   ```powershell
   python .\.opencode\skills\teardown-autonomous-testing\scripts\validate_todo_plan.py .\TEARDOWN_SHIP_PLATFORM_TODO.json
   ```

   Use `validate_contract.py` only for a standalone Scenario/one-off contract.
   `build-todo-json.ps1` is a compatibility-named in-place refresher: the root
   JSON is authoritative and the command never rebuilds it from Markdown.

3. Choose the fixture and the minimum real trigger. Prefer an isolated deterministic scenario over manual travel, aiming, or waiting. Read [scenarios.md](references/scenarios.md) when `SCENE` or `CONSUMER_MOD` applies.
4. Implement the smallest in-scope change. Do not add a new MCP/game RPC for each gameplay feature; strengthen observation, scenario setup, or authority-boundary telemetry first.
5. Determine reload mode from [reload-matrix.md](references/reload-matrix.md). Record file revisions in scenario telemetry when testing reload behavior.
6. Identify the current Teardown state using process/window title, screenshot, telemetry session/scenario and incremental log together. Read [teardown-operation.md](references/teardown-operation.md). Do not infer a page from one signal alone when input could be destructive.
7. For a live test, normally run:
   - `teardown_instances` / `teardown_status`;
   - `teardown_observe` to obtain a fresh frame;
   - `teardown_telemetry_probe` and baseline `teardown_telemetry_read`;
   - minimal `teardown_control` actions;
   - incremental telemetry, screenshot and log;
   - `teardown_emergency_release` in `finally`-style cleanup.
8. Compare evidence to the contract. On failure, locate the first missing or inconsistent authority boundary using [diagnostics.md](references/diagnostics.md); change code, reload and rerun the same contract.
9. Run targeted regression, then the repository's `$check` skill / `./harness/check-all.ps1`. Validate extra Mod script/XML roots separately because `check-all` targets CM2.
10. Persist the result and only then mark the task complete. A final report must distinguish `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`, and `NEEDS REGRESSION`.

## Evidence authority

The three eyes and two hands are intentionally asymmetric:

- Structured telemetry is the primary truth for player, camera, input, ship registry, transforms, velocities, layered HP, damage, destruction and cleanup. Its protocol is `CM2_TEST_V1`; see [harness.md](references/harness.md).
- Screenshot proves only what is visible: menu/editor/running state, HUD/UI, beam/projectile/impact/explosion/smoke, camera and clipping. It does not prove HP, hit layer, registration or cleanup.
- Runtime log proves new Lua/engine errors and warnings from a byte cursor. `DebugPrint` is not assumed to reach `log.txt`.
- Real HID keyboard/mouse proves player-facing input chains.
- Restricted test control proves only the isolated subsystem named by its contract.

## Runtime completion gates

A gameplay claim needs, unless the contract explains why not:

- deterministic setup identity and revision;
- fresh telemetry session and baseline;
- exact real input/action trace when player input matters;
- expected authoritative event/state delta;
- relevant screenshot;
- incremental log with no new in-scope errors;
- destroyed/unregistered entities and held inputs cleaned up;
- saved evidence under `%LOCALAPPDATA%\TeardownAI\runs\<run-id>\`;
- relevant regression plus full Harness.

If visual taste is the only remaining question, report the objective facts and leave the subjective decision to the human.

## Reference routing

- Tool signatures, limits, telemetry fields, transport and evidence files: [harness.md](references/harness.md)
- Start/editor/play/menu/state recognition/recovery: [teardown-operation.md](references/teardown-operation.md)
- Minimum safe refresh by changed artifact: [reload-matrix.md](references/reload-matrix.md)
- Profiles, contracts, completion policy and tool misuse rules: [testing-policy.md](references/testing-policy.md)
- Scenario and external consumer fixtures: [scenarios.md](references/scenarios.md)
- Event-chain breakpoints and failure recovery: [diagnostics.md](references/diagnostics.md)
- Host/client startup, targeting, evidence and teardown: [multiplayer.md](references/multiplayer.md)
- Reproducible experiments that established this manual: [experiments.md](references/experiments.md)
- Read-only report generated from the executable 80-Step source: [todo-coverage.md](references/todo-coverage.md)
