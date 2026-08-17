# Catalog Authority v1

`Content Mod 2/script/data/catalog/catalog_authority_v1.lua` is the init-time
authority boundary for the Gate 3 catalog cutover. Both production entry
points include and initialize it before Runtime ticks.

The boundary has four states:

- Legacy definition files may import into private bootstrap buckets only while
  the entry closure is being assembled.
- The authority validates the generated candidate manifest, builds one frozen
  projection, and publishes the vehicle, weapon, and component maps used by
  Runtime.
- Bootstrap buckets are cleared before the authority freezes. Runtime lookup
  never reads the legacy registries.
- `registerLegacyDefinition` and `overrideDefinition` are rejected after the
  freeze and counted. A new context may request `legacy` or `rollback` only as
  an explicit rollback source; there is no implicit legacy fallback.

The generated manifest is `candidate-active`, `promoted`, and
`promotionAllowed=true`. The live Step 3.6 evidence records two fresh editor
reloads, candidate authority telemetry, 114/114 parity, five registered
production entries, zero Runtime register/override calls, zero in-scope log
errors or warnings, and cleanup back to the editor.

Legacy source files are not silently deleted. The removal ledger records each
remaining init-import adapter, migration alias, presentation adapter, and
offline compiler with its reference scan, owner boundary, removal gate, and
rollback artifact. This keeps rollback reproducible without restoring a second
Runtime authority.
