# Asset Build Pipeline v1

This pipeline turns the read-only `AssetManifest v1` candidate into a
deterministic generated package. It is engine-free and does not promote
runtime catalog ownership.

## Stages

The fixed stage order is:

1. `import`
2. `validate`
3. `voxelize-convert`
4. `optimize`
5. `compile`
6. `package`

Every stage key includes the pipeline tool version, stage name, upstream
artifact hash, and canonical parameters. A clean build therefore produces
the same stage hashes and package bytes on another machine with the same
fixture and tool version. A changed tool version, source hash, or parameter
produces a new key and a cache miss.

The runner writes `build-report.json` for machines and `build-report.md` for
human inspection. Both reports contain the package hash, publication result,
stage cache keys/hashes, and budget values.

## Publication and recovery

Stages are written below a GUID staging directory. The generated package and
SHA-256 sidecar are published only after all stages and budget checks pass.
An existing package must have a matching sidecar before it can be replaced;
drift, invalid source, and stage failures fail closed and preserve the last
valid package. The generated package is marked `manualEdit=forbidden`.

## Verification

Run the fixture self-test:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\cm2-asset-build\test-asset-build-pipeline-v1.ps1
```

The test covers clean and incremental builds, byte-identical clean rebuilds,
tool-version cache invalidation, package drift, invalid source rollback, and
the body/shape/joint/package budget report. The live Teardown runtime is outside
this tool-only contract; preview and in-game loading belong to later steps.
