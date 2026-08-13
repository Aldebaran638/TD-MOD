# Four vertical-slice migration bridge

Step 2.5 connects the validated event path to the fixed-capacity EffectPlayer for
four real content families:

| slice | representative IDs | event families |
| --- | --- | --- |
| ray-beam | `flakArtillery` | beam/impact/sound |
| logical-projectile | `gigaCannon` | projectile/impact |
| guided-missile | `swarmerMissile` | projectile/impact/craft lifecycle |
| tachyon-charge-beam | `tachyonLance`, `perditionBeam` | charge/beam/impact |

`slice_runtime.lua` consumes the bounded event ring only when the slice is
configured `event-v1`; legacy remains the default. Projectile events retain a
handle for subsequent impact/finish cleanup, while one-shot beam/muzzle/sound/
impact events use an idempotent play/stop pair. A 256-entry trace records
sequence, slice, operation and handle for deterministic comparison. Slice modes
are read at init and freeze after the publisher's first publication.

This is an integration bridge, not a renderer rewrite: specialised phase
renderers remain available and the EffectPlayer stores renderer state for the
next EffectPlayer adapter step. Each slice can independently revert to legacy.
