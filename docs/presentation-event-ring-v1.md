# Presentation Event Ring v1

The event-v1 client receiver uses two fixed-capacity rings:

| class | capacity | policy |
| --- | ---: | --- |
| Critical (`projectile`, `impact`, craft launch/recover, charge-stop) | 128 | never displaced by ambient events; overflow is counted and rejected |
| Ambient (trail/update, sound, muzzle and other non-critical kinds) | 32 | latest event for the same source/effect/kind replaces the older entry; otherwise overflow is counted |

The rings use head/tail/count slots and never call unbounded `append` or
`table.remove`. Events are validated before insertion. Source-local sequence
tracking reports duplicate, gap and out-of-order events while the global latest
sequence remains available for diagnostics. `presentationEventDrain()` consumes
each queued event exactly once, critical first, then ambient.

`presentationEventDisposeOwner(sourceId)` removes pending events owned by a dead
entity and records a cancellation count. This is the client-side dispose boundary;
the server publisher remains responsible for emitting protocol-level finish events.
Legacy presentation bypasses the ring and is therefore an immediate rollback path.
