# Turret Visual Actuator and LOD v1 (Step 7.3)

`cm2TurretVisualActuatorV1` is a bounded presentation DTO. It approaches solver
yaw/pitch commands at configured maximum speeds, clamps large `dt` to 100 ms,
and exposes current/target angles. It never writes a Joint or calls renderer,
particle or audio APIs.

LOD selection is explicit and deterministic: `near` up to `nearDistance`, `far`
up to `farDistance`, otherwise `cull`; a disabled budget always culls. When the
visual path is unavailable the DTO preserves `fallbackMode=static-anchor`, so a
stable anchor can still supply a minimal marker without creating unbounded FX.
Every handle carries identity/owner/generation and stale handles are rejected.

The fixture checks two 100-ms actuator steps, large-dt clamping, near/far/cull
boundaries, disposal and stale generation. The self-test rejects a smoothing
golden and an LOD boundary mutation. Live renderer cost, Joint synchronization,
network interpolation and visual screenshots remain pending until Teardown is
discoverable.

Rollback is to bypass the visual actuator and retain the legacy/static marker;
keep solver output and LOD reports for comparison and do not add production FX
ownership before the runtime gate.
