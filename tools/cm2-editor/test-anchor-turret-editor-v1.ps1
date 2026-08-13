# Self-test for VOX/Anchor/Mount/Turret 3D Editor data contracts.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Join-Path $PSScriptRoot "run-anchor-turret-editor-v1.ps1"
$fixturePath = Join-Path $root "docs\candidates\anchor-turret-editor-v1.fixture.json"
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Anchor/Turret Editor self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Editor([string]$fixture, [string]$report) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -FixturePath $fixture -ReportPath $report *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}
function Write-Fixture([object]$document, [string]$path) { [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 100), $utf8) }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-anchor-turret-editor-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $baseReport = Join-Path $tempRoot "base.report.json"
    Assert-True ((Invoke-Editor $fixturePath $baseReport) -eq 0) "accepts VOX manifest, graph, anchors, mounts and turret"
    $base = Get-Content -Raw -LiteralPath $baseReport | ConvertFrom-Json
    Assert-True ([string]$base.coordinateContract.storageSpace -eq "parent-local") "stores transforms in parent-local space"
    Assert-True ([string]$base.golden.wing.position -eq "12 2 -4" -or [double]$base.golden.wing.position[0] -eq 12) "root/child world golden is stable"
    Assert-True ([int]$base.graph.anchors -eq 4 -and [int]$base.graph.mounts -eq 2 -and [int]$base.graph.turrets -eq 1) "anchor/mount/turret tree is reported"
    Assert-True ([int]$base.sourcePatch.count -ge 4 -and -not [bool]$base.sourcePatch.generatedArtifactMutation) "edits emit source patches only"
    Assert-True ([string]$base.generatedCatalogHashBefore -eq [string]$base.generatedCatalogHashAfter) "generated Runtime catalog is unchanged"

    $cases = @(
        @{ Name = "stale asset manifest"; Mutate = { param($d) $d.assetManifest.manifestHash = "stale" } },
        @{ Name = "read-write asset"; Mutate = { param($d) $d.assetManifest.readOnly = $false } },
        @{ Name = "unconfirmed live orientation"; Mutate = { param($d) $d.assetManifest.orientation.confirmed = $false } },
        @{ Name = "graph cycle"; Mutate = { param($d) $d.graph.nodes[0].parentId = "nozzle" } },
        @{ Name = "duplicate anchor"; Mutate = { param($d) $d.anchors += $d.anchors[0] } },
        @{ Name = "joint budget overflow"; Mutate = { param($d) $d.modes.joint.joint = 5 } },
        @{ Name = "generated mutation policy"; Mutate = { param($d) $d.sourcePatchPolicy.generatedArtifactMutation = $true } }
    )
    foreach ($case in $cases) {
        $document = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        & $case.Mutate $document
        $caseFixture = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".json")
        $caseReport = Join-Path $tempRoot (($case.Name -replace "[^A-Za-z0-9]", "-") + ".report.json")
        Write-Fixture $document $caseFixture
        Assert-True ((Invoke-Editor $caseFixture $caseReport) -ne 0) ("rejects " + $case.Name)
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
