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

Before coding, create JSON with schema `cm2.verification-contract/1` and all of:

- `task`: outcome;
- `behavior_under_test`: exact production behavior;
- `test_profiles`: one or more allowed profiles;
- `setup`: deterministic initial state;
- `trigger`: minimum action, including which actions must be real;
- `expected_telemetry`: ordered/partial boundaries as applicable;
- `expected_state`: numeric/state assertions;
- `expected_visual`: visible assertions or an explicit empty list;
- `expected_log`: forbidden/required runtime lines;
- `cleanup`: entities, sessions and inputs to release;
- `reload_requirement`: selected matrix mode;
- `regression`: old contracts to rerun;
- `evidence`: files/results to retain.

Run `scripts/validate_contract.py`. The validator checks structure and policy consistency, not game correctness.

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
