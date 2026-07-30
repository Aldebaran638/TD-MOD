# CM2 Ship and Weapon Architecture

`script/shipMain.lua` and `script/client.lua` are engine entry points. They are
composition roots only:

- the server entry delegates ship work to `ship/common/server/bootstrap.lua`;
- the server entry delegates weapon work to `weapon/server/bootstrap.lua`;
- the client entry delegates to the equivalent ship and weapon client
  bootstraps.

Entry points must not include or call a concrete weapon controller.

## Ship boundary

Every spawned ship supplies a `shiptype` parameter. The catalog entry under
`data/ships` owns all ship-specific values:

- HP, regeneration and shield radius;
- flight, attitude and damping tuning;
- camera and engine-effect profiles;
- slot configurations, weapon pools and canonical mount profiles.

`ShipRuntimeContext` owns the current script entity's body, type and definition.
Framework code must use `shipContextGetBody`, `shipContextGetType` and
`shipContextGetDefinition`; implicit `shipBody` or `defaultShipType` globals are
forbidden.

`ship/common` owns reusable state, movement, lifecycle, camera, HUD, registry and
network authorization. A future ship adds a data definition and prefab tags; it
does not copy the battlecruiser runtime.

## Weapon boundary

Each weapon has one complete definition in `data/weapons/<slot>`. The schema
builders supply only common defaults. A weapon definition selects:

- a generic behavior (`raycast`, `projectile`, `rocketProjectile`,
  `guidedProjectile`, or `strikeCraft`);
- an optional specialized controller through `controllerType`;
- a ship-owned mount profile through `mountProfile`.

The selected ship definition and weapon definition are resolved together by
`shipDefinitionResolveMounts`. Weapon code never stores battlecruiser
coordinates.

The unified weapon runtime exposes:

- `weaponRuntimeInit`
- `weaponRuntimeRebuild`
- `weaponRuntimeClearCommands`
- `weaponRuntimeCommandTick`
- `weaponRuntimeSimulationTick`
- `weaponRuntimeUpdate`
- `weaponRuntimePostUpdate`
- `weaponRuntimeDeactivate`

Specialized state machines register through
`specialized_controller_adapters.lua`. Optional activity predicates prevent
empty projectile and unavailable-controller systems from consuming frame time.

## Network and input ownership

Server requests are separated into:

- common ship request authorization;
- validated control snapshots;
- weapon command endpoints.

The server derives authority from the player currently driving this script's
body. When the driver changes or leaves, movement, attitude, aim and held-fire
commands are reset atomically.

The local configuration panel owns one session Registry source. A spawned ship
takes one snapshot and submits it on first drive; the server validates and locks
that ship's configuration.

## Naming

Lua paths use lowercase `snake_case`. Teardown's established `shipMain.lua`
engine entry name is the only exception.
