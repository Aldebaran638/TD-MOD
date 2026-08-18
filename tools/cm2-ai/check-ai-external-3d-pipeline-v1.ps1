# Static contract checker for the provider-neutral external 3D pipeline.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-external-3d-pipeline-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-external-3d-pipeline-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }

try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: " + $_.Exception.Message) }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: " + $_.Exception.Message) }

if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.ai-external-3d-policy/1" -and [string]$policy.status -eq "candidate-only") "external 3D policy schema/status mismatch"
    Require ([string]$policy.providers.adapterContract -eq "cm2.provider-adapter/1" -and [bool]$policy.providers.replaceable -and -not [bool]$policy.providers.networkRequired) "provider adapter must be replaceable and offline-capable"
    Require ([string]$policy.permissions.default -eq "deny" -and [bool]$policy.permissions.humanApprovalRequired) "external pipeline must be default-deny and human-approved"
    foreach ($denied in @("network", "runtime-registration", "core-write", "generated-artifact-write", "lua-write", "provider-arbitrary-exec", "license-bypass", "auto-publish")) {
        Require ([string]$denied -in @($policy.permissions.deny)) ("missing external pipeline denied permission: " + $denied)
    }
    foreach ($stage in @("input", "mesh-cleanup", "mesh-repair", "scale-axis", "voxelization", "palette-material", "voxtool-optimization", "asset-manifest")) {
        Require ($null -ne @($policy.stages | Where-Object { [string]$_.id -eq $stage })[0]) ("missing deterministic stage: " + $stage)
    }
    foreach ($field in @("inputHash", "promptHash", "provider", "modelVersion", "license", "meshHash", "voxelizationParamsHash", "stageHashes", "reviewStatus", "finalBuildHash")) {
        Require ([string]$field -in @($policy.provenanceRequired)) ("missing external pipeline provenance field: " + $field)
    }
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.ai-external-3d-fixtures/1" -and [int]$fixture.fixedSeed -eq 424242) "external 3D fixture schema/seed mismatch"
    Require (@($fixture.cases).Count -eq 8) "external 3D fixture must cover eight provider/quality cases"
    Require (@($fixture.cases | Where-Object { [string]$_.expected -eq "accept" }).Count -ge 3) "fixture needs image/text/local accepted cases"
    Require (@($fixture.cases | Where-Object { [string]$_.expected -eq "reject" }).Count -ge 4) "fixture needs quality/security rejection cases"
    foreach ($fixtureCase in @($fixture.cases)) {
        Require ([string]$fixtureCase.id -ne "" -and [string]$fixtureCase.prompt -ne "") "external case needs id/prompt"
        Require ($null -ne $fixtureCase.input -and $null -ne $fixtureCase.provider -and $null -ne $fixtureCase.mesh) ("external case is incomplete: " + [string]$fixtureCase.id)
    }
}
if ($issues.Count -gt 0) {
    Write-Error ("External 3D pipeline checker failed:" + [Environment]::NewLine + " - " + ($issues -join [Environment]::NewLine + " - "))
    exit 1
}
Write-Host "External 3D pipeline v1 contract passed: replaceable offline adapter, deterministic mesh stages, provenance/license and rejection boundaries are declared." -ForegroundColor Green
exit 0
