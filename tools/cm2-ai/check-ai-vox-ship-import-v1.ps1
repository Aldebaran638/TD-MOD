# Static contract checker for the existing-VOX Ship Import Assistant.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-vox-ship-import-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-vox-ship-import-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }

try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: " + $_.Exception.Message) }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: " + $_.Exception.Message) }

if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.ai-vox-import-policy/1" -and [string]$policy.status -eq "candidate-only") "VOX import policy schema/status mismatch"
    Require ([int]$policy.voxVersion -eq 150) "VOX import policy must require v150"
    Require ([string]$policy.coordinateContract.mapping -match "voxX=logicalX" -and [string]$policy.coordinateContract.sizeMapping -match "logicalSizeY") "Teardown VOX coordinate mapping is incomplete"
    Require ([string]$policy.coordinateContract.forwardSelection -eq "human-required" -and [string]$policy.confidencePolicy.orientationSelection -eq "never-auto-select") "forward orientation must remain human-selected"
    Require ([string]$policy.permissions.default -eq "deny" -and [bool]$policy.permissions.humanApprovalRequired) "VOX import must be default-deny and human-approved"
    foreach ($denied in @("runtime-registration", "core-write", "generated-artifact-write", "lua-write", "network", "voxel-rewrite", "auto-build")) {
        Require ([string]$denied -in @($policy.permissions.deny)) ("missing VOX denied permission: " + $denied)
    }
    foreach ($field in @("assetHash", "modelIndex", "voxVersion", "parserVersion", "scaleCandidates", "confidence", "reviewStatus", "finalBuildHash")) {
        Require ([string]$field -in @($policy.provenanceRequired)) ("missing VOX provenance field: " + $field)
    }
    Require (@($policy.scaleCandidatesMetersPerVoxel).Count -eq 3 -and [bool]$policy.confidencePolicy.lowConfidenceBlocksBuild) "scale/confidence policy is incomplete"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.ai-vox-import-fixtures/1") "VOX import fixture schema mismatch"
    Require (@($fixture.requiredModels).Count -eq 3) "VOX import fixture must cover three reference assets"
    Require ([int]$fixture.expected.minModelRecords -ge 4 -and [int]$fixture.expected.minDistinctAxisSignatures -ge 3) "VOX diversity expectations are incomplete"
    foreach ($model in @($fixture.requiredModels)) {
        Require ([string]$model.id -ne "" -and [string]$model.path -match '\.vox$') ("VOX fixture entry is incomplete: " + [string]$model.id)
    }
}
if ($issues.Count -gt 0) {
    Write-Error ("VOX Ship Import checker failed:" + [Environment]::NewLine + " - " + ($issues -join [Environment]::NewLine + " - "))
    exit 1
}
Write-Host "VOX Ship Import v1 contract passed: v150 validation, axis/scale recommendations, confidence review and candidate-only boundaries are declared." -ForegroundColor Green
exit 0
