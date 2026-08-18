# Design-only Expert Behavior request gate. It never executes user code.

param(
    [Parameter(Mandatory = $true)][string]$RequestPath,
    [string]$PolicyPath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\expert-behavior-api-v1.json" }
if ($ReportPath -eq "") { $ReportPath = [IO.Path]::ChangeExtension($RequestPath, ".decision.json") }
$utf8 = New-Object Text.UTF8Encoding($false)
function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical $value) + "`n", $utf8)
}
function Fail([string]$code, [string]$message, [string]$fieldPath, [string]$suggestion) {
    $report = [ordered]@{ schema = "cm2.expert-behavior-decision/1"; decision = "deny"; code = $code; fieldPath = $fieldPath; message = $message; suggestion = $suggestion; execution = "not-run"; result = "fail" }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    exit 1
}

try {
    if (-not (Test-Path -LiteralPath $RequestPath -PathType Leaf)) { Fail "request-missing" "Behavior request does not exist" "request" "Provide a request fixture." }
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Fail "policy-missing" "Expert policy does not exist" "policy" "Restore the reviewed policy." }
    $request = Get-Content -Raw -LiteralPath $RequestPath | ConvertFrom-Json
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    if ([string]$policy.status -ne "deferred" -or [bool]$policy.enabled) { Fail "policy-not-deferred" "Expert behavior policy is not in its mandatory deferred state" "policy.enabled" "Keep the API disabled until security review passes." }
    $capabilities = @($request.capabilities | ForEach-Object {[string]$_})
    $denied = @($capabilities | Where-Object { [string]$_ -in @($policy.capabilities.denied) })
    if ($denied.Count -gt 0) { $report = [ordered]@{ schema = "cm2.expert-behavior-decision/1"; decision = "deny"; code = "capability-not-allowlisted"; deniedCapabilities = $denied; fieldPath = "capabilities"; suggestion = "Use the data-only SDK or wait for an explicitly reviewed allow-list."; execution = "not-run"; result = "pass" } }
    elseif ($null -ne $request.timeoutMs -and [double]$request.timeoutMs -gt [double]$policy.budgets.maxTickMs) { $report = [ordered]@{ schema = "cm2.expert-behavior-decision/1"; decision = "isolate"; code = "timeout-isolated"; fieldPath = "timeoutMs"; suggestion = "Terminate and isolate the behavior instance; do not run it in Runtime."; execution = "not-run"; result = "pass" } }
    elseif ([bool]$request.simulateCrash) { $report = [ordered]@{ schema = "cm2.expert-behavior-decision/1"; decision = "isolate"; code = "crash-isolated"; fieldPath = "simulateCrash"; suggestion = "Disable the package instance and fall back to builtin behavior."; execution = "not-run"; result = "pass" } }
    else { $report = [ordered]@{ schema = "cm2.expert-behavior-decision/1"; decision = "deferred"; code = "expert-api-disabled"; fieldPath = "policy.enabled"; suggestion = "Use the Data-only SDK; Expert Custom Behavior is deferred pending security review."; execution = "not-run"; result = "pass" } }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    exit 0
}
catch {
    Fail "expert-gate-error" $_.Exception.Message "request" "Fix the request/policy JSON and rerun the design-only gate."
}
