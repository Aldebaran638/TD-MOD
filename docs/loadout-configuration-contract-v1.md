# Loadout / Configuration Contract v1

`Content Mod 2/script/data/configuration/loadout_contract_v1.lua` is the pure
DTO boundary for UI selections, server Runtime validation, future Compiler
input and save payloads. It defines `cm2.loadout/1`, integer `revision`, a
namespaced `vehicleId`, canonical `configurationId`, ordered group keys,
namespaced Weapon/Component IDs and an optional `mountRevision`.

The module provides:

- `validate` with structured `code`, `fieldPath`, `expected`, `actual` and
  `suggestion` diagnostics;
- `migrateV0`, which maps legacy `configuration`/`configurationId`, X/L/M/G/H/T
  and unnamespaced IDs exactly once and is idempotent when called on v1;
- explicit missing policies: unknown Weapon rejects, absent Component/Mount
  degrades to an empty choice with a warning, missing Configuration falls back
  to the compiled default, and revision downgrade rejects;
- `validateAgainstFit` for server-owned compiled fit matrices;
- deterministic `encode` and `snapshotHash` for persistence/replay; and
- init-only alias registration plus `freeze`, which prevents Runtime
  registration or overwrite after context initialization.

The JSON fixtures under `harness/data/configuration` cover a valid v1 snapshot,
a legacy alias migration, an unknown Weapon and a downgrade. The module is
included once by `data/ships/ship_catalog.lua`; no per-frame configuration
registration or engine API is introduced. Legacy `slot_loadout` remains the
rollback adapter until the v0 usage ledger is empty and live S7 evidence is
available.
