# Transform/Anchor v1

Step 6.3 introduces one coordinate contract for ship parts and anchors. The
adapter is DTO-only: it consumes EntityGraph definition/runtime records and
does not call `GetBodyTransform`, read a root Body, or apply a system-specific
magic offset.

## Contract

- Protocol: `cm2.transform-anchor/1`.
- Units: metres (`meters`). The frame is right-handed, Y-up; ship forward is
  local `-Z`, up is `+Y`, and right is `+X`.
- A transform has `position`, quaternion `rotation` (`x,y,z,w`), positive
  `scale`, and sign-only `mirror` (`-1` or `+1` per axis).
- `local` is relative to `parentPartId`; `parent` is the parent world frame;
  `world` is the composed result. Composition applies parent effective scale
  (`scale * mirror`) before parent rotation and translation.
- Every handle and result carries `identity`, `ownerId`, `generation`, and
  `sourceRevision`. A stale, foreign, malformed, or invalid handle is rejected
  before any engine access.

## API

`cm2TransformAnchorV1.serverInit`, `handle`, `bind`, `invalidate`,
`resolvePart`, `resolveAnchor`, `getBasis`, `getVelocity`, `getScale`,
`getMirror`, `snapshot`, and `getDiagnostics` are the public surface.

`bind` validates duplicate parts, missing parents, and parent cycles. `invalidate`
  increments the source revision and clears both part and anchor caches. A
  scene reload, runtime graph rebind, or authoritative transform correction must
  call it before publishing new DTOs. Cache diagnostics expose lookups, hits,
  misses, stale/owner rejects, and invalidation counts.

`getBasis` uses the fixed forward/up/right convention. `getVelocity` converts
  between local and world velocity only through the resolved rotation; scale and
  mirror are returned separately so physics and presentation cannot silently
  conflate them.

## Adoption and rollback

`shipMain.lua` and `strikeCraftMain.lua` initialize the adapter after
`EntityGraphV1`; no existing physics layout is changed in this step. Until the
S1 in-game mount golden is available, callers may retain the old coordinate
adapter behind a feature switch. Roll back by bypassing this adapter and keeping
the old mount resolver read-only for comparison; preserve the fixture and
diagnostics so any difference can be reproduced.

## Evidence

`tools/cm2-world-host/run-transform-anchor-v1.ps1` validates root/parent
composition, 90-degree rotation, mirror/scale propagation, basis vectors,
velocity conversion, cache hits, world/local round-trip, invalidation, and stale
handles. `test-transform-anchor-v1.ps1` mutates a golden and a parent reference
to verify failures. The fixture is
`docs/candidates/transform-anchor-v1.fixture.json`.

The runner is offline evidence. Live S1 mount-count/coordinate, reload, and
performance evidence remains pending until a discoverable `Teardown.exe` is
available.
