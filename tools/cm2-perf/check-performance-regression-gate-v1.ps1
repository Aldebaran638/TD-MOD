# Static checker for the versioned performance regression gate.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\performance-regression-gate-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\performance-regression-gate-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }
try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: " + $_.Exception.Message) }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: " + $_.Exception.Message) }
if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.performance-regression-policy/1" -and [string]$policy.status -eq "headless-candidate") "policy schema/status mismatch"
    Require ([double]$policy.thresholds.p95MaxRegression -eq 0.05 -and [double]$policy.thresholds.p99MaxRegression -eq 0.10) "p95/p99 default thresholds must be 5%/10%"
    Require ([double]$policy.thresholds.maxRelativeStdDev -gt 0 -and [string]$policy.thresholds.variancePolicy -eq "stop-and-repair-scenario") "variance policy is incomplete"
    Require (@($policy.requiredSlices).Count -eq 9 -and @($policy.requiredMetrics).Count -eq 7) "S0-S8 or published metric coverage is incomplete"
    Require ([bool]$policy.replayPolicy.required -and [string]$policy.replayPolicy.adr -ne "") "ADR and before/after replay policy is required"
    Require ([bool]$policy.runtimePolicy.teardownRequired -and [string]$policy.runtimePolicy.statusWhenUnavailable -eq "deferred") "runtime policy must disclose unavailable Teardown"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.performance-regression-fixtures/1") "fixture schema mismatch"
    Require (@($fixture.metrics).Count -eq 7) "fixture must contain seven release metrics"
    foreach ($metric in @($fixture.metrics)) {
        Require ([string]$metric.id -ne "" -and @($metric.baseline).Count -ge 20 -and @($metric.candidate).Count -ge 20) ("metric samples incomplete: " + [string]$metric.id)
        Require ([double]$metric.maxRegression -le 0.05 -and [double]$metric.p95MaxRegression -eq 0.05 -and [double]$metric.p99MaxRegression -eq 0.10) ("metric threshold mismatch: " + [string]$metric.id)
    }
    Require (@($fixture.slices).Count -eq 9) "fixture must contain all S0-S8 slices"
    foreach ($slice in @($fixture.slices)) { Require ([string]$slice.id -in @("S0", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8") -and [string]$slice.suite -ne "") ("invalid performance slice: " + [string]$slice.id) }
    Require (@($fixture.nightly).Count -ge 2) "nightly pressure/soak declarations are incomplete"
}
if ($issues.Count -gt 0) {
    Write-Error ("Performance regression gate checker failed:" + [Environment]::NewLine + " - " + ($issues -join [Environment]::NewLine + " - "))
    exit 1
}
Write-Host "Performance Regression Gate v1 contract passed: S0-S8, p95/p99 thresholds, variance stop rule, release metrics, ADR and replay policy are declared." -ForegroundColor Green
exit 0
