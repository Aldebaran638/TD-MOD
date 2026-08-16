# Presentation event routing v1

Step 2.6 extends the Step 2.5 Event Ring bridge from four representative
weapon slices to the remaining publisher routes. The server publisher now
rejects unknown routes before either transport is selected and copies the
route metadata into the validated event payload. The client consumer uses a
fixed route allowlist and invokes the existing budget-backed renderer facade;
it never evaluates a callback name received from the event.

The supported route families are:

- beam and hit: `ray.effect`, `ray.shieldImpact`, `tSlot.render`, `xSlot.render`;
- projectile and missile lifecycle: spawn, finish, muzzle, impact and sound;
- audio: weapon, projectile and missile sound routes;
- strike craft: launch, register and recover;
- point defense: `point-defense.fx` with an explicit destination payload.

Each event carries a stable `presentation.entityId` when the route owns a
projectile or craft. Finish routes stop the matching EffectPlayer generation;
scene or source disposal removes pending events and active handles. Legacy
mode still calls the existing route adapter, and event-v1 mode does not call
the legacy adapter for the same event.

The static route and budget contract passes. Live S1/S3/S5 owner-dispose,
visual and p95 evidence must be captured in the Step 2.6 evidence record before
the Todo status is promoted to verified.
