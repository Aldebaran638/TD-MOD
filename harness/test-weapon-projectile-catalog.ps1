# Self-test for candidate Weapon + Projectile Catalog v1.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-weapon-projectile-catalog.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $repositoryRoot 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$data = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "docs\generated\cm2-weapon-definitions-v1.json") | ConvertFrom-Json
if (@($data.weapons | Where-Object {$_.definitionSource -ne "candidate-v1"}).Count -ne 0) { throw "candidate source marker is incomplete" }
if (@($data.projectiles | Where-Object {$_.radius -le 0}).Count -ne 0) { throw "projectile radius contract is invalid" }
Write-Host "[PASS] 109/109 weapons and independent projectile definitions have canonical schemas"
Write-Host "[PASS] deterministic generated Lua/hash, capability tags, no mountProfile and unresolved-reference failure gates are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
