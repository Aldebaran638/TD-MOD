# Continuous Performance Regression Gate v1

## Contract

The gate treats performance as versioned release data. Related Runtime pull requests run the relevant S0–S8 slices; milestone and nightly jobs run every slice plus the pressure and lifecycle Soak suites. Unless an approved tradeoff exists, p95 regression is capped at 5% and p99 at 10%. Query count, active entities, budget rejects, queue depth, network bytes and memory slope are first-class metrics.

The gate evaluates every sample, reports variance, and stops when relative standard deviation exceeds 20%; it never chooses the best trial. Any hard-cap increase blocks promotion. A budget change requires the ADR, reference hardware, and before/after replay paths in the policy.

## Run

    .\tools\cm2-perf\check-performance-regression-gate-v1.ps1
    .\tools\cm2-perf\run-performance-regression-gate-v1.ps1
    .\tools\cm2-perf\test-performance-regression-gate-v1.ps1

The result is written to `docs/candidates/performance-regression-gate-v1.result.json`. The current fixture is a deterministic headless candidate: all seven metrics and S0–S8 suites pass, but live Teardown timing, hardware identity, nightly pressure, and replay evidence are deferred because `Teardown.exe` is unavailable. This is reported as `unable`, not `pass`.

## Rollback

Restore the previous baseline and budget, keep the failing report/replay, and revert unapproved budget changes. Temporary exceptions must name an owner, expiry and follow-up ADR.
