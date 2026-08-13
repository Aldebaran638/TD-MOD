# Schema/Core/Package compatibility and deprecation policy v1

`docs/compatibility-policy-v1.json` is the public machine-readable authority
for schema, package, Core API, build-format and SDK compatibility. The public
PackageManifest validator calls the same resolver used by compatibility tests;
the policy is not a parallel documentation-only promise.

## Negotiation and supported window

Negotiation is ordered: package schema → Core API → source schema → build
format → SDK. Package schema `cm2.package/1`, Core API `>=1.0.0 <2.0.0`, SDK
`>=1.0.0 <2.0.0`, and build format `cm2.package-build/1` are supported. The
selected resolved Core/SDK versions must satisfy both this policy and the
package ranges. An empty intersection is an actionable failure; it never causes
a silent downgrade.

Major-0 Effect/Weapon sources and Package manifests are readable only through
`tools/cm2-compat/migrate-compat-v1.ps1`. Every write is canonical major 1.
The writer removes deprecated aliases, moves unknown optional Runtime fields to
`editor.compatibility.unknownRuntimeFields`, preserves unknown Editor metadata,
and rejects future-required or security-sensitive unknown fields before the
Compiler or Runtime.

The adapter never edits input in place and publishes output/report atomically.
Running it again on canonical v1 produces byte-equivalent data. Failed input
does not overwrite a pre-existing last-valid output or report.

## Deprecation lifecycle

Every ledger entry declares its owner, introduction and deprecation versions,
deprecation date, earliest removal version/date, replacement, diagnostic level,
writer-removal evidence, and reader-removal decision. “Writer removed the old
field” and “reader no longer accepts the old form” are separate facts:

- the v1 writer has verified tests proving deprecated aliases are absent;
- the major-0 reader remains supported until both the major-2 boundary and the
  earliest removal date are satisfied;
- removing it earlier is a checker failure, not a discretionary cleanup.

## Commands

```powershell
& .\tools\cm2-compat\check-compatibility-policy-v1.ps1
& .\tools\cm2-compat\test-compatibility-policy-v1.ps1
```

The regression covers current and migrated packages, compatible and
incompatible Core/SDK versions, missing required data, unknown optional data,
future/security fields, canonical alias deletion, idempotence, policy hashes,
last-valid preservation, and an independent disposable Teardown Consumer.

Rollback retains the original legacy source, the previous valid package/build
artifact, and the old reader until its removal window closes. Generated
migration output may be discarded without damaging source authority.
