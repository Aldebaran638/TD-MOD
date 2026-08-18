# Static checker for the non-adopted Global Mod Broker Spike.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\global-mod-broker-spike-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\global-mod-broker-spike-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }
try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: $($_.Exception.Message)") }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: $($_.Exception.Message)") }
if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.global-mod-broker-spike/1") "policy schema mismatch"
    Require ([string]$policy.status -eq "not-adopted" -and -not [bool]$policy.enabled) "Broker must remain disabled/not-adopted"
    Require ([string]$policy.resolution.conflictPolicy -eq "reject-and-builtin-fallback") "conflict policy must reject/fallback"
    Require ([string]$policy.resolution.unknownPackagePolicy -eq "builtin-only" -and -not [bool]$policy.resolution.runtimeMutation) "unknown package/runtime mutation policy is unsafe"
    Require (@($policy.scenarios).Count -eq 7) "all seven Broker scenarios are required"
    foreach ($id in @("S1", "S2", "S3", "S4", "S5", "S6", "S7")) { Require ($null -ne @($policy.scenarios | Where-Object {[string]$_.id -eq $id})[0]) ("missing scenario: " + $id) }
    Require (@($policy.requiredEvidenceBeforeAdoption).Count -ge 6) "adoption evidence gate is incomplete"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.global-mod-broker-fixtures/1") "fixture schema mismatch"
    Require (@($fixture.packages).Count -ge 3) "fixture must cover multiple packages"
    Require (@($fixture.scenarios).Count -eq 7) "fixture must cover seven scenarios"
    Require ([string]$fixture.expectedDefault -eq "builtin-only") "fixture default must be builtin-only"
}
if ($issues.Count -gt 0) { Write-Error ("Global Mod Broker spike check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Global Mod Broker spike v1 passed: seven scenarios, deterministic reject/fallback policy and non-adoption gate are declared." -ForegroundColor Green
exit 0
