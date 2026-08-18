# Self-test for deterministic/cacheable Asset Build Pipeline v1.

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot "run-asset-build-pipeline-v1.ps1"
$fixture = Join-Path $PSScriptRoot "..\..\docs\candidates\asset-importer-v1.fixture.json"
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Asset Build Pipeline self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-ExpectedFailure([string]$buildRoot, [string]$fixturePath, [string]$reportPath, [string]$label) {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -BuildRoot $buildRoot -FixturePath $fixturePath -ReportPath $reportPath 2>$null *> $null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    Assert-True ($exitCode -ne 0) $label
}
function Write-Json([object]$value, [string]$path) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 60), $utf8) }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-asset-build-" + [Guid]::NewGuid().ToString("N"))
$buildOne = Join-Path $tempRoot "build-one"
$buildTwo = Join-Path $tempRoot "build-two"
$buildThree = Join-Path $tempRoot "build-three"
$invalidFixture = Join-Path $tempRoot "invalid-fixture.json"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $reportOnePath = Join-Path $tempRoot "report-one.json"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -BuildRoot $buildOne -ReportPath $reportOnePath *> $null
    Assert-True ($LASTEXITCODE -eq 0) "clean build publishes six stages"
    $reportOne = Get-Content -Raw -LiteralPath $reportOnePath | ConvertFrom-Json
    Assert-True ([int]$reportOne.stageCount -eq 6 -and [int]$reportOne.cacheMisses -eq 6 -and [int]$reportOne.cacheHits -eq 0) "clean build has six deterministic cache misses"
    Assert-True ([string]$reportOne.result -eq "pass" -and [bool]$reportOne.failurePreservesLastValid) "machine report records pass and rollback policy"
    $humanReportPath = Join-Path $buildOne "build-report.md"
    Assert-True (Test-Path -LiteralPath $humanReportPath -PathType Leaf) "clean build writes a human report"
    $humanReport = Get-Content -Raw -LiteralPath $humanReportPath
    Assert-True ($humanReport -match "# Asset Build Report v1" -and $humanReport -match "\| import \|") "human report contains stage cache details"
    $packageOne = Join-Path $buildOne "published\asset-package.json"
    $sidecarOne = Join-Path $buildOne "published\asset-package.sha256"
    Assert-True ((Test-Path -LiteralPath $packageOne -PathType Leaf) -and (Test-Path -LiteralPath $sidecarOne -PathType Leaf)) "atomic package and hash sidecar are published"
    $packageHashOne = (Get-FileHash -Algorithm SHA256 -LiteralPath $packageOne).Hash.ToLowerInvariant()
    Assert-True ($packageHashOne -eq [string]$reportOne.packageHash -and $packageHashOne -eq (Get-Content -Raw -LiteralPath $sidecarOne).Trim()) "package sidecar matches generated package"
    $packageOneDocument = Get-Content -Raw -LiteralPath $packageOne | ConvertFrom-Json
    Assert-True ([bool]$packageOneDocument.generated -and [string]$packageOneDocument.manualEdit -eq "forbidden") "package is generated and manual edit is forbidden"
    Assert-True ([int]$packageOneDocument.budget.bodyCount -le [int]$packageOneDocument.budget.limits.bodyCount -and [int]$packageOneDocument.budget.packageBytesEstimate -gt 0) "body/shape/joint/package budget is reported"

    $reportTwoPath = Join-Path $tempRoot "report-two.json"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -BuildRoot $buildOne -ReportPath $reportTwoPath *> $null
    Assert-True ($LASTEXITCODE -eq 0) "incremental build succeeds"
    $reportTwo = Get-Content -Raw -LiteralPath $reportTwoPath | ConvertFrom-Json
    Assert-True ([int]$reportTwo.cacheHits -eq 6 -and [int]$reportTwo.cacheMisses -eq 0 -and [string]$reportTwo.published -eq "unchanged") "incremental build reuses all stage cache entries"
    Assert-True ([string]$reportTwo.packageHash -eq $packageHashOne) "incremental package hash is byte-identical"

    $reportThreePath = Join-Path $tempRoot "report-three.json"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -BuildRoot $buildTwo -ReportPath $reportThreePath *> $null
    Assert-True ($LASTEXITCODE -eq 0) "clean workspace rebuild succeeds"
    $reportThree = Get-Content -Raw -LiteralPath $reportThreePath | ConvertFrom-Json
    Assert-True ([string]$reportThree.packageHash -eq $packageHashOne) "clean workspace output is deterministic"

    $toolVersionReportPath = Join-Path $tempRoot "tool-version-report.json"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -BuildRoot $buildOne -ToolVersion "cm2.asset-build/1.0.1" -ReportPath $toolVersionReportPath *> $null
    Assert-True ($LASTEXITCODE -eq 0) "tool-version change rebuild succeeds"
    $toolVersionReport = Get-Content -Raw -LiteralPath $toolVersionReportPath | ConvertFrom-Json
    Assert-True ([string]$toolVersionReport.toolVersion -eq "cm2.asset-build/1.0.1" -and [int]$toolVersionReport.cacheMisses -eq 6 -and [int]$toolVersionReport.cacheHits -eq 0) "tool-version change invalidates every stage cache entry"
    Assert-True ([string]$toolVersionReport.packageHash -ne $packageHashOne) "tool-version change produces a new package hash"

    $driftBytes = [Text.Encoding]::UTF8.GetBytes("{drift:true}")
    [IO.File]::WriteAllBytes($packageOne, $driftBytes)
    $driftReport = Join-Path $tempRoot "drift-report.json"
    Invoke-ExpectedFailure $buildOne $fixture $driftReport "rejects generated package drift before overwrite"
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $packageOne).Hash.ToLowerInvariant() -eq ([BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($driftBytes))).Replace("-", "").ToLowerInvariant()) "drifted package remains untouched after rejection"

    $invalidDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $invalidDocument.resources[0].sourceFile = "Content Mod 2/vox/does-not-exist-for-build.vox"
    Write-Json $invalidDocument $invalidFixture
    $failureReport = Join-Path $tempRoot "failure-report.json"
    $beforeFailure = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $buildTwo "published\asset-package.json")).Hash.ToLowerInvariant()
    Invoke-ExpectedFailure $buildTwo $invalidFixture $failureReport "fails invalid source before publish"
    $afterFailure = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $buildTwo "published\asset-package.json")).Hash.ToLowerInvariant()
    Assert-True ($beforeFailure -eq $afterFailure) "failed build preserves last valid package"

    $noCacheReport = Join-Path $tempRoot "nocache-report.json"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -BuildRoot $buildThree -NoCache -ReportPath $noCacheReport *> $null
    Assert-True ($LASTEXITCODE -eq 0) "no-cache rebuild succeeds"
    $noCache = Get-Content -Raw -LiteralPath $noCacheReport | ConvertFrom-Json
    Assert-True ([int]$noCache.cacheMisses -eq 6 -and [int]$noCache.cacheHits -eq 0) "no-cache mode invalidates every stage"
}
finally {
    $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
    $tempPrefix = ([IO.Path]::GetFullPath([IO.Path]::GetTempPath())).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-True ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) "pipeline self-test workspace is inside the system temp root"
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
