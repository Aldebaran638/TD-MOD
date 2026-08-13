# Formal Platform Release Gate v1

## Decision rule

The final gate evaluates twelve critical checks: third-party clean-room packages, Golden Packages, S0–S8, multiplayer/Save soak, performance p95/p99 and published metrics, upgrade/rollback, entry closure, asset provenance, support documentation, security boundaries/core invariance, and live Runtime/replay/external cohort evidence. Every required check must pass for `go`.

If any critical check is missing or only headless, the decision is `no-go` and the project remains `Framework/Beta`. This is a release decision, not a marketing label: the report records the exact hold reasons, known limitations, next plan, versions/hashes and sign-off state.

## Run

    .\tools\cm2-platform\check-platform-release-gate-v1.ps1
    .\tools\cm2-platform\run-platform-release-gate-v1.ps1
    .\tools\cm2-platform\test-platform-release-gate-v1.ps1

The report is written to `docs/candidates/platform-release-gate-v1.result.json`. The current decision is intentionally `no-go`/`framework-beta`: headless Golden, Soak, performance and migration evidence exists, but Teardown Runtime, three verified external authors, three independent packages, immutable release archives and sign-off do not.

## Required promotion evidence

Acquire a Teardown build and fixed hardware, run Core-only/Golden/S0–S8/multiplayer/Save/upgrade-rollback live, recruit and verify three external authors and three independent packages, publish immutable archives and hashes, and obtain release-owner plus independent-reviewer sign-off. Until then, do not advertise the project as a stable Platform/SDK.

## Rollback

Keep the Framework/Beta manifest and last valid Core artifact. Do not widen compatibility claims. Re-run this gate after each missing evidence item is supplied; if a check regresses, restore the previous artifact and keep the failing report.
