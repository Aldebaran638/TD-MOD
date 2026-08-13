# Multiplayer, Save/Load and Lifecycle Soak v1

## Scope

This gate models the long-running boundary that short smoke tests cannot cover: Host plus remote configuration and ownership, lock/fire/turret/death/respawn, reconnect and late join; repeated Ship, Projectile, Craft, Effect and Joint creation/destruction; versioned Loadout/Package save/load; and bounded queue, owner lease, memory, active-count and stale-handle metrics.

## Run

    .\tools\cm2-soak\check-multiplayer-lifecycle-soak-v1.ps1
    .\tools\cm2-soak\run-multiplayer-lifecycle-soak-v1.ps1
    .\tools\cm2-soak\test-multiplayer-lifecycle-soak-v1.ps1

The deterministic headless model covers 1,800 cleanup cycles representing 30 minutes at 30 Hz, invokes the existing multiplayer/entity/projectile/joint/package/compatibility suites, and writes `docs/candidates/multiplayer-lifecycle-soak-v1.result.json`. Missing packages and downgrade revisions are explicit rejections; compatible revisions use an explicit migration decision and never silently fork.

## Result semantics

`pass` requires both the headless model and a live Teardown soak. `unable` means all source contracts, state-machine checks and existing suites pass, but live Teardown evidence is not available. The current report is therefore an honest headless candidate with Runtime `deferred`; it does not claim real frame time, network transport, memory allocator or screenshot/replay evidence.

## Rollback

Keep the failing trace and reduce only scenario scale when diagnosing. Restore the last valid lifecycle and Save/Load manifests; never discard a failing fixture or silently accept a missing package/downgrade. Re-run the 30-minute live gate after Teardown is available.
