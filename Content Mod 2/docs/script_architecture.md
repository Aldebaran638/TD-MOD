# Battlecruiser Script Architecture

`script/shipMain.lua` is the server entry point. `script/client.lua` is the client
composition root. Entry files may assemble modules, but weapon or ship behavior
must live in the owning module.

## Ownership rules

- `script/data/ships`: ship definitions and the ship catalog.
- `script/data/weapons/<slot>`: weapon definitions grouped by slot.
- `script/ship/battlecruiser`: battlecruiser-only camera, HUD, movement, registry,
  lifecycle, and fire-control orchestration.
- `script/weapon/client/common`: behavior genuinely shared by multiple weapons.
- `script/weapon/client/guided`: shared M/G guided-weapon targeting and effects.
- `script/weapon/client/slots/<slot>/<weapon>`: effects owned by one weapon.
- `script/weapon/server/common`: shared server-side weapon infrastructure.
- `script/weapon/server/guided`: shared guided-projectile runtime.
- `script/weapon/server/slots/<slot>/<weapon>`: state and control owned by one
  weapon.

Slot directories contain slot-wide state and targeting only. A specific weapon's
charging, muzzle, beam, projectile, or impact behavior belongs to that weapon.

Lua paths use lowercase `snake_case`. The `shipMain.lua` engine entry point keeps
its established name.

## Scene ownership

`prefabs/ships/enigma_battlecruiser.xml` is the single battlecruiser entity
definition. `main.xml` is a test scene and only instantiates that prefab.
