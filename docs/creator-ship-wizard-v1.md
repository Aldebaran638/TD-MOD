# Creator Ship Wizard MVP v1

The Wizard is a source/validation workflow for a non-Core creator. Its ordered
steps are intentionally explicit:

`select VOX → import report → confirm scale/forward/up → single Body high-
performance template → HP/flight/camera/engine → effect anchors → loadout →
Validate/Build → Ship Dock → Weapon Range`.

`tools/cm2-wizard/run-creator-ship-wizard-v1.ps1` reads the Step 8.1 Asset
Manifest, requires an explicit canonical orientation confirmation, and validates
one Body/one Shape/no Joint against the Runtime budget. It then validates health,
flight, camera, engine/effect anchors and namespaced loadout references before
producing a deterministic source/build hash. The wizard is Lua-free and does not
modify `main.lua`, `shipMain.lua`, Catalog Authority or any other Core entry.

The fixture records three non-Core creators, first-success seconds, error code /
field path / resource, Lua calls, coordinate drift and Preview difference. The
headless cohort reports 3 users, 1.0 localizable diagnostics, 0 Lua calls, zero
coordinate drift and zero Preview differences. These are contract fixtures, not
claims of live usability: Teardown.exe is unavailable, so in-game flight and
capture remain a later runtime gate.

The negative suite blocks wrong step order, unconfirmed orientation, invalid
mass, missing engine anchors, Core-boundary violations and unlocalizable errors.
Rollback is source-only: discard the wizard staging package and restore the last
valid source/catalog; the Core hashes are recorded before and after every run.
