# v1 → v2 Version Upgrade and Rollback Drill

## Scope

The drill publishes an internal v1 Core/Schema/SDK envelope and three extension packages, migrates them and two saves to v2, preserves semantic golden identity, repeats the migration for idempotency, and restores an immutable v1 backup. It records phase timings, stable hashes, failure policies, and the rule that an old Core rejects future-required data instead of silently reading it.

All migration writes are isolated under a temporary directory. Repository source and generated artifacts are read-only; the v1 generated-artifact references are retained as the rollback backup.

## Run

    .\tools\cm2-upgrade\check-version-upgrade-rollback-drill-v1.ps1
    .\tools\cm2-upgrade\run-version-upgrade-rollback-drill-v1.ps1
    .\tools\cm2-upgrade\test-version-upgrade-rollback-drill-v1.ps1

The report is written to `docs/candidates/version-upgrade-rollback-drill-v1.result.json`. The headless drill currently passes all five phases and the existing compatibility/semantic/compiler suites. Its official result is `unable` because live v1 boot, v2 boot, Runtime rollback and runtime compatibility traces require Teardown.exe.

## Rollback and failure handling

Migration is one command, idempotent and atomic: missing fields, source hash mismatch or partial publish must produce a diagnostic error and no v2 publication. Restore the exact v1 manifest/package/save/generated-artifact backup and keep the failing fixture. A future-required schema must be rejected by old Core with an explicit error.
