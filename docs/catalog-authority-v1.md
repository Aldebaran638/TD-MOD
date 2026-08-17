# Catalog Authority v1 and Legacy Removal Gate

`Content Mod 2/script/data/catalog/catalog_authority_v1.lua` is the init-time
authority boundary for the Gate 3 catalog cutover. It freezes the selected
source, exposes immutable lookup, counts/rejects legacy definition registration
and override attempts after freeze, and provides a new-context rollback path.
The two ship entry points initialize it before Runtime ticks.

The current generated manifest is `candidate-active`, `promoted`, and
`promotionAllowed=true`. Live Teardown evidence proves the generated Runtime
projection and its semantic parity, while the legacy schemas and registries
remain available as an explicit init-time rollback source. Every proposed
removal is recorded in `docs/catalog-legacy-removal-ledger-v1.json` with an
actual reference-scan command, current status, removal gate and rollback
version/path. The offline compiler remains retained because it is required to
reproduce the previous valid catalog.

The promotion evidence is recorded in
`docs/evidence/step-3.5-generated-catalog-v1.json`: generated manifest/hash
pass, live parity, Runtime projection load, telemetry continuity and cleanup.
Deletion of `weaponDefine*`, `shipDefinitionRegister`, `shipComponentDefine`
or profile registries remains a separate Gate 3.6 decision and is blocked until
its removal evidence and rollback criteria are satisfied.
