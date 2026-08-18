# Regression test for the provider-neutral external 3D pipeline.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-ai-external-3d-pipeline-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-ai-external-3d-pipeline-v1.ps1"
$policy = Join-Path $root "docs\ai-external-3d-pipeline-v1.json"
$fixture = Join-Path $root "docs\candidates\ai-external-3d-pipeline-v1.fixture.json"
$report = Join-Path $root "docs\candidates\ai-external-3d-pipeline-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-external-3d-" + [Guid]::NewGuid().ToString("N") + ".json")

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("External 3D pipeline v1 failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Script([string]$path, [string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @arguments *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}

try {
    Assert-True ((Invoke-Script $checker @("-PolicyPath", $policy, "-FixturePath", $fixture)) -eq 0) "static policy/fixture checker passes"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "external 3D runner passes"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.ai-external-3d-report/1" -and [string]$first.status -eq "candidate-only") "report declares candidate-only status"
    Assert-True ([int]$first.caseCount -eq 8 -and [int]$first.metrics.accepted -eq 3 -and [int]$first.metrics.rejected -eq 5) "image/text/local accepted cases and quality/security rejects are covered"
    Assert-True ([double]$first.metrics.legalRate -eq 1.0 -and [bool]$first.metrics.deterministicStages) "fixed provider decisions and all deterministic stages pass"
    Assert-True ([bool]$first.providerBoundary.replaceableAdapter -and [int]$first.providerBoundary.networkCalls -eq 0 -and [int]$first.providerBoundary.licenseBypass -eq 0) "provider adapter is replaceable and offline"
    Assert-True ([bool]$first.downstreamBuild.passed -and [int]$first.downstreamBuild.stageCount -eq 6 -and [bool]$first.downstreamBuild.failurePreservesLastValid) "shared Asset Build Pipeline runs in disposable scope"
    foreach ($evaluation in @($first.evaluations)) {
        Assert-True ([string]$evaluation.decision -eq [string]$evaluation.expected) ("expected decision is stable for " + [string]$evaluation.id)
        Assert-True ([int]$evaluation.networkCalls -eq 0 -and [int]$evaluation.runtimeRegistration -eq 0 -and [int]$evaluation.publishedArtifacts -eq 0) ("no external side effect for " + [string]$evaluation.id)
        if ([string]$evaluation.decision -eq "accept") {
            Assert-True (@($evaluation.stages).Count -eq 8 -and [string]$evaluation.reviewStatus -eq "needs-human-editor-review") ("all eight stages and human review are present: " + [string]$evaluation.id)
            Assert-True ($null -ne $evaluation.manifestCandidate -and [bool]$evaluation.manifestCandidate.readOnly -and [bool]$evaluation.manifestCandidate.runtimeRegistration -eq $false) ("AssetManifest candidate is read-only: " + [string]$evaluation.id)
            Assert-True ([string]$evaluation.preview.status -eq "deferred" -and [bool]$evaluation.preview.runtimeRequired) ("Preview runtime dependency is explicit: " + [string]$evaluation.id)
        }
    }
    $codes = @($first.evaluations | Where-Object { [string]$_.decision -eq "reject" } | ForEach-Object { [string]$_.code })
    Assert-True ($codes -contains "license-missing" -and $codes -contains "disconnected-components" -and $codes -contains "thin-wall" -and $codes -contains "palette-overflow" -and $codes -contains "network-denied") "license/mesh/palette/network rejection codes are actionable"
    Assert-True ([int]$first.repositoryIntegrity.coreDiff -eq 0 -and [int]$first.repositoryIntegrity.publishedArtifacts -eq 0) "Core and published Runtime artifacts remain unchanged"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second external 3D run passes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$first.metrics.determinismHash -eq [string]$second.metrics.determinismHash -and [string]$first.downstreamBuild.packageHash -eq [string]$second.downstreamBuild.packageHash) "external stage and downstream build hashes are deterministic"
    Write-Host "External image/text/mesh-to-3D pipeline v1 regression passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue }
}
