# CM2 Testing Notes

This note tracks future testing directions for Content Mod 2. It is a planning
record, not a replacement for the project check scripts.

## Current Priorities

| Direction | Risk to cover | Preferred validation |
| --- | --- | --- |
| Numbered weapon groups | `X1/X2`, `L1/L2/L3`, `M`, `G`, `H`, and `T` groups resolve distinct loadouts, mount profiles, HUD entries, and fire requests. | Lua fixture plus in-game configuration and firing pass. |
| Configuration synchronization | A remote client receives each resolved group weapon after a frame or loadout change; stale group data does not remain. | Network-facing Lua fixture and two-client gameplay check. |
| Guided group isolation | Numbered guided groups keep independent launcher selection, cooldown, and target requests. | Server runtime fixture and in-game target-lock check. |
| Strike-craft group isolation | Numbered H groups launch only from their own hangar mounts and respect global entity limits. | Server runtime fixture and motion check. |
| Charged-ray groups | Numbered X/T groups retain charge, release, visual lifecycle, and cancellation behavior. | Runtime fixture and visual smoke test. |
| UI scale | Wheel and configuration cards remain readable with many groups and long labels. | Screenshot/manual UI pass at supported resolutions. |
| Validation contract maintenance | Checkers match current audio, asset, and runtime contracts. | Checker self-test before any checker change. |
| Explicit weapon definitions | Slot weapons remain individually auditable and cannot regress to tier loops, batch tables, wrappers, or unsupported registration functions. | `harness/data/weapons/check-explicit-weapon-definitions.ps1` and its self-test. |

## Test Levels

1. Static contract: the charged-weapon and non-charged-laser checkers validate
   their data profile contracts and runtime dispatch boundaries.
2. Checker self-test: each Harness self-test rejects intentional
   fixture violations in its own category.
3. Runtime fixture: isolated Lua state proves loadout resolution, requests,
   cooldowns, and synchronization payloads.
4. In-game smoke test: validates engine physics, client/server ordering, sound,
   visual effects, and UI behavior that static scripts cannot observe.

## Record Template

```text
Scenario:
Risk:
Affected files/runtime layer:
Setup:
Action:
Expected result:
Automation owner:
Manual validation:
Status: planned | implemented | blocked | superseded
```

## Rules

- Test the public behavior and failure boundary, not implementation details
  without user-visible or correctness value.
- Keep fixtures minimal and restore them after each self-test case.
- Do not modify a checker or harness merely to make a product change pass.
- Run the complete verification sequence in `AGENTS.md` after product edits.

## Planned Runtime And Weapon Integration Scenarios

### Explicit Per-Slot Weapon Definitions

```text
Scenario: Keep every S/G/H/L/M/P/T/X weapon as one direct definition.
Risk: Tier loops, batch data tables, wrapper functions, or alternate registration
      functions hide individual values and reintroduce load-order failures.
Affected files/runtime layer: script/data/weapons slot definition files and the
      static Harness contract.
Setup: Scan each slot directory and its single stellaris.lua definition file.
Action: Reject loops, helper functions, batch structures, extra Lua files,
        unsupported calls, duplicate or non-literal weaponType fields, and
        slotTypes values that disagree with the containing directory.
Expected result: Every weapon is registered by exactly one direct call to
                 weaponDefineRay, weaponDefineProjectile, weaponDefineGuided,
                 or weaponDefineStrikeCraft in its matching slot file.
Automation owner: harness/data/weapons/check-explicit-weapon-definitions.ps1 and
                  harness/data/weapons/test-check-explicit-weapon-definitions.ps1.
Manual validation: None; this is a static source-structure contract.
Status: implemented
```

### Aircraft Load Performance

```text
Scenario: Incrementally place and operate multiple aircraft/strike craft.
Risk: Frame time, simulation time, network traffic, or active-craft state grows
      without a bound as craft are launched, recovered, and reused.
Affected files/runtime layer: H-slot strike-craft controller, motion runtime,
      global active-craft limit, and client/server synchronization.
Setup: Start from a clean session. Record a no-aircraft baseline for frame time
       and simulation time. Add carriers and launch craft in steps up to the
       configured global limit (currently 24), keeping the same scene and target.
Action: At each step, wait for launch, flight, recovery, and one full reuse
        cycle. Record frame-time percentile, simulation time, active-craft count,
        and network/debug entity counts. Repeat the final step after a reload.
Expected result: Resource and timing measurements stay within a threshold set
                from the baseline trial; the active count never exceeds the
                configured limit; recovered craft do not leave duplicate motion
                controllers or visual/network entities; reload returns to baseline.
Automation owner: A future runtime fixture or gated diagnostic counter should
                   assert active-craft bounds and that each lifecycle reaches a
                   terminal state. Existing static checks cover the motion
                   contract but not performance.
Manual validation: Game-session stress pass with a profiler or frame-time
                   capture at the supported desktop resolutions. Establish the
                   numeric threshold during the first baseline run and keep it in
                   this note with the result.
Status: planned
```

### Destroyed-Ship Runtime Cleanup

```text
Scenario: Destroy a ship while its weapon and strike-craft runtimes are active.
Risk: A dead ship leaves an empty per-frame script, stale callbacks, or orphaned
      projectile/craft state that continues consuming server time.
Affected files/runtime layer: weapon runtime deactivation, H-slot state,
      guided projectile state, target registration, and network cleanup.
Setup: Prepare one ship with an active H craft, a guided projectile, and one
       charge or other weapon controller. Capture the pre-destruction runtime
       counters and entity count.
Action: Destroy the ship, leave the vehicle, and observe immediately, after
        0.5 seconds, after 5 seconds, and after 30 seconds. Repeat after a
        session reload and with each supported ship type.
Expected result: The dead ship is removed from target/configuration registries;
                its weapon runtime is deactivated; H-slot craft owned by it are
                deleted or reach their documented terminal state; callbacks and
                per-frame ticks stop; no counter or entity count increases while
                the destroyed ship is absent. Projectiles that are intentionally
                independent may finish their documented lifetime, but must not
                retain a dead-ship controller loop.
Automation owner: Add a runtime fixture/diagnostic assertion for deactivation,
                   empty active-craft state, and zero dead-owner tick callbacks.
                   Do not weaken checker contracts to make this pass.
Manual validation: Use the profiler and server debug counters around the four
                   observation points, and inspect the scene for orphaned craft,
                   effects, and network updates.
Status: planned
```

### Weapon Classification, Registration, And Configuration Availability

```text
Scenario: Add one weapon definition and verify classification, values, effects,
          slot compatibility, configuration visibility, and actual firing.
Risk: A definition appears valid in isolation but is missing an icon, numeric
      value, behavior profile, FX profile, or a valid slotTypes declaration;
      compatible ships then show no weapon, show duplicates, or accept a weapon
      that the server cannot execute.
Affected files/runtime layer: weapon catalog/schema, weapon data, behavior and
      FX registries, shared weapon slot pools, slot loadout validation, and UI cards.
Setup: Create a uniquely named fixture weapon with a valid icon, numeric stats,
       behavior type, slotTypes, mount/slot values, and FX code. Register it in
       the weapon catalog; a ship with a matching slot group is compatible, and
       a ship without that slot group is the incompatible control.
Action: Reload a fresh session. Verify catalog/checker loading, then open each
        compatible ship configuration and confirm one correctly labeled card,
        icon, values, slot, behavior, and FX. Select, save, reload, and fire it.
        Confirm the incompatible control omits it and server-side validation
        rejects a forged incompatible loadout. Repeat for each numbered slot
        group used by the feature.
Expected result: All required metadata resolves without fallback or missing
                references; each compatible configuration lists the weapon once,
                preserves it across save/reload, and fires with the declared
                behavior and effects. Incompatible ships never offer it and
                cannot use it. A runtime-ready definition with `slotTypes` is
                automatically available to every matching slot group.
Automation owner: Add a focused runtime fixture when implementation begins to
                   assert pool membership, compatibility filtering, and
                   duplicate-free catalog resolution. The Harness only checks
                   Lua/XML/API legality plus charged and non-charged laser
                   profile contracts.
Manual validation: Configuration UI and firing pass across every compatible
                   ship, including a client/server session where applicable.
Status: planned
```
