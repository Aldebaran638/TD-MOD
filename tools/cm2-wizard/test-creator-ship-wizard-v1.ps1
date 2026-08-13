# Self-test for Creator Ship Wizard v1 output, rejection and safety boundaries.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Join-Path $PSScriptRoot "run-creator-ship-wizard-v1.ps1"
$fixturePath = Join-Path $root "docs\candidates\creator-ship-wizard-v1.fixture.json"
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Creator Ship Wizard self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Wizard([string]$fixture, [string]$report, [string]$staging) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -FixturePath $fixture -ReportPath $report -StagingPath $staging *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}
function Write-Fixture([object]$document, [string]$path) { [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 100), $utf8) }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-creator-wizard-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $sourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $fixturePath).Hash
    $baseReport = Join-Path $tempRoot "base.report.json"
    $baseStaging = Join-Path $tempRoot "base.staging"
    Assert-True ((Invoke-Wizard $fixturePath $baseReport $baseStaging) -eq 0) "accepts ordered VOX-to-Preview wizard flow"
    $base = Get-Content -Raw -LiteralPath $baseReport | ConvertFrom-Json
    Assert-True ([int]$base.staging.fileCount -eq 4 -and (Test-Path (Join-Path $baseStaging "package.manifest.json"))) "writes isolated manifest, VehicleDefinition, Anchor/Mount and catalog projection"
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $baseStaging "package.manifest.json") | ConvertFrom-Json
    Assert-True ([string]$manifest.packageHash -eq [string]$base.packageHash -and [string]$base.staging.packageManifestFileHash -ne "" -and -not [bool]$manifest.runtimeRegistration) "records package and manifest file hashes without Runtime registration"
    Assert-True ([int]$base.metrics.userCount -eq 3 -and [double]$base.metrics.localizableErrorRate -ge 0.9) "records three non-Core users and localizable diagnostics"
    Assert-True ([int]$base.metrics.luaCalls -eq 0 -and [double]$base.metrics.maxCoordinateDriftMeters -eq 0) "wizard remains Lua-free with zero coordinate drift"
    Assert-True ([int]$base.metrics.maxPreviewDifferenceCount -eq 0 -and -not [bool]$base.coreMutation -and -not [bool]$base.runtimeCatalogMutation) "Preview, catalog and Core boundaries are clean"

    $secondReport = Join-Path $tempRoot "second.report.json"
    $secondStaging = Join-Path $tempRoot "second.staging"
    Assert-True ((Invoke-Wizard $fixturePath $secondReport $secondStaging) -eq 0) "rebuilds the same source in a clean staging directory"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$base.sourceHash -eq [string]$second.sourceHash -and [string]$base.buildHash -eq [string]$second.buildHash -and [string]$base.packageHash -eq [string]$second.packageHash) "clean builds are deterministic and cache-correct"
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $fixturePath).Hash -eq $sourceHashBefore) "build leaves source unchanged"

    $cases = @(
        @{ Name = "wrong step order"; Mutate = { param($d) $first = $d.orderedSteps[0]; $d.orderedSteps[0] = $d.orderedSteps[1]; $d.orderedSteps[1] = $first } },
        @{ Name = "missing VOX asset"; Mutate = { param($d) $d.assetInput.voxPath = "Content Mod 2/vox/does-not-exist.vox" } },
        @{ Name = "orientation confirmation"; Mutate = { param($d) $d.assetInput.confirmedOrientation.forward = "UNKNOWN" } },
        @{ Name = "anchor outside VOX bounds"; Mutate = { param($d) $d.shipSource.anchors[0].localPosition[0] = 99 } },
        @{ Name = "invalid mass"; Mutate = { param($d) $d.shipSource.body.massKg = 0 } },
        @{ Name = "missing engine anchor"; Mutate = { param($d) $d.shipSource.engines[0].anchorId = "engine.missing" } },
        @{ Name = "Core boundary"; Mutate = { param($d) $d.coreBoundary.mustRemainUnmodified = $false } },
        @{ Name = "unlocalizable error"; Mutate = { param($d) $d.users[0].errors[0].fieldPath = "" } }
    )
    foreach ($case in $cases) {
        $document = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        & $case.Mutate $document
        $safeName = $case.Name -replace "[^A-Za-z0-9]", "-"
        $caseFixture = Join-Path $tempRoot ($safeName + ".json")
        $caseReport = Join-Path $tempRoot ($safeName + ".report.json")
        $caseStaging = Join-Path $tempRoot ($safeName + ".staging")
        Write-Fixture $document $caseFixture
        Assert-True ((Invoke-Wizard $caseFixture $caseReport $caseStaging) -ne 0) ("rejects " + $case.Name)
        Assert-True (-not (Test-Path -LiteralPath $caseStaging)) ("rejects " + $case.Name + " before writing partial artifacts")
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
