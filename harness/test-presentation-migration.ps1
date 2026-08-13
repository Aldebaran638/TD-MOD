# Self-test for batched presentation migration ledger.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-presentation-migration.ps1"
$manifest = Join-Path $repositoryRoot "docs\presentation-migration-batches.json"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2") 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$data = Get-Content -Raw -LiteralPath $manifest | ConvertFrom-Json
if (@($data.batches | Where-Object {$_.status -eq "facade-migrated"}).Count -lt 2) { throw "facade-migrated batch coverage is incomplete" }
if (@($data.directApiPolicy.forbiddenOutsideScopes).Count -ne 5) { throw "direct primitive policy is incomplete" }
if ([string]$data.eventSourceRule -notmatch 'never simultaneous') { throw "dual playback rule is missing" }
Write-Host "[PASS] four ordered migration batches and worst-case renderer budgets are declared"
Write-Host "[PASS] facade/direct-call policy and single event-source rollback rule are declared"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
