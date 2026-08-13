# Catalog Authority v1 and Legacy Removal Gate

`Content Mod 2/script/data/catalog/catalog_authority_v1.lua` is the init-time
authority boundary for the Gate 3 catalog cutover. It freezes the selected
source, exposes immutable lookup, counts/rejects legacy definition registration
and override attempts after freeze, and provides a new-context rollback path.
The two ship entry points initialize it before Runtime ticks.

The current generated manifest is intentionally `legacy-active`, `shadow`, and
`promotionAllowed=false`: the candidate catalog is available for offline
comparison but cannot become default without live Teardown evidence. Therefore
the legacy schemas and registries are not deleted prematurely. Every proposed
removal is recorded in `docs/catalog-legacy-removal-ledger-v1.json` with an
actual reference-scan command, current status, removal gate and rollback
version/path. The offline compiler remains retained because it is required to
reproduce the previous valid catalog.

Promotion requirements are: generated manifest/hash pass, zero legacy runtime
call counters for two releases, complete S0–S8 parity, and a tested rollback to
the previous generated hash. Until then, deletion of `weaponDefine*`,
`shipDefinitionRegister`, `shipComponentDefine` or profile registries is
blocked by policy and by the Harness checker.
