# ADR: Performance Budget v1

## Decision

Content Mod 2 treats performance as a versioned contract. A Runtime pull request runs the related S0–S8 slices; milestones and nightly jobs run every slice plus pressure and Soak. Unless an approved tradeoff is attached, p95 may regress by at most 5% and p99 by at most 10%. Query count, active entities, budget rejects, queue depth, network bytes and memory slope are recorded alongside frame time.

## Measurement policy

The gate compares all samples from a fixed baseline and candidate run. It never selects the best trial. If relative standard deviation exceeds 20%, the gate stops and requires the scenario to be repaired before a performance conclusion. Budget changes require this ADR, reference hardware, and before/after replay evidence.

The current headless fixture is a deterministic contract fixture, not live hardware evidence. Teardown runtime, hardware identity and replay files remain required for promotion.

## Rollback

Restore the previous baseline and budget manifest, retain the failing report/replay, and revert any unapproved budget adjustment. A temporary exception must name an owner, expiry and follow-up ADR.
