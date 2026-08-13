# Creator SDK CLI Alpha v1

`tools/cm2-sdk/cm2-sdk.ps1` is the first headless Creator SDK boundary for
third-party Content Mod 2 packages. It is deliberately data-only: it reuses
the PackageManifest validator, the existing Definition Compiler contract and
the Preview Suite builder; it does not load or generate Runtime Lua. The CLI is
therefore usable on a clean-room machine without a Teardown installation, while
live visual preview remains an explicit follow-up capability.

## Command contract

| Command | Purpose | Safe output/side effects |
| --- | --- | --- |
| `new` | Create `definitions`, `assets`, `generated`, a manifest template and a pinned tool lock. | Refuses to overwrite an existing destination. |
| `validate` | Validate the shared PackageManifest and report its deterministic hash. | Read-only. |
| `build` | Validate, stage and atomically publish `manifest.json`, `lock.json`, `resources.json`, `budget.json`, `fingerprint.sha256` and `build-report.json`. | Previous output is retained as `.previous`; drifted output cannot be overwritten. |
| `explain` | Present capabilities, dependency graph, budgets and Runtime-Lua policy. | Read-only. |
| `preview` | Execute the shared Effect Lab/Weapon Range/Ship Dock S0/S2/S5 contract. | Read-only report; live Teardown is optional. |
| `test` | Run package and preview acceptance contracts and return both hashes. | Read-only. |
| `package` | Alias of deterministic build with a package-oriented output root. | Same atomic publication and rollback rules as `build`. |
| `migrate` | Write `manifest.migrated.json` with explicit `cm2.package/0` provenance. | Writes only the requested migration directory. |
| `doctor` | Check schema/compiler availability and report whether `Teardown.exe` is installed. | Read-only; missing Teardown is a warning for data-only commands. |
| `clean` | Remove a named SDK-owned `build`, `package`, `migrated` or `new-package` leaf. | Rejects paths outside a `.cm2-sdk` root. |

All failures use the stable fields `code`, `packageId`, `definitionId`,
`fieldPath`, `message`, and `suggestion`. Typical gates are `validate-failed`,
`tool-version`, `generated-drift`, `preview-fixture`, and `unsafe-clean`.

## Reproducibility and rollback

The build uses the PackageManifest artifact fingerprint as
`fingerprint.sha256`. The canonical JSON report excludes absolute paths,
timestamps and host-specific values, so independent output roots produce the
same report hash. A successful publication moves an existing target to
`<target>.previous`; a failed validation or drift check leaves the last valid
target untouched. Generated reports are protected by a companion
`build-report.sha256` file.

The package capability boundary remains data-only (`runtimeLua=false`). The CLI
accepts only the locked SDK/compiler/importer/preview versions and leaves the
runtime catalog unchanged. Unknown packages still use the existing builtin-only
fallback policy.

## Verification

Run the deterministic self-test:

```powershell
& .\tools\cm2-sdk\test-cm2-sdk-v1.ps1
```

The self-test covers template creation, validation, build output completeness,
repeatability across two roots, explain/preview/test/package/migrate/doctor,
stable diagnostic fields, failure preservation, generated drift protection,
tool-lock rejection, and safe/unsafe clean behavior. In this step the test
passed all assertions. The full project Harness is still the final gate after
any implementation edit. No Teardown executable is installed in the current
environment, so live S0/S2/S5 rendering evidence is deferred; the headless
preview contract remains covered by the shared Preview Suite.

Rollback is intentionally small: remove the SDK output root, restore the
`.previous` directory, or disable third-party packages and retain builtin
catalog entries. No Core Runtime Lua or generated runtime catalog is modified
by this CLI.
