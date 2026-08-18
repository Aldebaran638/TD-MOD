# Static contract checker for the AI Weapon Assistant candidate-only boundary.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-weapon-assistant-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) {
    if (-not $condition) { [void]$issues.Add($message) }
}

try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: " + $_.Exception.Message) }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: " + $_.Exception.Message) }

if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.ai-weapon-policy/1" -and [string]$policy.status -eq "candidate-only") "AI Weapon policy schema/status mismatch"
    Require ([string]$policy.permissions.default -eq "deny" -and [bool]$policy.permissions.humanApprovalRequired) "AI Weapon Assistant must be default-deny and human-approved"
    foreach ($denied in @("generated-artifact-write", "core-write", "lua-write", "filesystem", "network", "runtime-registration", "schema-relax", "budget-relax")) {
        Require ([string]$denied -in @($policy.permissions.deny)) ("missing denied permission: " + $denied)
    }
    foreach ($allowed in @("ray", "ballistic", "guided", "charged")) { Require ([string]$allowed -in @($policy.allowLists.behaviors)) ("missing behavior allow-list entry: " + $allowed) }
    foreach ($field in @("promptHash", "candidateHash", "modelVersion", "toolVersion", "parserVersion", "validatorVersion", "humanDiff", "finalBuildHash")) {
        Require ([string]$field -in @($policy.provenanceRequired)) ("missing Weapon Assistant provenance field: " + $field)
    }
    Require ([double]$policy.budgets.maxFireRateHz -eq 20 -and [double]$policy.budgets.maxDps -eq 1000) "deterministic Weapon Assistant budget contract is incomplete"
    Require (@($policy.pipeline).Count -eq 8 -and [string]$policy.pipeline[1] -eq "WeaponIntent" -and [string]$policy.pipeline[6] -eq "compiler") "Weapon Assistant pipeline is incomplete"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.ai-weapon-fixtures/1" -and [int]$fixture.fixedSeed -eq 424242) "Weapon Assistant fixture schema/seed mismatch"
    Require (@($fixture.cases).Count -eq 6) "Weapon Assistant fixture must contain six prompt cases"
    foreach ($expected in @("accept", "repair", "reject")) { Require (@($fixture.cases | Where-Object { [string]$_.expected -eq $expected }).Count -ge 1) ("fixture has no " + $expected + " case") }
    foreach ($fixtureCase in @($fixture.cases)) {
        Require ([string]$fixtureCase.prompt -ne "" -and [string]$fixtureCase.id -ne "") "each Weapon Assistant case needs prompt and id"
        Require ($null -ne $fixtureCase.intent -and [string]$fixtureCase.intent.requestedOperation -ne "" -and [string]$fixtureCase.intent.requestedTarget -ne "") ("intent boundary is incomplete: " + [string]$fixtureCase.id)
    }
}
if ($issues.Count -gt 0) {
    Write-Error ("AI Weapon Assistant checker failed:" + [Environment]::NewLine + " - " + ($issues -join [Environment]::NewLine + " - "))
    exit 1
}
Write-Host "AI Weapon Assistant v1 contract passed: prompt -> intent -> constrained candidate -> lint -> human diff -> compiler boundary is declared." -ForegroundColor Green
exit 0
