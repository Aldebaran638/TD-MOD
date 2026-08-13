# TurretDefinition v1 and fixture (Step 7.1)

The first Gate-7 artifact is a compiler contract, not player-facing content.
`cm2TurretDefinitionV1` accepts a versioned DTO with:

- `basePartId` and `baseAnchorId` references;
- yaw/pitch axes, finite min/max limits, speed and damping;
- targeting filters/range and fire-control cooldown/salvo settings;
- explicit weapon groups and muzzle anchor IDs.

Compilation rejects schema mismatches, missing references, inverted limits,
duplicate groups and `playerFacing=true`. A compiled definition is permanently
marked `fixtureOnly=true`. `fixtureSpawn` only creates a serializable DTO,
clamps the requested joint angle to the declared limit, and can be disposed;
there is no engine Joint/Body creation and no formal turret dependency.

The fixture uses one wing part, one base anchor, two muzzle anchors, a yaw range
of `[-70°, +70°]` and a pitch range of `[-25°, +35°]`. The offline runner and
self-test cover compile/spawn/snapshot/dispose, angle clamping, missing anchor,
inverted limit, duplicate group, player-facing and stale-generation negatives.

Rollback is to remove/bypass the fixture compiler and keep the multi-body
experiment out of production. Do not promote a definition to player content
until Gate 7 runtime joint, target-filter, network and performance evidence is
captured in Teardown.
