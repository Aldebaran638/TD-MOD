# Regression test for the cross-layer Golden Package collection.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
$checker = Join-Path $PSScriptRoot "check-golden-packages-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-golden-packages-v1.ps1"
$policy = Join-Path $root "docs\golden-packages-v1.json"
$fixture = Join-Path $root "docs\candidates\golden-packages-v1.fixture.json"
$report = Join-Path $root "docs\candidates\golden-packages-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-golden-packages-" + [Guid]::NewGuid().ToString("N") + ".json")

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Golden Package v1 failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Script([string]$path, [string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @arguments *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}

try {
    Assert-True ((Invoke-Script $checker @("-PolicyPath", $policy, "-FixturePath", $fixture)) -eq 0) "static policy and fixture checker passes"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "Golden runner completes"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.golden-packages-report/1" -and [string]$first.status -eq "headless-candidate") "report schema and candidate status are explicit"
    Assert-True ([string]$first.result -eq "unable" -and [bool]$first.headlessPass) "headless Golden gate passes while runtime remains honestly unable"
    Assert-True (@($first.packages).Count -eq 8 -and @($first.packages | Where-Object { [string]$_.suiteResult.status -ne "pass" }).Count -eq 0) "all eight package suites pass headlessly"
    Assert-True (@($first.packages | Where-Object { [string]$_.stages.build -ne "headless-pass" -or [string]$_.stages.migrate -ne "headless-pass" -or [string]$_.stages.preview -ne "headless-pass" -or [string]$_.stages.package -ne "headless-pass" }).Count -eq 0) "build/migrate/preview/package stages pass for every package"
    Assert-True (@($first.packages | Where-Object { [string]$_.stages.runtime -notin @("deferred", "not-run") }).Count -eq 0 -and [string]$first.runtime.status -in @("deferred", "not-run")) "runtime stage is deferred/not-run rather than fabricated"
    Assert-True (@($first.negativeCases).Count -eq 6 -and @($first.negativeCases | Where-Object { -not [bool]$_.stable -or [string]$_.status -ne "declared-and-covered-by-regression-fixtures" }).Count -eq 0) "six negative contracts remain stable and covered"
    Assert-True ([int]$first.repositoryIntegrity.coreDiff -eq 0 -and [bool]$first.repositoryIntegrity.sourceOfTruthPreserved) "Golden audit leaves Content and Global scopes unchanged"
    Assert-True ($null -ne $first.runtime.PSObject.Properties["teardownAvailable"] -and [string]$first.runtime.status -in @("deferred", "not-run")) "Teardown availability and live status are disclosed separately"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second Golden audit completes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$first.determinismHash -eq [string]$second.determinismHash) "Golden report is deterministic"
    Write-Host "Golden Package v1 regression passed (runtime remains not-run/deferred until live Teardown evidence exists)." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue }
}
