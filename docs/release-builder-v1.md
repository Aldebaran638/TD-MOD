# CM2 → Global Mod Release Builder v1

`sync-cm2-to-global.ps1 -Release` is the release path for the source-of-truth
contract. The existing incremental sync remains available when `-Release` is
omitted; release mode is the only path used for a publish artifact.

## Build flow

1. Run focused preflight gates over the selected Content tree: entry closure,
   Lua/API/XML, Schema v1, generated-catalog ownership, weapon profile/layout,
   explicit weapon/component definitions and ship definitions. A non-zero gate
   stops before staging or touching Global.
2. Hash the complete Content source tree and pin `source_revision` to
   `tree:<sha256>` (or use an explicit `-SourceRevision`). The generator is
   pinned by the script SHA-256. `generated_at` is a deterministic marker based
   on the source hash, so two clean workspaces do not diverge because of wall
   clock time.
3. Copy the existing Global baseline into a disposable staging directory,
   replace the managed `script`, `gfx`, `prefabs`, `sound` and `vox` trees from
   Content, regenerate `main.lua` and the battlecruiser spawn fragment, and
   write `release-manifest.json`.
4. Compute `package_hash`, managed-tree hashes and an `output_hash` over the
   staged payload (excluding the manifest itself). Move the previous Global
   target to `<ReleaseRoot>/previous`, then rename staging into place. A failed
   rename restores the previous target.
5. Verify the published payload hash and write `<ReleaseRoot>/rollback.json`.

The manifest records source/generator revisions, source-of-truth hash,
preflight results, managed mappings, preserved unmanaged legacy files, package
and output hashes, generated-only policy and the rollback location. Global Mod
remains generated output; manual edits are forbidden by the manifest contract.

## Usage

Preview without publishing:

```powershell
& .\sync-cm2-to-global.ps1 -Release -WhatIf
```

Publish the normal target (the command creates `.cm2-release/previous` and
`.cm2-release/rollback.json`):

```powershell
& .\sync-cm2-to-global.ps1 -Release
```

For CI or a clean-room check, override `-SourceRoot`, `-TargetRoot` and
`-ReleaseRoot`. `-SkipPreflight` exists only for an explicitly isolated tool
experiment; normal releases must retain the preflight gates.

## Verification record

Run:

```powershell
& .\tools\test-release-builder-v1.ps1
```

The test copies Content and the existing Global baseline into two independent
temporary workspaces, publishes both, and proves that release manifests and
all target bytes are identical. It also proves WhatIf byte preservation,
preflight failure before publication, last-valid-target preservation, and the
presence of `previous` plus `rollback.json`. The machine result is recorded in
`docs/candidates/release-builder-v1.result.json`.

No live Teardown smoke is claimed by this script. It verifies the source,
generated payload and rollback contract; S0–S8/Workshop runtime evidence must
be appended when Teardown.exe is available. Rollback is to move the explicit
`previous` directory back to Global Mod, or to stop publishing and retain the
last valid artifact.
