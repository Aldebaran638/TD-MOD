# Static quality-gate checker for AI Creator Beta.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-creator-beta-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-creator-beta-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }

try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: " + $_.Exception.Message) }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: " + $_.Exception.Message) }

if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.ai-creator-beta-policy/1" -and [string]$policy.status -eq "headless-beta") "AI Creator Beta policy schema/status mismatch"
    Require ([int]$policy.requiredEvidence.nonCoreWeaponEffectAuthors -eq 5 -and [int]$policy.requiredEvidence.nonCoreVoxAuthors -eq 3) "external cohort thresholds are incomplete"
    Require ([double]$policy.requiredEvidence.compilerPassRate -eq 1 -and [double]$policy.requiredEvidence.previewPassRate -eq 1 -and [double]$policy.requiredEvidence.packageConformanceRate -eq 1) "quality pass-rate thresholds are incomplete"
    Require ([int]$policy.requiredEvidence.aiLuaWrites -eq 0 -and [int]$policy.requiredEvidence.pathEscapes -eq 0 -and [int]$policy.requiredEvidence.budgetBypasses -eq 0) "security zero-tolerance thresholds are incomplete"
    Require ([bool]$policy.gateRules.headlessSimulationDoesNotCountAsExternalAuthors -and [bool]$policy.gateRules.missingTeardownBlocksOfficialBeta -and [bool]$policy.gateRules.unableMayContinueAsInternalFramework) "Beta gate rules are incomplete"
    foreach ($suite in @("ai-weapon-assistant", "ai-effect-assistant", "ai-vox-import", "sdk-beta")) { Require ([string]$suite -in @($policy.requiredSuites)) ("missing required Beta suite: " + $suite) }
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.ai-creator-beta-fixtures/1") "AI Creator Beta fixture schema mismatch"
    Require (@($fixture.headlessCohort).Count -eq 8 -and @($fixture.qualitySamples).Count -ge 3) "headless cohort/quality fixture is incomplete"
    Require ([int]$fixture.externalEvidence.nonCoreWeaponEffectAuthorsVerified -eq 0 -and [int]$fixture.externalEvidence.nonCoreVoxAuthorsVerified -eq 0) "fixture must disclose absent external authors"
    Require ([int]$fixture.negativeSecurity.aiLuaWrites -eq 0 -and [int]$fixture.negativeSecurity.pathEscapes -eq 0 -and [int]$fixture.negativeSecurity.budgetBypasses -eq 0) "security fixture must declare zero bypasses"
}
if ($issues.Count -gt 0) {
    Write-Error ("AI Creator Beta checker failed:" + [Environment]::NewLine + " - " + ($issues -join [Environment]::NewLine + " - "))
    exit 1
}
Write-Host "AI Creator Beta v1 contract passed: external cohort thresholds, quality metrics, conformance suites and no-bypass gate are declared." -ForegroundColor Green
exit 0
