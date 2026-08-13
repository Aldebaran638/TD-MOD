# Preview Suite v1

Step 8.3 provides three Preview surfaces behind one shared, versioned boundary:

- **Effect Lab** uses production `EffectPlayer` lifecycle and
  `PresentationBudget`. It accepts the generated normalized runtime DTO, fixed
  seed `424242`, near/far LOD and synthetic origin/direction/hit/anchor context.
- **Weapon Range** consumes the same compiler and frozen catalog contract. Its
  fixed muzzle, fixed seed, moving/static shield/body/environment targets,
  damage range, four-shot ballistic trace and accepted/degraded/rejected budget
  result are deterministic.
- **Ship Dock** consumes the `cm2.world/1` World/Entity dependency. It exposes
  the real gamma strike-craft VOX, Body/Shape/Joint graph, anchor/mount/turret
  markers, camera and spawn/dispose/stale-handle lifecycle.

## Authority and isolation

The engine-free candidate is
`Content Mod 2/script/world/adapter/preview_suite_v1.lua`. Callers inject the
versioned compiler, frozen Catalog Authority, World/Entity adapter, EffectPlayer
and PresentationBudget. Preview never writes Runtime catalog state and does not
own damage, weapon fire, raycast, physics or networking authority.

`cm2SyntheticWorldAdapterV1.entity` is the disposable preview entity boundary.
It accepts normalized DTOs with an exact generation, rejects duplicate or stale
instances and never registers a gameplay ship. This keeps test setup separate
from the behavior being verified.

## Deterministic and live entries

`tools/cm2-preview/run-preview-suite-v1.ps1` writes the machine report
`docs/candidates/preview-suite-v1.result.json`. The paired self-test repeats
fixed-seed traces and rejects wrong compiler/catalog mutation/missing adapter,
moving target, VOX or stale-disposal coverage.

The disposable Teardown level is
`Content Mod 2/_ai_scenario_preview_suite.xml`; its controller is
`Content Mod 2/script/testing/scenario/preview_suite_controller.lua`. It is not
wired into `main.xml`, `main.lua` or the published Runtime catalog. Open the root
level XML from Mod Editor and use:

- `1`: Effect Lab;
- `2`: Weapon Range;
- `3`: Ship Dock;
- `Space` or `LMB`: replay the selected mode.

The live UI publishes the fixed seed, active mode, replay count, diagnostics and
catalog immutability result. The scene uses a fixed camera and preplaced VOX so
no manual flying, aiming or target search is needed. Objective visibility,
orientation, anchors and diagnostics are captured by Harness screenshot; visual
taste remains human review.

## Reload and rollback

Lua changes require Restart/reopen of the level. XML or VOX placement changes
require leaving the level and reopening `_ai_scenario_preview_suite.xml` from
Mod Editor. Do not use F5 alone as evidence that XML was reread.

Rollback is isolated: remove the root preview level/controller and disable the
preview entity fixture while retaining the deterministic fixture/result as an
audit baseline. The formal Runtime entry and generated catalog remain unchanged.
