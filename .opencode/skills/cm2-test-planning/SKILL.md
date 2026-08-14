---
name: cm2-test-planning
description: Plan, implement, and record future Content Mod 2 tests. Use when the user says "我要做一个...测试", asks to plan test coverage, add a regression test, design a fixture, or record a future CM2 testing direction.
---

# CM2 Test Planning

Read the target task in authoritative `TEARDOWN_SHIP_PLATFORM_TODO.json` first,
then read `Content Mod 2/docs/testing-notes.md` for reusable directions. The
Todo's embedded `cm2.verification-contract/2` is the executable Step fact;
testing notes must not duplicate or override it. Use existing check scripts and
self-tests as the primary headless surfaces.

## Workflow

1. Identify the behavior, affected runtime layer, and observable acceptance
   criteria. Inspect the existing checker and self-test before proposing a new
   test surface.
2. Update the target Step's embedded contract: Profiles, Eyes, Hands, setup,
   reload, trigger, assertions, cleanup, regression, evidence and automation
   level. Validate the entire plan with
   `.codex/skills/teardown-autonomous-testing/scripts/validate_todo_plan.py`.
   Add only reusable cross-Step directions to the testing note.
3. Prefer a focused fixture mutation in the corresponding `test-check-*.ps1`
   self-test when the behavior has a static contract. Use product-level or
   manual gameplay validation for physics, networking order, and visual FX.
4. Do not weaken a checker, fixture, or harness to accept product behavior.
   Fix product code when it violates a current contract. If the contract is
   obsolete, report the mismatch and request explicit approval before changing
   validation infrastructure.
5. After product changes, run the required CM2 checks listed in `AGENTS.md`.

## Output

State the Step ID, scenario, profiles, Eyes/Hands, setup, minimum action,
assertions, reload, automation owner/gap, regression and evidence. Keep
`implementation_status` independent from `verification_status`; an old finished
Step that lacks current evidence becomes `needs_regression`, not unfinished.
