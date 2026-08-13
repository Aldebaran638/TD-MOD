# Deterministic scenarios and consumer Mods

## Scenario layout

Keep executable level XML at the Content Mod root because the editor's Open Level dialog only enumerated root XML in the live experiment:

```text
Content Mod 2/
  _ai_scenario_<domain>_<case>.xml
  testing/scenarios/<domain>/<case>/contract.json
  script/testing/scenario/<controller>.lua
```

The root XML is only the engine entrypoint. Contracts and controllers remain under responsibility-first nested folders. This preserves the repository rule that siblings express the same classification dimension.

Each scenario must be isolated, disposable, deterministic, reproducible and easy to clean. Include explicit scenario ID, XML revision, Lua revision and ready state in telemetry. Prefer fixed transforms, zero velocities, fixed HP/loadout/counts, ready cooldowns and bounded lifetimes.

Current canonical fixture:

- level: `Content Mod 2/_ai_scenario_weapon_direct_fire.xml`;
- contract: `Content Mod 2/testing/scenarios/weapons/direct_fire/contract.json`;
- controller: `Content Mod 2/script/testing/scenario/scenario_controller.lua`;
- attacker: Titan at `(0,60,0)`, forward `-Z`;
- target: registered enigmatic cruiser centered approximately at `(0,60,-25)`.

Use this pattern for direct/guided/AOE weapons, damage layers, destroy-cleanup, movement/rotation/speed/boundary, strike craft, cloak, loadout, lifecycle, ownership, presentation and performance. Create a new case only when its setup or assertions materially differ.

Do not modify formal `main.xml` for an isolated test. Do not add a cheat path for the trigger under test. A scenario can place/aim/configure; it cannot directly publish a fake hit to prove collision.

## Consumer Mod fixtures

Create a second Mod when the claim crosses a Mod boundary: public API, dependency, registration, callbacks, schema compatibility, extension/override, invalid input, backwards compatibility or interoperability. Calling CM2 private code from CM2 is not consumer evidence.

Current fixture:

```text
_AI Test Consumer Basic/
  info.txt
  main.xml
  main.lua
```

It is tagged `[noupload]`, version 2 and intentionally independent. Live startup succeeded in single-player and two-player local mode. It displayed `WAITING FOR PUBLIC CM2 CONTRACT`, which is valid evidence that an independently launched Content Mod cannot currently discover a stable public CM2 runtime contract. Do not fix that by copying CM2 private scripts into the consumer; future public-contract work must define a real installation/dependency/broker path and re-run the consumer.

Consumer fixtures may remain as regression assets. Never publish them, never mix them into formal release content, and validate their Lua/API/XML roots separately.

## Scenario run recipe

1. validate contract;
2. select/reopen correct XML and F5;
3. wait through loading, then telemetry-probe until scenario ID/revisions/ready match;
4. record registered bodies and numeric baseline;
5. observe fresh frame and send minimum real action;
6. drain telemetry with continuation cursors;
7. capture visual and incremental log;
8. assert, release input, F4/exit and confirm cleanup/session boundary.
