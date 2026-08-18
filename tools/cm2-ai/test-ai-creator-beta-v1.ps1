# Regression test for the AI Creator Beta quality gate.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-ai-creator-beta-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-ai-creator-beta-v1.ps1"
$policy = Join-Path $root "docs\ai-creator-beta-v1.json"
$fixture = Join-Path $root "docs\candidates\ai-creator-beta-v1.fixture.json"
$report = Join-Path $root "docs\candidates\ai-creator-beta-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-creator-beta-" + [Guid]::NewGuid().ToString("N") + ".json")

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("AI Creator Beta v1 failed: " + $message) }
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
    Assert-True ((Invoke-Script $checker @("-PolicyPath", $policy, "-FixturePath", $fixture)) -eq 0) "static Beta policy/fixture checker passes"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "Beta quality runner completes its audit"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.ai-creator-beta-report/1" -and [string]$first.status -eq "headless-beta") "report declares headless Beta status"
    Assert-True ([string]$first.result -eq "unable" -and [string]$first.gateDecision -eq "unable") "official Beta is honestly blocked by missing external/runtime evidence"
    Assert-True (@($first.suites).Count -eq 4 -and @($first.suites | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0) "Weapon/Effect/VOX/SDK suites all pass headlessly"
    Assert-True ([bool]$first.thresholds.headlessQualityPass -and [bool]$first.thresholds.compilerPassRate -and [bool]$first.thresholds.previewPassRate -and [bool]$first.thresholds.packageConformanceRate) "headless quality and conformance thresholds pass"
    Assert-True (-not [bool]$first.thresholds.externalCohortReady -and [string]$first.runtime.status -in @("deferred", "not-run")) "external authors and Teardown runtime are not fabricated"
    Assert-True ([bool]$first.quality.thresholds.firstLegalRate -and [bool]$first.quality.thresholds.finalLegalRate -and [bool]$first.quality.thresholds.averageManualFields -and [bool]$first.quality.thresholds.anchorRework -and [bool]$first.quality.thresholds.luaViews) "quality metric thresholds are evaluated"
    Assert-True ([int]$first.security.aiLuaWrites -eq 0 -and [int]$first.security.pathEscapes -eq 0 -and [int]$first.security.budgetBypasses -eq 0 -and [int]$first.security.providerNetworkCalls -eq 0) "AI Lua/path/budget/network security counters remain zero"
    Assert-True ([int]$first.externalEvidence.nonCoreWeaponEffectAuthorsVerified -eq 0 -and [int]$first.externalEvidence.nonCoreVoxAuthorsVerified -eq 0 -and @($first.headlessCohort).Count -eq 8) "simulated cohort is separated from the required external cohort"
    Assert-True ([string]$first.quality.s1s5 -eq "deferred-runtime" -and [string]$first.runtime.s1s5 -eq "deferred-until-runtime") "S1/S5 performance evidence remains explicitly deferred"
    Assert-True ([int]$first.repositoryIntegrity.coreDiff -eq 0 -and [bool]$first.repositoryIntegrity.sourceOfTruthPreserved) "Beta audit leaves repository source of truth unchanged"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second Beta quality audit completes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$first.determinismHash -eq [string]$second.determinismHash) "Beta quality report is deterministic"
    Write-Host "AI Creator Beta v1 quality-gate regression passed (official gate remains unable pending external/runtime evidence)." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue }
}
