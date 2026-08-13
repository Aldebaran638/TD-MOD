# Creator SDK CLI Alpha v1

`tools/cm2-sdk/cm2-sdk.ps1` is the headless, project-root-driven Creator SDK
boundary for third-party Content Mod 2 packages. A project owns
`package.source.json`, public source-envelope definitions, assets, generated
data and `sdk.tool-lock.json`. Commands never read a hidden repository package
fixture when `ProjectPath` is supplied.

The CLI is deliberately data-only. It validates with the public
`PackageManifest v1` schema/validator, compiles project definitions with the
shared Definition Compiler, but does not publish the Compiler's Lua catalog.
The installable package contains JSON/data assets only and has
`entrypoints.runtime=data-only` plus `entrypoints.lua=null`.

## Project and command contract

Create a deterministic Hello Ship project and package it:

```powershell
& .\tools\cm2-sdk\cm2-sdk.ps1 -Command init -ProjectPath .\hello-ship
& .\tools\cm2-sdk\cm2-sdk.ps1 -Command validate -ProjectPath .\hello-ship
& .\tools\cm2-sdk\cm2-sdk.ps1 -Command package -ProjectPath .\hello-ship
```

`new` remains an alias for `init`. Both refuse to overwrite an existing root.
The generated project has five public source-envelope definitions (vehicle,
mount, weapon, projectile and effect), two assets and one generated DTO, so its
first `validate/build/package` needs no manual Runtime catalog work.

| Command | Purpose | Output/side effects |
| --- | --- | --- |
| `init` / `new` | Create a buildable Hello Ship project and exact tool lock. | Refuses an existing root. |
| `validate` | Hydrate source hashes, validate PackageManifest and run the shared Compiler. | Temporary files only. |
| `build` | Atomically publish the validated package and Compiler reports. | `ProjectPath/.cm2-sdk/build`. |
| `package` | Build an installable data-only package. | `ProjectPath/.cm2-sdk/package`. |
| `explain` | Report capabilities, dependency compatibility, budget and Core-only fallback. | Read-only. |
| `preview` | Run shared S0/S2/S5 headless preview contracts after project validation. | Temporary report only. |
| `test` | Compose package, Compiler and preview contracts. | Temporary files only. |
| `migrate` | Add explicit `cm2.package/0` migration provenance. | `ProjectPath/.cm2-sdk/migrated`. |
| `doctor` | Check schema/compiler and report live Teardown process state separately. | Read-only; Editor is not required. |
| `clean` | Remove only `build`, `package` or `migrated` below the project SDK root. | Fails closed outside approved leaves. |

## Build, diagnostics and rollback

Published output includes the canonical package artifact and report, manifest,
lock, resources, budget, Compiler manifest/report/diagnostics, fingerprint and
integrity-protected build report. It intentionally excludes
`compiler.catalog.lua`; that file is a temporary validation product, not a
public Runtime entrypoint.

Build reports exclude absolute paths, host names and timestamps. Independent
Windows/CI roots therefore emit byte-identical package artifacts, Compiler
manifests and build reports. Rebuilding moves the previous intact output to
`<target>.previous`. Invalid manifests, incompatible Core/SDK/dependency
ranges, unknown capabilities, private path references, Compiler diagnostics,
lock drift and generated-output drift all fail before publication and preserve
the last valid artifact exactly.

Every CLI failure has stable `code`, `packageId`, `definitionId`, `fieldPath`,
`message` and `suggestion` fields. A Compiler failure preserves its first
definition ID, field path and repair suggestion instead of collapsing the
diagnostic into a generic build exception.

## Verification

Run the deterministic regression:

```powershell
& .\tools\cm2-sdk\test-cm2-sdk-v1.ps1
```

The test creates independent Windows-workstation and clean-CI roots, builds and
packages twice, compares exact outputs, exercises all commands, verifies
rollback, and covers incompatible versions, unknown capability, Runtime Lua,
private reference, Compiler range, tool-lock, generated-drift and safe-clean
failures. The retained project fixture is
`testing/fixtures/creator_sdk/alpha_project`; its `.cm2-sdk/package` output is
the install source for the independent Teardown Consumer Mod regression.
