# Event-chain diagnosis and recovery

## Weapon chain

A useful full chain is:

```text
input_edge
→ weapon_input_evaluated(ready)
→ weapon_hold_sent
→ weapon_hold_received
→ weapon_hold_applied
→ fire_request
→ presentation_event (when publisher path applies)
→ weapon_released
→ hit
→ damage_applied
→ hp_changed
→ ship_destroyed
→ ship_unregistered
→ ship_cleanup
```

This is a boundary map, not a universal strict timestamp order. A charged weapon can apply release damage before the `weapon_released` instrumentation, and a lock-free fire request can have target 0 while the authoritative hit later resolves a registered target.

| Last good evidence | Missing/inconsistent evidence | Diagnose first |
|---|---|---|
| no `input_edge` after real input | input trace | focus, binding, HID, client telemetry init |
| edge, `weapon_input_evaluated(blocked)` | ready stage | player vehicle/context/config UI/target lock/reason field |
| ready + sent, no received | command transport | ServerCall same-script boundary, player/ship IDs, server endpoint |
| received, rejected | applied | rejection reason, ownership, group validity, target validation |
| applied, no `fire_request`/release | weapon runtime | cooldown, charge state, group state machine, definition |
| released, no hit | collision | ray/projectile/sweep, target geometry, mask, range, targeting |
| hit, no `damage_applied` | damage boundary | authority, target registration, layer resolver |
| damage, no matching HP delta | health registry | before/after writes, numeric precision, duplicate authority |
| destruction, no unregister/cleanup | lifecycle | registry owner, dispose schedule, stale handles |
| presentation event, no visual | client presentation | consumer queue, effect resolver, budget/asset/camera |
| visual fire, no weapon events | presentation bypass | legacy/fake FX path, wrong scenario/input context |

For damage arithmetic, sum actual deltas by layer and compare with `applied_damage`, allowing only documented float tolerance. Layer order is shield → armor → body unless the weapon explicitly defines bypass semantics.

## State/reload faults

- New telemetry session after reload means discard old cursors and ship IDs.
- Same Lua/XML revision after intended change means reload was too weak; use the matrix's next level.
- Registered ship from an old session is not current evidence even if body ID repeats.
- `truncated=true` means continue from `next_after_seq`; do not interpret an incomplete chain as a runtime break.
- First UI bridge timeout: emergency release, fresh observe, verify correct level, retry once. Repeated timeout with no session means wrong Mod/level or bridge failure. A black text bar remaining after a response means bridge cleanup failed; do not send gameplay input until a fresh screenshot proves it closed.

## Runtime faults

- stale frame: re-observe; never reuse;
- lost focus/wrong window: exact target status, observe, then input;
- input stuck: emergency release, confirm held arrays empty;
- black screen: wait and check log/process; capture timeout evidence;
- clipboard conflict: preserve user copy and report;
- Lua/engine error: record log cursor slice and stop acceptance; fix before retry;
- multiple processes: use explicit target ID and close all test children after session;
- crash: preserve action/telemetry/log/last frame before relaunch.

Always diagnose the first broken authority boundary. Later missing events are usually consequences, not independent bugs.
