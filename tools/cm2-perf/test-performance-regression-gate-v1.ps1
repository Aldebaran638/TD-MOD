# Regression test for the versioned performance regression gate.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
$checker = Join-Path $PSScriptRoot "check-performance-regression-gate-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-performance-regression-gate-v1.ps1"
$policy = Join-Path $root "docs\performance-regression-gate-v1.json"
$fixture = Join-Path $root "docs\candidates\performance-regression-gate-v1.fixture.json"
$report = Join-Path $root "docs\candidates\performance-regression-gate-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-performance-gate-" + [Guid]::NewGuid().ToString("N") + ".json")
function Assert-True([bool]$condition, [string]$message) { if (-not $condition) { throw ("Performance Regression Gate v1 failed: " + $message) }; Write-Host ("[PASS] " + $message) -ForegroundColor Green }
function Invoke-Script([string]$path, [string[]]$arguments) { $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @arguments *> $null; $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved; return $code }
try {
    Assert-True ((Invoke-Script $checker @("-PolicyPath", $policy, "-FixturePath", $fixture)) -eq 0) "static performance policy and fixture checker passes"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "headless performance gate completes"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.performance-regression-report/1" -and [string]$first.status -eq "headless-candidate") "report schema and candidate status are explicit"
    Assert-True ([string]$first.result -eq "unable" -and [bool]$first.headlessPass -and [string]$first.gateDecision -eq "unable") "headless gate passes while live performance evidence remains honestly unable"
    Assert-True (@($first.metrics).Count -eq 7 -and @($first.metrics | Where-Object { [string]$_.status -ne "pass" -or -not [bool]$_.variancePass -or -not [bool]$_.thresholdPass }).Count -eq 0) "all seven release metrics pass p95/p99/mean and variance limits"
    Assert-True (@($first.metrics | Where-Object { [string]$_.selectionPolicy -ne "all-samples-no-best-trial" }).Count -eq 0 -and [bool]$first.variance.allSamplesEvaluated) "gate evaluates every sample and refuses best-trial cherry picking"
    Assert-True (@($first.slices).Count -eq 9 -and @($first.slices | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0) "all S0-S8 related slices pass headlessly"
    Assert-True (@($first.nightly).Count -ge 2 -and @($first.nightly | Where-Object { [string]$_.status -ne "declared-live-required" }).Count -eq 0) "milestone/nightly pressure and soak runs remain declared for live execution"
    Assert-True ([string]$first.replayPolicy.adr -eq "docs/adr/performance-budget-v1.md" -and [string]$first.replayPolicy.before -ne "" -and [string]$first.replayPolicy.after -ne "") "ADR and before/after replay requirements are recorded"
    Assert-True ($null -ne $first.runtime.PSObject.Properties["teardownAvailable"] -and [string]$first.runtime.status -in @("deferred", "not-run")) "Teardown availability is disclosed without fabricating a live gate"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second performance gate completes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$first.determinismHash -eq [string]$second.determinismHash) "performance report is deterministic"
    Write-Host "Performance Regression Gate v1 regression passed (live S0-S8 evidence remains deferred)." -ForegroundColor Green
    exit 0
}
finally { if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue } }
