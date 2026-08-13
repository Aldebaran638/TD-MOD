# Minimal multi-body/joint fixture v1 (Step 6.5)

This fixture is deliberately not a production turret. It is a small, opt-in
DTO lifecycle contract used before VehicleFactory and formal Joint content are
allowed:

- one root body (`root`) and one child body (`pod`);
- one `pod-yaw` joint with an explicit axis and `[-45°, +45°]` limit;
- deterministic spawn, tick, child disposal, parent disposal and idempotent
  disposal;
- a generation/owner-tagged network snapshot with
  `cm2.multi-body-joint-fixture-snapshot/1` and an explicit
  `formal-turret-rejected` policy.

`cm2MultiBodyJointFixtureV1` validates exactly one root, missing/cyclic parents,
joint endpoints, self-joints, duplicate IDs and inverted limits. It marks
dependent joints inactive when a body is disposed and exposes body/joint counts,
ticks, snapshots and rejection counters. `promoteFormalTurret` always rejects
in v1 so no player-facing turret can accidentally depend on this experiment.

`run-multi-body-joint-fixture-v1.ps1` and its self-test exercise spawn/update,
network snapshots, child and parent disposal, idempotence, stale generation,
missing parent and inverted-limit negatives. No engine Body/Joint creation is
performed; live joint solver cost, parent destruction timing and S7 runtime
serialization remain pending until Teardown is available.

Rollback is removal of this standalone fixture or bypassing its adapter. It has
no production content dependency and must not change the existing single-Body
ship path.
