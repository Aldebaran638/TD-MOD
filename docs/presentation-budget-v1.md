# Presentation Budget Facade v1

`presentation_budget.lua` is the single new facade for expensive presentation
requests. It exposes particle, point-light, sprite, line, audio and camera-shake
requests and records `requested/accepted/degraded/rejected` counts with the
effect/owner/priority metadata supplied by callers.

`beginFrame` is called by each script entry exactly once before destroyed-ship
or weapon presentation work. The old duplicate call in `client.lua` plus
`effect_dispatch.lua` was removed; `effect_dispatch` now only runs specialised
renderer ticks. The underlying `effect_budget.lua` remains the legacy budget
implementation and is the only other file permitted to call `PointLight`.

The first high-risk paths now use the facade: ship destruction, weapon sound
service, Perdition/Tachyon charge particles and charge light. Existing
Tachyon/Perdition impact renderers retain their pre-budgeted specialised loops
as a transitional allowlist; the checker requires those loops to retain an
explicit budget reservation. Budget rejection/degradation changes only visual
requests, never damage, hit or lifecycle state.

Rollback is local: remove the facade include/calls and restore the previous
renderer call sites; the hard budget counters remain available through the
legacy implementation.
