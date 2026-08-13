# Vehicle / Mount / Component / Interceptor Catalog v1

This is the Gate 3.3 migration candidate. It is generated from
`docs/golden/cm2-definition-snapshot.json` and the current ship/component Lua
sources by `tools/cm2-vehicles/build-generated-vehicle-catalog.ps1`.

The artifact contains 5 `cm2.vehicle/1` records, 32 normalized mount records,
26 `cm2.component/1` records, 3 `cm2.interceptor/1` records, and two explicit
target-filter records. Vehicle records retain health, flight, parent-local
coordinate-frame metadata, slot groups, default loadout, mount-set IDs and
component IDs. Mount entries retain the legacy parent-local position and
relative direction (including non-unit legacy directions) in a canonical
`localTransform`; alias profiles point to their source profile instead of
silently duplicating ownership. Components preserve slot, numerical effects,
official IDs, English labels, icon paths and source provenance. Interceptors
are server-authoritative and carry bounded query/guidance budgets.

The generated JSON, Lua summary and SHA-256 sidecar are candidate-only. The
legacy ship/component registries remain authoritative until the in-engine
Vehicle gate has completed S1–S4 replay and coordinate golden evidence. A
failed build never replaces an existing generated artifact: build into a
temporary directory, compare the deterministic sidecar, then promote only
after the checker passes.

## Coordinate and ownership rules

- All candidate transforms state `space = parent-local`, use metres, and record
  the project frame `+X right, +Y up, -Z forward`.
- `fireDirRelative` is retained as a direction observation, not normalized;
  this prevents the legacy Enigma swarmer vectors from changing behavior.
- Vehicle ownership is independent from Weapon ownership. To roll back, keep
  `cm2-vehicle-definitions-v1.json` out of runtime includes and select the
  legacy registry; no legacy source file is overwritten.

## Verification

`harness/check-vehicle-component-catalog.ps1` checks counts, schemas, ID
references, coordinate metadata, component slot contracts, interceptor budgets,
hash integrity and deterministic regeneration. The paired self-test exercises
missing references, invalid interceptor classes and non-parent-local transforms.
