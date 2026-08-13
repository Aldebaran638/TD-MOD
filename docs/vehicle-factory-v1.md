# VehicleFactory v1 (Step 6.6)

`cm2VehicleFactoryV1` is the dynamic lifecycle boundary for future
VehicleInstance creation. It is intentionally DTO-only in this step; engine
Body/Shape/Joint calls remain behind a later runtime adapter. The transaction
stages are fixed and ordered:

`graph → body → shape → joint → mount → runtime`

`spawn` validates factory identity, owner and generation, allocates an instance
identity, and records each stage. A requested failure at any stage emits a
`spawn_failed` event and marks every stage `rolled_back`; no failed instance is
inserted into the registry. A successful transaction emits `spawned`, exposes an
instance handle with instance generation, and supports `legacy`, `shadow`, or
`synthetic` mode. `serverTick`, `validateInstance`, `snapshot`, and bounded
`drainEvents` provide deterministic lifecycle and snapshot surfaces.

`dispose` releases stages in reverse order, marks the instance disposed, emits a
`disposed` event, and is idempotent on repeat calls. `disposeAll` supports scene
reload/owner teardown. Diagnostics expose active/total counts, peak, stage
failures, rollbacks, stale/owner rejects, event drops and resource state. The
ship and strike-craft entry points register a legacy-safe factory but do not
change their existing single-Body spawn path.

`run-vehicle-factory-v1.ps1` covers successful and synthetic spawn, a joint-stage
failure with rollback, tick, event ledger, dispose/idempotence, stale generation,
foreign owner and zero orphan resources. The self-test mutates a snapshot and a
failure stage to ensure both regressions fail closed.

Rollback is to bypass the factory and continue the existing VehicleInstance/
adapter path. Keep failed-stage records and lifecycle events when investigating
runtime cleanup; never promote a stage implementation without live S1 resource
and owner/generation evidence.
