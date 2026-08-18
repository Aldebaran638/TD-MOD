# Static checker for the AI evaluation/provenance contract.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-evaluation-provenance-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-evaluation-provenance-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }
try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: $($_.Exception.Message)") }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: $($_.Exception.Message)") }
if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.ai-evaluation-policy/1" -and [string]$policy.status -eq "evaluation-only") "AI evaluation policy schema/status mismatch"
    Require ([int]$policy.seed -eq 424242 -and [string]$policy.modelVersion -ne "" -and [string]$policy.toolVersion -ne "") "model/tool/seed provenance is incomplete"
    Require ([string]$policy.permissions.default -eq "deny" -and [bool]$policy.permissions.humanApprovalRequired) "AI permission boundary must be default-deny/human-approved"
    foreach ($denied in @("generated-artifact-write", "core-write", "lua-write", "schema-relax", "budget-relax", "filesystem", "network", "runtime-registration")) { Require ([string]$denied -in @($policy.permissions.deny)) ("missing AI denied permission: " + $denied) }
    foreach ($field in @("modelVersion", "toolVersion", "seed", "inputHash", "promptHash", "candidateHash", "validatorVersion", "repair", "confidence", "humanEdits", "finalBuildHash")) { Require ([string]$field -in @($policy.provenanceRequired)) ("missing provenance field: " + $field) }
    Require ([string]$policy.candidateContract.schemaAndBudgetPolicy -eq "cannot-relax") "AI cannot relax schema/budget policy"
    Require (@($policy.evaluationSet.requiredCategories).Count -eq 10 -and [double]$policy.evaluationSet.legalRateTarget -eq 1 -and [double]$policy.evaluationSet.determinismTarget -eq 1) "evaluation category/targets incomplete"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.ai-evaluation-fixtures/1") "AI fixture schema mismatch"
    Require (@($fixture.cases).Count -eq 10) "AI evaluation fixture must contain ten categories"
    foreach ($category in @("normal", "ambiguous", "conflict", "budget-overflow", "missing-resource", "malicious-path", "lua-request", "manual-edit", "generated-write", "missing-provenance")) { Require ($null -ne @($fixture.cases | Where-Object {[string]$_.category -eq $category})[0]) ("missing AI category: " + $category) }
    Require ([string]$fixture.inputHash -ne "" -and [string]$fixture.promptHash -ne "" -and [string]$fixture.validatorVersion -ne "") "fixture input/prompt/validator provenance is incomplete"
}
if ($issues.Count -gt 0) { Write-Error ("AI evaluation checker failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "AI evaluation/provenance v1 passed: ten-category regression set, default-deny permissions and complete artifact provenance are declared." -ForegroundColor Green
exit 0
