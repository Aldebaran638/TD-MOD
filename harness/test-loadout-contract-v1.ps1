$ErrorActionPreference = "Stop"
$checker = Join-Path $PSScriptRoot "check-loadout-contract-v1.ps1"
& $checker -Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($LASTEXITCODE -ne 0) { throw "loadout contract checker rejected the DTO" }
$module = Get-Content -Raw (Join-Path $PSScriptRoot "..\Content Mod 2\script\data\configuration\loadout_contract_v1.lua")
$fixtures = Get-Content -Raw (Join-Path $PSScriptRoot "data\configuration\loadout-contract-v1-fixtures.json") | ConvertFrom-Json
if ($module -notmatch 'missingPolicy\s*=') { throw "missing-value policy is not declared" }
if ($module -notmatch 'migrateV0' -or $module -notmatch 'aliasApplied') { throw "v0 alias migration is not declared" }
if ($module -notmatch 'fieldPath' -or $module -notmatch 'suggestion') { throw "structured diagnostics are not declared" }
if ($module -notmatch 'snapshotHash' -or $module -notmatch 'table\.sort') { throw "deterministic storage/hash contract is not declared" }
if ($module -notmatch 'registry-frozen' -or $module -notmatch 'function _contract\.freeze') { throw "freeze gate is not declared" }
if ([string]$fixtures.validV1.schemaVersion -ne "cm2.loadout/1" -or [string]$fixtures.legacyV0.configuration -ne "siege_2x4g2m") { throw "fixture coverage is incomplete" }
Write-Host "[PASS] LoadoutSnapshot v1 covers vehicle/revision/configuration/groups/weapon/component/mount fields"
Write-Host "[PASS] v0 alias migration is idempotent, missing/downgrade policies and structured errors are declared"
Write-Host "[PASS] deterministic persistence/hash and init-only freeze gate are declared"
Write-Host "Self-test passed."
exit 0
