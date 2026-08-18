# Static contract checker for the AI Effect Assistant.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-effect-assistant-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-effect-assistant-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }

try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: " + $_.Exception.Message) }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: " + $_.Exception.Message) }

if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.ai-effect-policy/1" -and [string]$policy.status -eq "candidate-only") "AI Effect policy schema/status mismatch"
    Require ([string]$policy.permissions.default -eq "deny" -and [bool]$policy.permissions.humanApprovalRequired) "AI Effect Assistant must be default-deny and human-approved"
    foreach ($denied in @("generated-artifact-write", "core-write", "lua-write", "filesystem", "network", "runtime-registration", "custom-renderer", "budget-relax")) {
        Require ([string]$denied -in @($policy.permissions.deny)) ("missing denied permission: " + $denied)
    }
    foreach ($node in @("emitter", "beam", "shockwave", "sound", "shake")) { Require ([string]$node -in @($policy.allowLists.nodes)) ("missing Effect node allow-list entry: " + $node) }
    foreach ($field in @("promptHash", "candidateHash", "modelVersion", "toolVersion", "parserVersion", "validatorVersion", "humanDiff", "finalBuildHash")) {
        Require ([string]$field -in @($policy.provenanceRequired)) ("missing Effect Assistant provenance field: " + $field)
    }
    Require ([double]$policy.ranges.maxEmitters -eq 8 -and [double]$policy.ranges.maxPowerCost -eq 12) "Effect hard-cap contract is incomplete"
    Require (@($policy.pipeline).Count -eq 8 -and [string]$policy.pipeline[1] -eq "EffectIntent" -and [string]$policy.pipeline[4] -eq "effect-lab") "Effect Assistant pipeline is incomplete"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.ai-effect-fixtures/1" -and [int]$fixture.fixedSeed -eq 424242) "Effect Assistant fixture schema/seed mismatch"
    Require (@($fixture.cases).Count -eq 6) "Effect Assistant fixture must contain six prompt cases"
    foreach ($expected in @("accept", "repair", "reject")) { Require (@($fixture.cases | Where-Object { [string]$_.expected -eq $expected }).Count -ge 1) ("fixture has no " + $expected + " case") }
    foreach ($fixtureCase in @($fixture.cases)) {
        Require ([string]$fixtureCase.prompt -ne "" -and [string]$fixtureCase.id -ne "") "each Effect case needs prompt and id"
        Require ($null -ne $fixtureCase.intent -and [string]$fixtureCase.intent.requestedOperation -ne "" -and [string]$fixtureCase.intent.requestedTarget -ne "") ("Effect intent boundary is incomplete: " + [string]$fixtureCase.id)
    }
}
if ($issues.Count -gt 0) {
    Write-Error ("AI Effect Assistant checker failed:" + [Environment]::NewLine + " - " + ($issues -join [Environment]::NewLine + " - "))
    exit 1
}
Write-Host "AI Effect Assistant v1 contract passed: intent, approved nodes, budget profiles, Effect Lab, human diff and Compiler boundary are declared." -ForegroundColor Green
exit 0
