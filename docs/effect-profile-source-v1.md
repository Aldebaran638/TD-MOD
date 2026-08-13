# Versioned Effect Profile Source v1

Gate 3 Step 3.1 materializes the current client profile vocabulary as a
deterministic source artifact: [effect-profiles-v1.json](effect-profiles-v1.json).
The builder inventories charge, beam, muzzle, impact, projectile, trail, craft,
shake and sound IDs from the current dispatch plus all weapon-definition
references. Each entry has a namespaced ID, schema version, legacy alias, renderer
contract/version, worst-case cost, LOD range, owner policy and termination policy.

The source currently contains 108 profiles, 108 aliases and 437 scanned weapon
references with zero unresolved references. Legacy IDs remain aliases; the source
does not silently turn missing IDs into a default profile. The builder is
deterministic and fails when a reference cannot be resolved. Existing runtime
lookup remains the rollback path until Preview and live lookup call-count evidence
are available.
