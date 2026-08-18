# Static security checker for the deferred Expert Custom Behavior API.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\expert-behavior-api-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\expert-behavior-api-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }

try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: $($_.Exception.Message)") }
try { $fixtures = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: $($_.Exception.Message)") }
if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.expert-behavior-policy/1") "policy schema mismatch"
    Require ([string]$policy.status -eq "deferred" -and -not [bool]$policy.enabled) "Expert API must remain deferred and disabled"
    Require (-not [bool]$policy.dataOnlyPrerequisite) "Expert API cannot be a Data-only SDK prerequisite"
    Require ([bool]$policy.capabilities.defaultDeny -and [bool]$policy.capabilities.reviewRequired) "capability boundary is not default-deny/reviewed"
    foreach ($denied in @("arbitrary-lua", "filesystem", "network", "engine-handle", "process-spawn", "native-code", "reflection")) { Require ([string]$denied -in @($policy.capabilities.denied)) ("missing denied capability: " + $denied) }
    Require ([string]$policy.sandbox.filesystemRoot -eq "none" -and [string]$policy.sandbox.network -eq "none" -and [bool]$policy.sandbox.noDynamicCode) "sandbox permits an unsafe surface"
    Require ([bool]$policy.lifecycle.ownerRequired -and [bool]$policy.lifecycle.generationRequired -and [bool]$policy.lifecycle.disposeOnPackageUnload) "lifecycle ownership/dispose policy is incomplete"
    Require ([string]$policy.network.rawRpc -eq "forbidden" -and [string]$policy.network.authority -eq "server-only-review") "network authority boundary is incomplete"
    Require ([double]$policy.budgets.maxTickMs -gt 0 -and [int]$policy.budgets.maxEventQueue -gt 0 -and [string]$policy.budgets.timeoutAction -ne "") "execution budgets are missing"
    foreach ($field in @("timeout", "crash", "memory", "permission", "leak", "runtimeFallback")) { Require ([string]$policy.failureIsolation.$field -ne "") ("failure isolation field missing: " + $field) }
    Require ([string]$policy.versioning.futureRequired -eq "fail-fast" -and [string]$policy.versioning.migration -eq "explicit-only") "version policy is not fail-fast/explicit"
    foreach ($id in @("T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10")) { Require ($null -ne @($policy.threatModel | Where-Object {[string]$_.id -eq $id})[0]) ("threat model missing: " + $id) }
    Require (@($policy.reviewGates).Count -ge 7) "security review gates are incomplete"
}
if ($null -ne $fixtures) {
    Require ([bool]$fixtures.mustRemainDisabled -and [bool]$fixtures.mustNotBeDataOnlyPrerequisite) "fixture must assert deferred/disabled boundary"
    Require (@($fixtures.requests).Count -ge 7) "expert behavior negative fixture coverage is incomplete"
}
if ($issues.Count -gt 0) { Write-Error ("Expert behavior policy check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Expert behavior policy v1 passed: deferred/default-deny boundary, threat model, budgets, lifecycle, network and failure isolation are declared." -ForegroundColor Green
exit 0
