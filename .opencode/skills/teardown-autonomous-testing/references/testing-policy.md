# Testing policy and profiles

## Cost-ordered profiles

Use the cheapest combination that actually owns the claim.

| Profile | Use for | Required mechanism |
|---|---|---|
| STATIC | schemas, IDs, folders, resources, contracts, generated catalogs | parser, checker, schema/contract validation |
| FIXTURE | algorithms, state machines, migrations, DTOs, budgets, selection | deterministic engine-free fixtures |
| SCENE | weapons, motion, collision, cloak, boundary, lifecycle | isolated preconstructed Teardown level |
| REAL_INPUT | fire, thrust, aim, switch, UI, camera, hotkeys | Harness keyboard/mouse with fresh frame |
| TELEMETRY | HP, velocity, hits, registry, ownership, destruction, cleanup | `CM2_TEST_V1` snapshot/events |
| VISUAL | VFX, HUD, beam, projectile, smoke, clipping, camera | timestamped screenshot |
| LOG | Lua/engine/protocol runtime health | incremental `log.txt` slice |
| MULTIPLAYER | host/client authority, replication, joining, reconnect | official local test or published online session |
| CONSUMER_MOD | public API, dependency, compatibility, extension | independent disposable Mod |

A full weapon claim normally requires `SCENE + REAL_INPUT + TELEMETRY + VISUAL + LOG`. A DTO migration can be `STATIC + FIXTURE`. Avoid launching Teardown when it cannot improve the claim.

## Verification Contract

For an 80-Step task, use its embedded JSON object with schema `cm2.verification-contract/2` in `TEARDOWN_SHIP_PLATFORM_TODO.json`. A standalone Scenario may retain compatible schema `cm2.verification-contract/1`. Version 2 records all of:

- `task`: outcome;
- `behavior_under_test`: exact production behavior;
- `profiles`: one or more allowed profiles;
- `eyes`: `EYE_TELEMETRY`, `EYE_SCREENSHOT`, and/or `EYE_LOG` exactly matching the evidence profiles;
- `hands`: `HAND_REAL_INPUT` and/or `HAND_TEST_SETUP` exactly matching the trigger/setup profiles;
- `setup`: deterministic initial state, fixture identity, and forbidden shortcuts;
- `reload`: mode, reason, and expected session reset;
- `trigger`: minimum action, including which actions must be real;
- `telemetry_assertions`, `state_assertions`, `visual_assertions`, `log_assertions`;
- `cleanup_assertions`: entities, sessions and inputs to release;
- `regression`: old contracts to rerun;
- `evidence`: files/results to retain.
- `automation_level` and any concrete `automation_gaps`.

Run `scripts/validate_todo_plan.py TEARDOWN_SHIP_PLATFORM_TODO.json`. The validator checks 80-Step identity/order, history, contract structure, Eyes/Hands consistency and stale contract fingerprints; it does not replace gameplay assertions.

## Setup may cheat; behavior may not

Good weapon setup: attacker already faces a stationary registered target, weapon is selected and ready, fixed HP and distance. Trigger one real LMB action and observe the production chain.

Bad weapon proof: call `damage_probe`, observe lower HP, declare weapon success. That proves only damage architecture.

Other invalid substitutions:

- screenshot instead of HP/damage/registry assertions;
- log lines instead of authoritative gameplay state;
- direct state mutation instead of the player input under test;
- internal CM2 calling its own claimed public API instead of a consumer Mod;
- manually flying for minutes when navigation is not under test.

Test injection is allowed only to establish initial conditions or isolate the named core. It must be bounded, nonce-gated, dormant by default, authority-validated and explicitly identified in evidence.

## Completion vocabulary

- `PASS`: every required assertion and cleanup passed with durable evidence.
- `FAIL`: the test ran and contradicted an assertion.
- `BLOCKED`: an external prerequisite prevents running the test; never convert this to pass.
- `NOT RUN`: intentionally skipped with reason.
- `NEEDS REGRESSION`: a formerly completed task lacks evidence demanded by current policy. This is not a retroactive functional failure.

Code completion is not behavior completion. A runtime task needs live evidence; a visual task needs a screenshot; a framework extension claim needs a consumer. Always run relevant regression and full Harness after implementation.

Disable unrelated Global Mods for authoritative regression runs unless their interoperability is part of the contract. If isolation cannot be changed, preserve the exact enabled-Mod list and attribute log lines by source path; never silently ignore third-party noise or charge it to CM2.
