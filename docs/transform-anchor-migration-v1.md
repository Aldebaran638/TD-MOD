# Transform/Anchor migration v1 (Step 6.4)

This step makes the coordinate migration observable and reversible. It does not
turn every legacy caller on at once. `cm2TransformAnchorMigrationV1` owns a
fixed ledger of five batches and keeps `legacy` as the default source:

1. `mount-fire` — mount lookup and fire transforms.
2. `camera-engine-thruster` — camera, engine and thruster axes.
3. `weapon-projectile` — muzzle and projectile spawn transforms.
4. `fx-audio-shake` — effect, audio and camera-shake anchors.
5. `damage-part-health` — damage hit parts and per-part health locations.

Each batch can be `legacy`, `shadow`, or `anchor`. Shadow executes both
resolvers, returns the legacy value, and records the first differing field,
numeric delta, epsilon, and evidence tag. Anchor mode is rejected until that
batch has a clean comparison. A mismatch therefore cannot silently promote a
weapon or camera coordinate. `rollback` is idempotent at the source boundary:
it switches the batch to legacy and stores the reason in the ledger.

The facade and both ship entry points carry identity, owner and generation. The
default initialization is legacy-safe, so this step changes no physics or
presentation behavior until a later gate explicitly promotes a batch. The
fixture exercises all five batches, shadow comparisons, one deliberate muzzle
mismatch, an anchor-mode rejection, rollback, an unknown batch and a stale
handle. `test-transform-anchor-migration-v1.ps1` adds negative mutations for
promotion-before-comparison and unknown batch definitions.

The migration ledger is the returned `snapshot()`/`getDiagnostics()` DTO plus
`docs/candidates/transform-anchor-migration-v1.result.json`. Keep the legacy
resolver as a read-only comparator until S0/S1/S5 in-game golden captures are
available. If a live batch differs, call `rollback` for that batch, preserve the
comparison record, and fix the resolver before attempting promotion again.
