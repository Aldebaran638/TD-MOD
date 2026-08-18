# Self-test for the non-adopted Global Mod Broker state-machine Spike.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-global-mod-broker-spike-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-global-mod-broker-spike-v1.ps1"
$policy = Join-Path $root "docs\global-mod-broker-spike-v1.json"
$fixture = Join-Path $root "docs\candidates\global-mod-broker-spike-v1.fixture.json"
$result = Join-Path $root "docs\candidates\global-mod-broker-spike-v1.result.json"

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Global Mod Broker self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Tool([string]$scriptPath, [string[]]$arguments) {
    $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments *> $null
    $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved; return $code
}
function Write-Json([string]$path, [object]$value) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 100) + "`n", (New-Object Text.UTF8Encoding($false))) }

Assert-True ((Invoke-Tool $checker @()) -eq 0) "checker accepts the non-adopted seven-scenario policy"
Assert-True ((Invoke-Tool $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $result)) -eq 0) "state-machine Spike runs without Runtime registration"
$report = Get-Content -Raw -LiteralPath $result | ConvertFrom-Json
Assert-True ([string]$report.status -eq "not-adopted" -and -not [bool]$report.enabled -and -not [bool]$report.runtimeMutation) "report keeps Broker disabled and side-effect free"
Assert-True (@($report.scenarioDecisions).Count -eq 7) "report covers load order, Core, unload, multiplayer and conflict scenarios"
Assert-True ([string](@($report.scenarioDecisions | Where-Object {$_.id -eq "S3"})[0].decision) -eq "builtin-only" -and [string](@($report.scenarioDecisions | Where-Object {$_.id -eq "S4"})[0].decision) -eq "builtin-only") "missing/mismatched Core uses builtin fallback"
Assert-True ([string](@($report.scenarioDecisions | Where-Object {$_.id -eq "S5"})[0].decision) -eq "blocked-runtime" -and [string](@($report.scenarioDecisions | Where-Object {$_.id -eq "S6"})[0].decision) -eq "blocked-runtime") "unload/multiplayer remain blocked until live evidence"
Assert-True (@($report.capabilityConflicts).Count -eq 1 -and [string](@($report.capabilityConflicts)[0].capability) -eq "Ship") "multiple-package capability conflict is deterministic"

$badPolicy = Get-Content -Raw -LiteralPath $policy | ConvertFrom-Json
$badPolicy.enabled = $true
$tempPolicy = Join-Path ([IO.Path]::GetTempPath()) ("cm2-broker-bad-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
    Write-Json $tempPolicy $badPolicy
    Assert-True ((Invoke-Tool $runner @("-PolicyPath", $tempPolicy, "-FixturePath", $fixture, "-ReportPath", (Join-Path ([IO.Path]::GetTempPath()) "cm2-broker-bad.report.json"))) -ne 0) "enabled Broker policy is rejected before adoption"
}
finally { if (Test-Path -LiteralPath $tempPolicy) { Remove-Item -LiteralPath $tempPolicy -Force -ErrorAction SilentlyContinue } }

Write-Host "Global Mod Broker Spike self-test passed." -ForegroundColor Green
exit 0
