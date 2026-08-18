# Regression test for the existing-VOX Ship Import Assistant.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-ai-vox-ship-import-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-ai-vox-ship-import-v1.ps1"
$policy = Join-Path $root "docs\ai-vox-ship-import-v1.json"
$fixture = Join-Path $root "docs\candidates\ai-vox-ship-import-v1.fixture.json"
$report = Join-Path $root "docs\candidates\ai-vox-ship-import-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-vox-import-" + [Guid]::NewGuid().ToString("N") + ".json")

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("VOX Ship Import v1 failed: " + $message) }
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
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "VOX import runner passes"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.ai-vox-import-report/1" -and [string]$first.status -eq "candidate-only") "report declares candidate-only status"
    Assert-True (@($first.files).Count -eq 3 -and [int]$first.modelRecords -eq 7) "three source files and seven VOX model records are analyzed"
    Assert-True (@($first.files | Where-Object { @($_.validation | Where-Object { -not [bool]$_.passed }).Count -eq 0 }).Count -eq 3) "every source file passes the v150 binary validator"
    Assert-True ([int]$first.diversity.distinctAxisSignatures -ge 3 -and [int]$first.diversity.distinctSymmetryClasses -ge 2) "axis and symmetry diversity is measured across references"
    Assert-True ([string]$first.coordinateContract.upAxis -eq "logical+Y" -and [string]$first.coordinateContract.forwardSelection -eq "human-required") "logical Teardown axes and human forward selection are declared"
    Assert-True (-not [bool]$first.review.autoBuild -and [bool]$first.review.allRecommendationsHumanReview -and -not [bool]$first.review.forwardAxisSelected -and -not [bool]$first.review.pcaAutoSelected) "low confidence blocks build and PCA never auto-selects orientation"
    foreach ($fileReport in @($first.files)) {
        Assert-True ([string]$fileReport.assetHash -ne "" -and [int]$fileReport.modelCount -ge 1) ("asset hash and model count are present: " + [string]$fileReport.assetId)
        foreach ($modelRecord in @($fileReport.models)) {
            Assert-True ([int]$modelRecord.voxVersion -eq 150 -and [string]$modelRecord.reviewStatus -eq "needs-human-review") ("model provenance and review status are present: " + [string]$fileReport.assetId + "/" + [string]$modelRecord.modelIndex)
            Assert-True (@($modelRecord.engineCandidates).Count -eq 2 -and [string]$modelRecord.orientation.selected -eq "") ("engine alternatives and unresolved forward orientation are explicit: " + [string]$fileReport.assetId + "/" + [string]$modelRecord.modelIndex)
            Assert-True (@($modelRecord.scale.metersPerVoxelCandidates).Count -eq 3 -and [string]$modelRecord.finalBuildHash -eq "not-built:human-review") ("scale candidates and no-build provenance are explicit: " + [string]$fileReport.assetId + "/" + [string]$modelRecord.modelIndex)
        }
    }
    Assert-True ([int]$first.repositoryIntegrity.assetWrites -eq 0 -and [int]$first.repositoryIntegrity.runtimeRegistration -eq 0 -and [int]$first.repositoryIntegrity.coreDiff -eq 0) "VOX assets, Runtime registration and Core remain unchanged"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second VOX import run passes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$first.determinismHash -eq [string]$second.determinismHash) "binary analysis and recommendations are deterministic"
    Write-Host "AI Existing-VOX Ship Import v1 regression passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue }
}
