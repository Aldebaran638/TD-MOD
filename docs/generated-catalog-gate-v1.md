# Generated Catalog Gate v1 (Gate 3.5)

`tools/cm2-compiler/build-generated-catalog-manifest-v1.ps1` is the aggregation
step after the Weapon/Projectile, Vehicle/Component, Effect Profile and
Loadout DTO builders. It emits:

- `docs/generated/cm2-generated-catalog-manifest-v1.json`, containing source
  snapshot hash, catalog paths/counts/hashes, effect profile and Loadout DTO
  revisions, entry-closure requirements, namespace/reference totals and the
  ownership decision;
- `docs/generated/cm2-generated-catalog-v1.lua`, a generated index with the
  same hashes; and
- `docs/generated/cm2-generated-catalog-v1.sha256`, the sidecar used to reject
  stale output.

`harness/check-generated-catalog-manifest-v1.ps1` fails early when a generated
header, sidecar, manifest path, reference count, source hash, entry point or
deterministic rebuild differs. Its self-test corrupts `outputHash` and proves
that stale output cannot pass the gate. The existing `cm2-compiler` fixtures
continue to cover duplicate IDs, future schema, missing resources and broken
references.

The manifest intentionally records `runtimePolicy = legacy-active`,
`mode = shadow`, and `promotionAllowed = false`. This is the safe default until
Teardown shadow/S0–S8 evidence is available. The aggregate Lua index is not
included by any Content Mod 2 entry point. Promotion is therefore a separate,
auditable ownership change with rollback to the previous manifest and legacy
catalogs.
