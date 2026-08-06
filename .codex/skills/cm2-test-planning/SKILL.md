---
name: cm2-test-planning
description: Plan, implement, and record future Content Mod 2 tests. Use when the user says "我要做一个...测试", asks to plan test coverage, add a regression test, design a fixture, or record a future CM2 testing direction.
---

# CM2 Test Planning

Read `Content Mod 2/docs/testing-notes.md` before planning or adding tests. Use
the existing check scripts and self-tests as the primary test surfaces.

## Workflow

1. Identify the behavior, affected runtime layer, and observable acceptance
   criteria. Inspect the existing checker and self-test before proposing a new
   test surface.
2. Add the scenario to the testing note with its risk and intended coverage.
   Keep completed cases marked with the checker or test that owns them.
3. Prefer a focused fixture mutation in the corresponding `test-check-*.ps1`
   self-test when the behavior has a static contract. Use product-level or
   manual gameplay validation for physics, networking order, and visual FX.
4. Do not weaken a checker, fixture, or harness to accept product behavior.
   Fix product code when it violates a current contract. If the contract is
   obsolete, report the mismatch and request explicit approval before changing
   validation infrastructure.
5. After product changes, run the required CM2 checks listed in `AGENTS.md`.

## Output

State the scenario, test level, setup, action, expected result, automation
owner, and remaining manual validation. Update the note when a direction is
added, implemented, superseded, or blocked.
