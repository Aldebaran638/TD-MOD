# Regression test for multiplayer, Save/Load and lifecycle Soak v1.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
$checker = Join-Path $PSScriptRoot "check-multiplayer-lifecycle-soak-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-multiplayer-lifecycle-soak-v1.ps1"
$policy = Join-Path $root "docs\multiplayer-lifecycle-soak-v1.json"
$fixture = Join-Path $root "docs\candidates\multiplayer-lifecycle-soak-v1.fixture.json"
$report = Join-Path $root "docs\candidates\multiplayer-lifecycle-soak-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-soak-" + [Guid]::NewGuid().ToString("N") + ".json")
function Assert-True([bool]$condition, [string]$message) { if (-not $condition) { throw ("Multiplayer/Lifecycle Soak v1 failed: " + $message) }; Write-Host ("[PASS] " + $message) -ForegroundColor Green }
function Invoke-Script([string]$path, [string[]]$arguments) { $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @arguments *> $null; $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved; return $code }
try {
    Assert-True ((Invoke-Script $checker @("-PolicyPath", $policy, "-FixturePath", $fixture)) -eq 0) "static Soak policy and fixture checker passes"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "headless Soak runner completes"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.multiplayer-lifecycle-soak-report/1" -and [string]$first.status -eq "headless-candidate") "report schema and candidate status are explicit"
    Assert-True ([string]$first.result -eq "unable" -and [bool]$first.headlessPass) "headless state machine passes while live Runtime is honestly unable"
    Assert-True (@($first.scenarios).Count -eq 8 -and @($first.scenarios | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0) "host/remote, lock, fire, turret, death, respawn, late-join and reconnect scenarios pass"
    Assert-True (@($first.saveLoad).Count -eq 4 -and @($first.saveLoad | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0) "same, missing, downgrade and migration Save/Load cases pass explicitly"
    Assert-True (@($first.suites).Count -eq 6 -and @($first.suites | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0) "six existing lifecycle/package suites pass"
    Assert-True ([int]$first.queue.commandDepthAfterDrain -eq 0 -and [int]$first.queue.snapshotDepthAfterDrain -eq 0) "command and snapshot queues drain"
    Assert-True ([int]$first.queue.commandHighWatermark -le 32 -and [int]$first.queue.snapshotHighWatermark -le 64) "queue high watermarks stay within capacity"
    Assert-True ([int]$first.lifecycle.cycles -ge 1800 -and [int]$first.lifecycle.staleLiveHandles -eq 0 -and [int]$first.lifecycle.ownerLeaseLeaks -eq 0) "1800 lifecycle churn cycles leave no stale live handle or lease leak"
    Assert-True ([int]$first.lifecycle.duplicateDamage -eq 0 -and [int]$first.lifecycle.duplicateEntities -eq 0 -and [int]$first.lifecycle.resurrections -eq 0 -and [int]$first.lifecycle.orphanEffect -eq 0 -and [int]$first.lifecycle.orphanVoice -eq 0 -and [int]$first.lifecycle.orphanJoint -eq 0) "damage/entity resurrection and Effect/Voice/Joint orphan counters remain zero"
    Assert-True ([double]$first.memory.memorySlopeBytesPerMinute -eq 0 -and [int]$first.memory.activeCountFinal -eq 0) "headless warmup memory/active-count slope is platformized"
    Assert-True ($null -ne $first.runtime.PSObject.Properties["teardownAvailable"] -and [string]$first.runtime.status -in @("deferred", "not-run")) "live Teardown availability is disclosed without fabricating a pass"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second Soak run completes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$first.determinismHash -eq [string]$second.determinismHash) "Soak report is deterministic"
    Write-Host "Multiplayer/Lifecycle Soak v1 regression passed (live 30-minute evidence remains deferred)." -ForegroundColor Green
    exit 0
}
finally { if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue } }
