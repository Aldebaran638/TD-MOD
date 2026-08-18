# Static checker for the cross-layer Golden Package set.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\golden-packages-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\golden-packages-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }
try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: " + $_.Exception.Message) }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: " + $_.Exception.Message) }
if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.golden-packages-policy/1" -and [string]$policy.status -eq "headless-candidate") "Golden policy schema/status mismatch"
    foreach ($kind in @("builtin-content", "hello-ship", "previous-schema", "dependency-dag", "expert-behavior", "ai-approved-weapon", "ai-approved-effect", "ai-approved-ship")) { Require ([string]$kind -in @($policy.requiredKinds)) ("missing Golden kind: " + $kind) }
    foreach ($negative in @("missing-dependency", "dependency-cycle", "duplicate-id", "path-traversal", "asset-hash-mismatch", "budget-overflow")) { Require ([string]$negative -in @($policy.negativeCases)) ("missing Golden negative case: " + $negative) }
    foreach ($stage in @("build", "migrate", "preview", "package", "runtime")) { Require ([string]$stage -in @($policy.requiredStages)) ("missing Golden stage: " + $stage) }
    Require ([bool]$policy.runtimePolicy.teardownRequired -and [string]$policy.runtimePolicy.statusWhenUnavailable -eq "deferred") "Golden runtime policy must disclose unavailable Teardown"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.golden-packages-fixtures/1" -and @($fixture.packages).Count -eq 8) "Golden fixture must contain eight package kinds"
    Require (@($fixture.negativeCases).Count -eq 6) "Golden fixture must contain six negative cases"
    foreach ($package in @($fixture.packages)) { Require ([string]$package.id -ne "" -and [string]$package.suite -ne "") ("Golden package entry incomplete: " + [string]$package.id) }
    foreach ($negativeCase in @($fixture.negativeCases)) { Require ([string]$negativeCase.id -ne "" -and [string]$negativeCase.expectedCode -ne "") ("Golden negative entry incomplete") }
}
if ($issues.Count -gt 0) {
    Write-Error ("Golden package checker failed:" + [Environment]::NewLine + " - " + ($issues -join [Environment]::NewLine + " - "))
    exit 1
}
Write-Host "Golden Package v1 contract passed: eight cross-layer kinds, six stable negative cases and build/migrate/preview/package/runtime stages are declared." -ForegroundColor Green
exit 0
