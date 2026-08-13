# Creator SDK Beta v1 conformance

`docs/sdk-beta-v1.json` defines the Beta gate before inviting independent
authors. It models three profiles—data-only ship creator, weapon/effect creator
and CI/release maintainer—with editor-free workflows covering template,
validation, build, Preview, package, migration, explain, doctor, repeat and
clean/uninstall.

The Beta runner composes the existing Alpha CLI, clean-room package and
compatibility-policy suites. Four high-frequency blockers are recorded as
resolved: stable diagnostics, editor-independent builds, drift-safe previous
artifacts and idempotent/provenance-preserving migration. The report is
deterministic across repeated runs and does not modify Core Runtime files.

## Reproduction

```powershell
& .\tools\cm2-sdk-beta\check-sdk-beta-v1.ps1
& .\tools\cm2-sdk-beta\run-sdk-beta-v1.ps1
& .\tools\cm2-sdk-beta\test-sdk-beta-v1.ps1
```

The current report is `docs/candidates/sdk-beta-v1.result.json`. It records all
three profiles and all three conformance suites as passing, `editorFree=true`,
`repeatableBuild=true`, and a resolved blocker list.

This environment has no external author cohort and no Teardown.exe. The report
therefore keeps `externalAuthors=0`, `runtimeStatus=deferred` and
`s0s8=deferred-until-runtime`; those are release blockers, not silently passed
Beta criteria. Once an external cohort and game executable exist, rerun the
same fixture and append install/Preview/S0/S8 evidence. Rollback is to keep the
Alpha/internal SDK and remove Beta invitation metadata while retaining prior
package artifacts.
