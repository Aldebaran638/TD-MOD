# Static Gate 3.6 authority/freeze and legacy-removal ledger checker.

param([string]$Path = ".")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$module = Join-Path $root "Content Mod 2\script\data\catalog\catalog_authority_v1.lua"
$manifest = Join-Path $root "docs\generated\cm2-generated-catalog-manifest-v1.json"
$ledger = Join-Path $root "docs\catalog-legacy-removal-ledger-v1.json"
$shipMain = Join-Path $root "Content Mod 2\script\shipMain.lua"
$strikeMain = Join-Path $root "Content Mod 2\script\strikeCraftMain.lua"
$issues = New-Object System.Collections.Generic.List[string]
foreach ($required in @($module, $manifest, $ledger, $shipMain, $strikeMain)) { if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { [void]$issues.Add("missing authority artifact: $required") } }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $module
    foreach ($required in @("cm2CatalogAuthorityV1", "authority.init", "authority.isFrozen", "authority.registerLegacyDefinition", "authority.overrideDefinition", "authority.lookup", "authority.rollbackAtInit", "authority.getReport", "state.frozen", "rejectedAfterFreeze")) {
        if ($source -notmatch [regex]::Escape($required)) { [void]$issues.Add("authority module missing member: $required") }
    }
    if ($source -match '#include|GetBody|GetVehicle|Spawn|PlaySound') { [void]$issues.Add("authority module must remain engine-independent") }
    foreach ($entry in @($shipMain, $strikeMain)) {
        if ((Get-Content -Raw -LiteralPath $entry) -notmatch '#include "data/catalog/catalog_authority_v1\.lua"') { [void]$issues.Add("entry does not include Catalog Authority: $entry") }
        if ((Get-Content -Raw -LiteralPath $entry) -notmatch 'cm2CatalogAuthorityV1\.init\(\)') { [void]$issues.Add("entry does not initialize Catalog Authority: $entry") }
    }
    try { $gate = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json }
    catch { [void]$issues.Add("generated manifest JSON invalid: $($_.Exception.Message)") }
    if ($null -ne $gate -and ([string]$gate.ownership.runtimePolicy -ne "legacy-active" -or [string]$gate.ownership.mode -ne "shadow" -or $gate.ownership.promotionAllowed -ne $false)) { [void]$issues.Add("manifest is not legacy-safe shadow ownership") }
    try { $removal = Get-Content -Raw -LiteralPath $ledger | ConvertFrom-Json }
    catch { [void]$issues.Add("legacy removal ledger JSON invalid: $($_.Exception.Message)") }
    if ($null -ne $removal) {
        if ([string]$removal.schemaVersion -ne "cm2.catalog-removal-ledger/1" -or @($removal.entries).Count -lt 6) { [void]$issues.Add("legacy removal ledger schema/coverage is incomplete") }
        foreach ($item in @($removal.entries)) {
            foreach ($field in @("id", "path", "status", "referenceScan", "removalGate", "rollback")) { if ($null -eq $item.PSObject.Properties[$field] -or [string]$item.$field -eq "") { [void]$issues.Add("removal ledger field missing: $($item.id)/$field") } }
            if ($null -ne $item.referenceScan -and ([string]$item.referenceScan.command -eq "" -or [string]$item.referenceScan.result -eq "")) { [void]$issues.Add("removal ledger reference scan incomplete: $($item.id)") }
            if (([string]$item.status -eq "removed") -and ([string]$item.referenceScan.expectedAfterPromotion -eq "")) { [void]$issues.Add("removed item has no post-promotion reference gate: $($item.id)") }
        }
    }
    $candidateInclude = & rg -n --fixed-strings "cm2-generated-catalog-v1.lua" (Join-Path $root "Content Mod 2\script") 2>$null
    if ($LASTEXITCODE -eq 0 -and $candidateInclude) { [void]$issues.Add("generated catalog is included before authority promotion") }
}
if ($issues.Count -gt 0) { Write-Error ("Catalog Authority v1 check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Catalog Authority v1 passed: init freeze, post-freeze rejection, immutable lookup, shadow-safe manifest and removal ledger gates are present." -ForegroundColor Green
exit 0
