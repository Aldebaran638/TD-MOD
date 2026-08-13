# Self-test for Effect Profile Source v1.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-effect-profile-source.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $repositoryRoot 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$data = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "docs\effect-profiles-v1.json") | ConvertFrom-Json
if (@($data.references).Count -lt 400) { throw "weapon reference inventory is unexpectedly small" }
if (@($data.unresolved).Count -ne 0) { throw "unresolved references remain" }
if (@($data.profiles | Where-Object {$_.rendererVersion -eq ""}).Count -ne 0) { throw "renderer version contract is incomplete" }
Write-Host "[PASS] all current profile phases have namespaced source IDs, aliases and renderer contracts"
Write-Host "[PASS] weapon references resolve, budget/LOD metadata is present and builder output is deterministic"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
