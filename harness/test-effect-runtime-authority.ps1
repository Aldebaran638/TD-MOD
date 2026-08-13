# Self-test for Effect Runtime authority cutover.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-effect-runtime-authority.ps1"
$fixture = Join-Path $repositoryRoot "harness\data\presentation\effect-runtime-authority-fixtures.json"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2") 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$data = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
if ([string]$data.rollback -ne "effectRuntime=legacy") { throw "atomic legacy rollback is missing" }
if (@($data.firstBatchRemoval).Count -lt 3) { throw "first-batch cleanup list is incomplete" }
$source = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "Content Mod 2\script\net\effect_runtime_authority.lua")
if ($source -notmatch 'state\.dualPlaybackRejected\s*=\s*state\.dualPlaybackRejected\s*\+\s*1') { throw "dual-playback rejection counter missing" }
Write-Host "[PASS] legacy/event-v1 authority modes and atomic rollback are declared"
Write-Host "[PASS] dual playback rejects/counts and first old-path cleanup gates are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
