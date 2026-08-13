# Static contract checker for LoadoutSnapshot v1 and its legacy adapter.

param([string]$Path = ".")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$module = Join-Path $root "Content Mod 2\script\data\configuration\loadout_contract_v1.lua"
$catalog = Join-Path $root "Content Mod 2\script\shipMain.lua"
$fixturesPath = Join-Path $root "harness\data\configuration\loadout-contract-v1-fixtures.json"
$docs = Join-Path $root "docs\loadout-configuration-contract-v1.md"
$issues = New-Object System.Collections.Generic.List[string]
foreach ($required in @($module, $catalog, $fixturesPath, $docs)) { if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { [void]$issues.Add("missing loadout contract artifact: $required") } }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $module
    if ($source -match '#include|GetBody|GetVehicle|Spawn|PlaySound|Query') { [void]$issues.Add("Loadout DTO must not depend on Teardown APIs/includes") }
    foreach ($required in @("cm2.loadout/1", "currentRevision", "missingPolicy", "registerConfigurationAlias", "freeze", "isFrozen", "validate", "migrateV0", "validateAgainstFit", "encode", "snapshotHash")) {
        if ($source -notmatch [regex]::Escape($required)) { [void]$issues.Add("Loadout DTO missing contract member: $required") }
    }
    foreach ($field in @("code", "fieldPath", "expected", "actual", "suggestion")) { if ($source -notmatch [regex]::Escape($field)) { [void]$issues.Add("structured diagnostic field missing: $field") } }
    if ($source -notmatch 'registry-frozen' -or $source -notmatch '_frozen') { [void]$issues.Add("runtime registration freeze gate is missing") }
    $strikeCraft = Join-Path $root "Content Mod 2\script\strikeCraftMain.lua"
    if ((Get-Content -Raw -LiteralPath $catalog) -notmatch '#include "data/configuration/loadout_contract_v1\.lua"' -or (Get-Content -Raw -LiteralPath $strikeCraft) -notmatch '#include "data/configuration/loadout_contract_v1\.lua"') { [void]$issues.Add("ship entry points do not include the shared Loadout DTO") }
    try { $fixtures = Get-Content -Raw -LiteralPath $fixturesPath | ConvertFrom-Json }
    catch { [void]$issues.Add("loadout fixtures are invalid JSON: $($_.Exception.Message)") }
    if ($null -ne $fixtures) {
        if ([string]$fixtures.validV1.schemaVersion -ne "cm2.loadout/1") { [void]$issues.Add("valid v1 fixture schema mismatch") }
        if ([string]$fixtures.validV1.vehicleId -notmatch '^cm2:vehicle/') { [void]$issues.Add("valid v1 fixture vehicle ID is not namespaced") }
        if ([string]$fixtures.legacyV0.configuration -ne "siege_2x4g2m") { [void]$issues.Add("legacy alias fixture is missing") }
        if ([string]$fixtures.invalidDowngrade.revision -ne "0") { [void]$issues.Add("downgrade fixture is missing") }
    }
}
if ($issues.Count -gt 0) { Write-Error ("Loadout contract v1 check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Loadout contract v1 passed: DTO, v0 alias migration, diagnostics, fit validation, deterministic storage and freeze gate are present." -ForegroundColor Green
exit 0
