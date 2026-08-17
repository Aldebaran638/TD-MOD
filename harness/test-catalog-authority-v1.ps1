$ErrorActionPreference = "Stop"
$checker = Join-Path $PSScriptRoot "check-catalog-authority-v1.ps1"
& $checker -Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($LASTEXITCODE -ne 0) { throw "catalog authority checker rejected the freeze gate" }
$module = Get-Content -Raw (Join-Path $PSScriptRoot "..\Content Mod 2\script\data\catalog\catalog_authority_v1.lua")
$ledger = Get-Content -Raw (Join-Path $PSScriptRoot "..\docs\catalog-legacy-removal-ledger-v1.json") | ConvertFrom-Json
if ($module -notmatch 'state\.frozen\s*=\s*true' -or $module -notmatch 'legacy definition registration is frozen' -or $module -notmatch 'definition override is frozen') { throw "post-freeze mutation rejection is incomplete" }
if (@($ledger.entries | Where-Object {$_.referenceScan.command -eq "" -or $_.rollback -eq ""}).Count -ne 0) { throw "legacy removal ledger lacks scan/rollback metadata" }
$manifest = Get-Content -Raw (Join-Path $PSScriptRoot "..\docs\generated\cm2-generated-catalog-manifest-v1.json") | ConvertFrom-Json
if ([string]$manifest.ownership.mode -ne "promoted" -or $manifest.ownership.promotionAllowed -ne $true) { throw "promoted candidate gate is missing" }
Write-Host "[PASS] Catalog Authority freezes source at init and rejects register/override after freeze"
Write-Host "[PASS] immutable lookup, init rollback and legacy-removal reference/rollback ledger are present"
Write-Host "[PASS] generated catalog is the promoted Runtime projection with legacy rollback available"
Write-Host "Self-test passed."
exit 0
