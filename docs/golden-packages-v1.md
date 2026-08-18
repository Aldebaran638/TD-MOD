# End-to-end Golden Packages v1

## Purpose

This collection is the cross-layer release gate for Content Mod 2. It keeps one versioned set of packages that exercises built-in content, a minimal `hello-ship`, migration from the previous schema, a valid dependency DAG, trusted Expert Behavior, and human-approved AI Weapon/Effect/Ship candidates. The same run also declares stable negative diagnostics for missing dependencies, dependency cycles, duplicate IDs, path traversal, asset hash mismatch, and budget overflow.

## Execution

Run the static contract, runner, and regression test from the repository root:

    .\tools\cm2-golden\check-golden-packages-v1.ps1
    .\tools\cm2-golden\run-golden-packages-v1.ps1
    .\tools\cm2-golden\test-golden-packages-v1.ps1

The runner executes every non-runtime suite headlessly, verifies that `Content Mod 2` and `Global Mod` are unchanged, and writes `docs/candidates/golden-packages-v1.result.json`. The report includes build, migrate, Preview, package, and Runtime stage status for each package, the six negative contracts, a deterministic hash, and rollback instructions.

## Current result

The v1 candidate contains eight package kinds and six negative cases. All headless suites pass and the deterministic hash is stable. Teardown is installed, but live Runtime was not run because the responding target was not the foreground window; the report records Runtime as `not-run` and the official result remains `unable`, not a fabricated pass. A release promotion requires the live Runtime stage to be rerun with a focused Teardown target and the prior Golden set retained until that run passes.

## Rollback

Restore the previous Golden manifest and package set without deleting the last valid artifact. If a package or migration fails, disable promotion, keep the failing fixture for diagnosis, and return to the previous Golden version. Runtime evidence may be added only after the same headless and repository-integrity checks remain green.
