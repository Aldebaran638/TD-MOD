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

## Step 3.4 Runtime Verification

The live verification used the embedded contract fingerprint
`1af2d2ed626d423751e74d9ea3892f113f7acbcfd0f73a28879337900c0f1d65` and the
isolated `_ai_scenario_vehicle_component_catalog.xml` scene after F5 reload.
The fresh `CM2_TEST_V1` session was `0-b3446688`; the scenario reported
`vehicle_component_catalog_v1`, `scenario-controller-v2`, and
`vehicle-component-catalog-xml-v1`.

The runtime snapshot exposed both affected ships through the same v1 DTO:

- Titan: `titan_core`, revision `1`, hash `473e5410`;
- Enigmatic: `battleline_2x2l4m`, revision `1`, hash `68c64c40`.

The real-input trace produced `weapon_input_evaluated`, `fire_request`, and
`presentation_event` boundaries, then returned to `lmb=false`. The T key opened
the configuration UI; a real selection changed Enigmatic to `TORPEDO FRAME`,
Save displayed `SAVED FOR NEXT SPAWN`, and close/reopen displayed
`TORPEDO FRAME` with `LOCAL DESIGN LOADED`. This proves the visible persisted
selection; telemetry remains authoritative for the runtime snapshots.

Evidence runs and screenshots are recorded in
`docs/evidence/step-3.4-loadout-configuration-v1.json`. The incremental log
contained no in-scope CM2 Lua/API error. Two missing TABS Workshop sound banks
and six TABS ballistics deprecation warnings were attributed to the external
`[TABS] Vehicle Framework`; they are retained as environment noise, not CM2
success evidence. Cleanup returned the tracked input set to empty and F4
returned to the editor.
