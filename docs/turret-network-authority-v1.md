# Turret Network and multiplayer authority v1 (Step 7.4)

`cm2TurretNetworkAuthorityV1` defines the server/client DTO boundary for a
future turret:

- the server owns yaw/pitch/target state and emits monotonic snapshots;
- commands require matching owner, generation and increasing sequence;
- a bounded per-second command rate rejects floods;
- fire events are server-issued and duplicate sequence IDs are idempotently
  rejected;
- clients accept only newer snapshots for the current generation and expose a
  local interpolation result.

The module has no socket, player, weapon, Joint or physics calls. It is therefore
safe to run in the offline fixture host and cannot accidentally grant a client
authority. `turret-network/1` snapshots include identity, owner, generation,
sequence, yaw, pitch and target ID; fire events include group and target IDs.

The fixture uses command rate 1, proves accepted/stale/foreign/rate-rejected
commands, accepted and duplicate fire, client stale-snapshot rejection and
50%-interpolation. The self-test mutates snapshot sequencing and foreign-owner
expectations. Live multiplayer latency, packet loss, reconnect and runtime fire
ownership remain pending until Teardown is available.

Rollback is to stop accepting the DTO command path and keep the existing legacy
server route; preserve sequence/rejection evidence and never let the client emit
a fire event directly.
