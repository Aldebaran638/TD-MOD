# Self-test for the bounded Presentation Event Ring contract.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-presentation-event-ring.ps1"
$runtime = Join-Path $repositoryRoot "Content Mod 2\script\weapon\client\presentation\event_runtime.lua"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2") 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$source = Get-Content -Raw -LiteralPath $runtime
if ($source -notmatch 'for _ = 1, ring\.count') { throw "ring iteration is not bounded by count" }
if ($source -notmatch 'while state\.critical\.count > 0' -or $source -notmatch 'while state\.ambient\.count > 0') { throw "drain ordering is missing" }
if ($source -notmatch 'state\.cancelled\s*=\s*state\.cancelled\s*\+\s*1') { throw "owner cancellation accounting is missing" }
Write-Host "[PASS] fixed capacities and bounded head/tail ring operations are present"
Write-Host "[PASS] Critical/Ambient policy, source ordering diagnostics and owner cancellation are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
