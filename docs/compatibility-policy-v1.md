# Schema/Core/Package compatibility policy v1

`docs/compatibility-policy-v1.json` is the machine-readable compatibility
contract. Version negotiation is explicit and ordered as package → Core API →
schema → build format → SDK. The supported window is v1 (`1.x`) for each
surface; an empty intersection is a structured failure, never a silent
downgrade.

The policy is intentionally asymmetric:

- old major-0 documents may be read only through the explicit migration
  adapter;
- all writes are one canonical v1 form;
- unknown Editor/optional metadata is round-tripped outside Runtime projection;
- unknown required or security-sensitive Runtime fields and all future required
  schema majors fail before Compiler/Runtime;
- every deprecation has an owner, introduction/deprecation/removal versions,
  replacement and evidence requirement.

## Migration adapter

`tools/cm2-compat/migrate-compat-v1.ps1` never edits its input in place. It
supports `cm2.effect/0` and `cm2.package/0` fixtures, maps the published v0
aliases (`type`/`asset`, legacy weapon aliases), adds only deterministic v1
defaults, and records `migratedFrom`. Running it again on the v1 output writes
the same canonical document. Missing required fields, unsupported old majors
and future required majors return stable JSON diagnostics containing `code`,
`packageId`, `definitionId`, `fieldPath`, `message` and `suggestion`.

## Verification

```powershell
& .\tools\cm2-compat\check-compatibility-policy-v1.ps1
& .\tools\cm2-compat\test-compatibility-policy-v1.ps1
```

The self-test covers effect and package migration, v1 single-write output,
idempotence, unknown optional metadata preservation, missing fields, future
required fields and unsupported old versions. The current machine result is
`docs/candidates/compatibility-policy-v1.result.json`.

Rollback is to retain the previous valid package/build artifact and keep the
adapter enabled through each `removeAfter` version. Migration output is a new
file; the original package remains available for immediate downgrade.
