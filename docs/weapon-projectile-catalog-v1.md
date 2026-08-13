# Weapon + Projectile Catalog v1

Gate 3 Step 3.2 generates a candidate catalog from the Gate 1 semantic snapshot:

- 109/109 weapons are emitted as `cm2:weapon/<legacyId>` definitions.
- 75 projectile definitions are emitted independently with simulation mode,
  speed, lifetime, radius, guidance, collision, network and active-budget data.
- Weapon definitions contain slot capability tags, behavior/fire/damage data and
  canonical effect/sound references; the legacy `mountProfile` field is absent.
- `docs/generated/cm2-weapon-catalog-v1.lua` is an explicit, deterministic,
  generated artifact with a SHA-256 sidecar. It is not yet included by Runtime;
  ownership remains `candidate-v1` until live parity evidence is available.

The builder fails on snapshot count mismatch or unresolved profile references and
never changes the legacy catalog. Each candidate batch can therefore be discarded
or selected through the existing authority/ownership rollback switches.
