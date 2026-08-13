# Self-test for the Step 2.1 Presentation Publisher contract.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-presentation-publisher.ps1"
$publisher = Join-Path $repositoryRoot "Content Mod 2\script\net\presentation_publisher.lua"
$eventRuntime = Join-Path $repositoryRoot "Content Mod 2\script\weapon\client\presentation\event_runtime.lua"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2") 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$source = Get-Content -Raw -LiteralPath $publisher
$client = Get-Content -Raw -LiteralPath $eventRuntime
if ($source -notmatch 'mode\s*=\s*"legacy"') { throw "legacy is not the safe default" }
if ($source -notmatch 'requested\s*~=\s*"legacy"\s*and\s*requested\s*~=\s*"event-v1"') { throw "unsupported mode fallback is missing" }
if ($source -notmatch 'state\.legacyAdapterCalls\s*=\s*state\.legacyAdapterCalls\s*\+\s*1') { throw "legacy adapter counter is missing" }
if ($source -notmatch 'state\.eventV1Calls\s*=\s*state\.eventV1Calls\s*\+\s*1') { throw "event-v1 counter is missing" }
if ($client -notmatch '_newRing\(128\)' -or $client -notmatch '_newRing\(32\)') { throw "bounded client rings are missing" }
Write-Host "[PASS] legacy default and init-only event-v1 switch are present"
Write-Host "[PASS] legacy/event-v1 counters, DTO validation and bounded client queue are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
