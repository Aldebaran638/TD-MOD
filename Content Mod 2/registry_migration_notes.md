# CM2 Registry Migration Notes

## Core Method

Move runtime state that is only consumed inside the current script instance out of `registry` and back into local Lua objects.

Keep only these kinds of data in `registry`:

- state that must be shared across script instances
- state that must be readable from both server and client through snapshot-style access
- data that is still part of an old chain that has not been migrated yet

For client UI, do not push full runtime state back into `registry`.
Instead:

- keep the real state on the server
- push only minimal display data with `ClientCall`
- store only UI cache on the client

## What Was Migrated

### 1. L-slot runtime state

Migrated off `registry` into local server state:

- `lSlots/count`
- `lSlots/request`
- `lSlots/cooldownRemain`
- `lSlots/heat`
- `lSlots/overheated`
- per-slot `weaponType`
- per-slot `mount/firePosOffset`
- per-slot `mount/fireDirRelative`
- per-slot `aimMode`

Current server state source:

- `script/server/weapon_fire/lSlotState.lua`

Current runtime consumers:

- `script/server/weapon_fire/lSlotControl.lua`
- `script/server/weapon_fire/mainWeaponControl.lua`

Current client HUD path:

- server `ClientCall`
- client local cache in `script/client/camera_modules/mainWeaponHud.lua`

### 2. Main-weapon request bits

Migrated off `registry` into local server request state:

- `mainWeapon/fireRequest`
- `mainWeapon/toggleRequest`

Current server state source:

- `script/server/weapon_fire/mainWeaponControl.lua`

Current request ingress:

- `script/server/registry/shipRegistryRequest.lua`

These request bits are now local request flags only.
The old registry keys still exist in registry definitions for now, but runtime no longer depends on them.

### 3. X-slot runtime state

Migrated off `registry` into local server state:

- `xSlots/request`
- `xSlots/lastReadSeq`
- per-slot `cd`
- per-slot `state`
- per-slot `chargeRemain`
- per-slot `launchRemain`
- per-slot `weaponType`
- per-slot `mount/firePosOffset`
- per-slot `mount/fireDirRelative`
- per-slot `chargeDuration`
- per-slot `launchDuration`
- per-slot `randomTrajectoryAngle`

Current server state source:

- `script/server/weapon_fire/xSlotState.lua`

Current runtime consumers:

- `script/server/weapon_fire/xSlotControl.lua`
- `script/server/weapon_fire/mainWeaponControl.lua`
- `script/server/registry/shipRegistryRequest.lua`

### 4. X-slot render event bus

Migrated off `registry` into direct server-to-client event push:

- removed `xSlots/render/*` registry keys
- removed `snapshot.xSlotsRender`
- replaced with `ClientCall` event delivery
- client now caches render events by `shipBody`

Current server event source:

- `script/server/weapon_fire/xSlotRenderState.lua`

Current server emitter:

- `script/server/weapon_fire/xSlotControl.lua`

Current client event cache:

- `script/client/xSlotRenderState.lua`

Current client consumers:

- `script/client/draw_modules/xSlotChargingFx.lua`
- `script/client/draw_modules/xSlotLaunchFx.lua`
- `script/client/draw_modules/hitPointFx.lua`
- `script/client/draw_modules/shieldHitFx.lua`
- `script/client/sound_modules/soundModule.lua`

## Important Lessons / Bug Notes

### 1. Removing registry code can accidentally remove data loading

This happened with:

- `script/data/weapons/lSlots/kineticArtillery.lua`

After old L-slot registry code was removed, this file stopped being loaded, which broke:

- L-slot weapon config build
- projectile settings
- heat/cooldown values

Fix:

- load `kineticArtillery.lua` from `script/server/weapon_data.lua`

Rule:

- when cutting registry code, re-check all `#include` paths that were previously loaded "for free" by that code

### 2. Client namespace is shared across multiple script instances

This is the most important practical lesson from today.

Even if each `shipMain.lua` instance manages only one ship, all client-side functions and tables still live in the shared client namespace.

That means:

- one instance can overwrite another instance's HUD cache
- one instance can overwrite another instance's `DebugWatch`
- one instance can make a single global UI cache look broken

Fix used for L-slot HUD:

- store HUD cache by `shipBody`, not as one single global table

Rule:

- any client state that receives data from multiple script instances must be keyed by a stable ship identifier

### 3. DebugWatch can mislead badly in multi-instance scenes

If multiple instances write the same `DebugWatch` label, the last writer wins.

So:

- "watch value is stuck" does not necessarily mean the controlled ship is stuck
- it may only mean another instance is overwriting the same label

Rule:

- use very few `DebugWatch`
- in multi-instance scenes, include per-instance identity in the watched value or key

### 4. Split config from runtime

For migrated runtime state, keep this structure:

- `config`
- `runtime`

Do not mix them again.

This makes later migrations much safer.

### 5. Migrate runtime first, cleanup second

The safer order is:

1. migrate active runtime logic off registry
2. prove behavior still works
3. then remove dead registry keys/getters/setters/snapshot fields

This is the order used for L-slot migration.

## Remaining Unmigrated Registry Areas

### High-impact

- Full ship snapshot path
  - `server.registryShipGetSnapshot(...)`
  - `client.registryShipGetSnapshot(...)`
  - many modules still read more fields than they really need

### Medium-impact

- Movement request / state path
  - `move/requestState`
  - `moveState`

- Driver sync
  - `driverPlayerId`

- Rotation / roll input path
  - `pitchError`
  - `yawError`
  - `rollError`

- HP / regen state
  - HP values
  - regen config access
  - last-damage timestamps

### Structural / support

- Ship index
  - `ships/index/count`
  - `ships/index/<i>/bodyId`

- Client modules still scanning registry snapshots
  - sound
  - hit/shield FX
  - destroyed FX

## What Was Selected Next

Selected next migration:

- main-weapon request bits

Reason:

- low-risk
- no gameplay state persistence needed
- pure request flags
- easy reduction of unnecessary registry write/read traffic

Status:

- migrated

## Recommended Next Migration

If continuing from here, the best next target is:

- X-slot runtime state

Reason:

- after L-slot and request-bit migration, the remaining biggest burdens are now:
  - full snapshot over-read
  - movement / driver / rotation state
