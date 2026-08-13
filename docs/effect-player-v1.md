# EffectPlayer v1

`script/weapon/client/presentation/effect_player.lua` provides the lifecycle
foundation for the later Effect Runtime without turning every particle into a
generic ECS entity. A fixed-capacity slot store uses a free-list for allocation
and a dense active-index list for update iteration. Handles carry `index` and
`generation`; stale handles are rejected before mutation.

Each instance stores effect ID, owner, anchor, clock, seed, LOD, priority, phase,
fade state and renderer state. `play`, `update`, `stop` and `destroy` are
idempotent at the lifecycle boundary. Invalid owners destroy immediately;
invalid anchors enter a zero-duration stop. `sceneReload` resets all slots while
preserving the configured capacity. Resource handles are cached by key.

The invariant exposed by `getDiagnostics()` is always `active + free = capacity`.
Existing phase renderers remain registered in their specialised hot loops; this
module does not allocate a generic entity per particle.
