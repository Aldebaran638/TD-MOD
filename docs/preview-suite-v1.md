# Preview Suite v1

Step 8.3 adds three independent, headless-verifiable Preview surfaces:

- **Effect Lab** uses the production `EffectPlayer` and `PresentationBudget`.
  It accepts a generated normalized runtime DTO, a fixed seed, near/far LOD,
  synthetic origin/direction/hit/normal/anchor context, and a bounded replay.
- **Weapon Range** uses the same compiler and frozen catalog. A fixed muzzle,
  fixed seed, deterministic moving target, shield/body/environment target types,
  damage range, ballistic trace, and budget result are recorded as one replay.
- **Ship Dock** uses the same World/Entity adapter. It exposes the imported VOX
  source, EntityGraph Body/Shape/Joint counts, anchor/mount/turret tree, camera,
  engine markers, spawn/snapshot/dispose and stale-handle rejection.

The candidate module is `Content Mod 2/script/world/adapter/preview_suite_v1.lua`.
The caller injects the production compiler, generated Catalog Authority,
`cm2.world/1` World/Entity adapter, EffectPlayer and PresentationBudget. Preview
does not include a second physics/effect implementation and never writes the
runtime catalog. The fixture records the shared authority IDs and the required
S0/S2/S5 replay checkpoints.

`tools/cm2-preview/run-preview-suite-v1.ps1` performs the deterministic contract
run and writes `docs/candidates/preview-suite-v1.result.json`. It repeats the
fixed-seed traces, checks the normalized DTO/authority closure, checks Ship Dock
lifecycle and verifies runtime-catalog immutability. `test-preview-suite-v1.ps1`
adds negative fixtures for authority mismatch, catalog mutation, missing adapter,
missing moving target and incomplete Ship Dock data.

Screenshot and recording exports are diagnostic descriptors only in this step.
They explicitly say `runtimeRequired=true`; no Teardown executable is installed
on this machine, so live rendering, capture, replay playback, physics cost and
frame-time pressure remain deferred runtime evidence rather than fabricated
headless claims.

Rollback is isolated: do not wire this candidate into `main.xml`, `main.lua`, or
the Runtime catalog. Disable the Preview entrypoint and remove its candidate
registration while retaining the fixture/result as the audit baseline. Runtime
source and generated catalog remain the last valid versions.
