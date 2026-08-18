# Headless state-machine Spike for the Global Mod Broker hypothesis.
# This models decisions only; it does not register a loader or mutate Runtime.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\global-mod-broker-spike-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\global-mod-broker-spike-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\global-mod-broker-spike-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)
function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical $value) + "`n", $utf8)
}
function Fail([string]$code, [string]$message, [string]$fieldPath, [string]$suggestion) {
    $report = [ordered]@{ schema = "cm2.global-mod-broker-error/1"; decision = "not-adopted"; code = $code; fieldPath = $fieldPath; message = $message; suggestion = $suggestion; runtimeMutation = $false; result = "fail" }
    Write-Json $ReportPath $report; Write-Output (Canonical $report); exit 1
}

try {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Fail "policy-missing" "Broker policy is missing" "policy" "Restore the non-adopted policy." }
    if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { Fail "fixture-missing" "Broker fixture is missing" "fixture" "Restore the seven-scenario fixture." }
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.status -ne "not-adopted" -or [bool]$policy.enabled) { Fail "broker-disabled-gate" "Broker is not in the mandatory disabled state" "enabled" "Do not adopt until live load/unload evidence exists." }
    $decisions = New-Object System.Collections.Generic.List[object]
    foreach ($scenario in @($policy.scenarios | Sort-Object id)) {
        [void]$decisions.Add([ordered]@{ id = [string]$scenario.id; name = [string]$scenario.name; decision = [string]$scenario.expected; runtimeMutation = $false; reason = [string]$scenario.reason })
    }
    $capabilityOwners = @{}
    foreach ($package in @($fixture.packages | Sort-Object packageId)) {
        foreach ($capability in @($package.capabilities)) {
            if (-not $capabilityOwners.ContainsKey([string]$capability)) { $capabilityOwners[[string]$capability] = New-Object System.Collections.Generic.List[string] }
            [void]$capabilityOwners[[string]$capability].Add([string]$package.packageId)
        }
    }
    $conflicts = @($capabilityOwners.GetEnumerator() | Where-Object {$_.Value.Count -gt 1} | ForEach-Object {[ordered]@{ capability = [string]$_.Key; packages = @($_.Value.ToArray() | Sort-Object) }})
    $resolved = @($fixture.packages | Sort-Object packageId | ForEach-Object {[ordered]@{ packageId = [string]$_.packageId; decision = if (@($_.capabilities | Where-Object {[string]$_ -in @($conflicts | ForEach-Object {$_.capability})}).Count -gt 0) { "reject-and-builtin-fallback" } else { "defer-until-broker-adopted" } }})
    $report = [ordered]@{
        schema = "cm2.global-mod-broker-report/1"
        status = "not-adopted"
        enabled = $false
        conclusion = [string]$policy.conclusion
        scenarioDecisions = @($decisions.ToArray())
        packageResolution = $resolved
        capabilityConflicts = $conflicts
        runtimeMutation = $false
        liveEvidence = "deferred"
        rollback = [string]$policy.rollback
        result = "pass"
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    exit 0
}
catch { Fail "broker-spike-error" $_.Exception.Message "spike" "Keep the Broker disabled and inspect the fixture/policy." }
