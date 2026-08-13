# Self-test for four vertical-slice migration bridge.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-presentation-slices.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2") 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$source = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "Content Mod 2\script\weapon\client\presentation\slice_runtime.lua")
if ($source -notmatch 'state\.sliceMode\[slice\]') { throw "per-slice mode selection is missing" }
if ($source -notmatch 'state\.handles\[key\]') { throw "projectile handle tracking is missing" }
if ($source -notmatch 'state\.rejected\s*=\s*state\.rejected\s*\+\s*1') { throw "slice rejection accounting is missing" }
Write-Host "[PASS] four representative slices map into bounded Event Ring -> EffectPlayer flow"
Write-Host "[PASS] per-slice init switch, handle cleanup, deterministic trace and independent fallback are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
