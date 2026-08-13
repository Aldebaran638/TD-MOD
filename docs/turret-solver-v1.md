# Pure TurretSolver v1 (Step 7.2)

`cm2TurretSolverV1` is deliberately pure logic. It receives a turret definition,
base position/basis and target DTOs, then returns deterministic commands:

- filters alive/hostile/kind/range candidates;
- sorts by priority, distance and target ID for deterministic ties;
- applies optional target velocity lead time;
- calculates yaw around the +Y/right-handed frame and pitch around +X;
- clamps both angles to definition limits and reports raw vs clamped values.

It never reads a Body, Joint, raycast or input state and never writes an aim
command. Every result carries identity/owner/generation. Invalid basis,
co-located targets and stale/foreign handles fail closed with counters.

The fixture selects `projectile-02` over a friendly/dead candidate, clamps a 45°
yaw to 40°, applies one-second lead, rejects a zero basis and rejects a stale
generation. `run-turret-solver-v1.ps1` and its self-test provide deterministic
golden/negative evidence. Runtime joint drives, target visibility and live
performance remain deferred until Teardown is available.

Rollback is to stop calling the solver and keep the fixture-only target/legacy
aim path; do not connect its output to a production Joint before Gate 7 runtime
review.
