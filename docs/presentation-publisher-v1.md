# Presentation Publisher v1

Step 2.1 introduces a deliberately narrow server-side publication boundary. Weapon
behaviour now publishes semantic kinds (`sound`, `muzzle`, `beam`, `projectile`,
`impact`, `craft_launch`, `craft_recover`) through `server.presentationPublisherPublish`.
The behaviour modules do not name client renderer callbacks; the route table in
`script/net/presentation_publisher.lua` owns the legacy mapping.

## Runtime switch

The switch is read once during each ship/strike-craft `server.init`:

```text
presentationRuntime=legacy   # default, exact existing ClientCall behaviour
presentationRuntime=event-v1  # sends validated WeaponPresentationEvent v1 DTOs
```

The legacy adapter remains the safe default. Event-v1 delivery uses the existing
network call boundary and the client receiver validates protocol, sequence and
forbidden runtime references before queueing the DTO. Rendering is intentionally
not replaced in this step; Step 2.2 consumes the queue with EffectPlayer.

## Evidence and rollback

Publisher counters expose total publishes, legacy adapter calls, event-v1 calls,
rejections and per-kind counts. A bad route or invalid DTO is rejected before
dispatch. Rollback is a single init-time switch back to `presentationRuntime=legacy`;
the underlying damage, movement and lifecycle algorithms are unchanged.

Teardown executable/runtime smoke evidence remains an external requirement. The
repository Harness proves static route ownership, init-only mode selection, DTO
validation and legacy/event-v1 fixture behaviour.
