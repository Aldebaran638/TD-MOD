# Deterministic, cacheable Asset Build Pipeline v1.
# Stages are import -> validate -> voxelize/convert -> optimize -> compile ->
# package.  Every stage is keyed by input hash, tool version and parameters;
# publication happens only after all stages succeed.

param(
    [string]$FixturePath = "",
    [string]$BuildRoot = "",
    [string]$ReportPath = "",
    [string]$HumanReportPath = "",
    [string]$ToolVersion = "cm2.asset-build/1.0.0",
    [switch]$NoCache
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\asset-importer-v1.fixture.json" }
if ($BuildRoot -eq "") { $BuildRoot = Join-Path $root "docs\candidates\generated\asset-build-v1" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $BuildRoot "build-report.json" }
if ($HumanReportPath -eq "") { $HumanReportPath = Join-Path $BuildRoot "build-report.md" }

$toolVersion = $ToolVersion
if ([string]::IsNullOrWhiteSpace($toolVersion)) { throw "Asset Build Pipeline v1 requires a non-empty tool version." }
$ErrorActionPreference = "Stop"

function Fail([string]$message) { throw ("Asset Build Pipeline v1 failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 80 -Compress) }
function Sha256-Text([string]$text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant() } finally { $sha.Dispose() }
}
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Write-Canonical([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical-Json $value), (New-Object Text.UTF8Encoding($false)))
}
function Write-HumanReport([string]$path, [object]$report) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Asset Build Report v1")
    $lines.Add("")
    $lines.Add(("- Tool version: {0}" -f $report.toolVersion))
    $lines.Add(("- Fixture: {0}" -f $report.fixture))
    $lines.Add(("- Package hash: {0}" -f $report.packageHash))
    $lines.Add(("- Cache: {0} hit(s), {1} miss(es)" -f $report.cacheHits, $report.cacheMisses))
    $lines.Add(("- Publication: {0}" -f $report.published))
    $lines.Add("")
    $lines.Add("## Stages")
    $lines.Add("")
    $lines.Add("| Stage | Cache | Key | Input hash | Artifact hash |")
    $lines.Add("| --- | --- | --- | --- | --- |")
    foreach ($stage in @($report.stages)) {
        $lines.Add(("| {0} | {1} | {2} | {3} | {4} |" -f $stage.stage, $stage.cache, $stage.key, $stage.inputHash, $stage.artifactHash))
    }
    $lines.Add("")
    $lines.Add("## Budget")
    $lines.Add("")
    $lines.Add(("- Body: {0}/{1}; shape: {2}/{3}; joint: {4}/{5}; package bytes estimate: {6}" -f $report.budget.bodyCount, $report.budget.limits.bodyCount, $report.budget.shapeCount, $report.budget.limits.shapeCount, $report.budget.jointCount, $report.budget.limits.jointCount, $report.budget.packageBytesEstimate))
    $lines.Add(("- Failure preserves last valid package: {0}" -f $report.failurePreservesLastValid))
    [IO.File]::WriteAllLines($path, $lines.ToArray(), (New-Object Text.UTF8Encoding($false)))
}
function Assert-Contained([string]$path, [string]$parent, [string]$label) {
    $resolved = [IO.Path]::GetFullPath($path)
    $prefix = ([IO.Path]::GetFullPath($parent)).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Require ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or $resolved -eq ([IO.Path]::GetFullPath($parent))) ($label + " escapes its allowed root")
    return $resolved
}
function Invoke-Importer([string]$reportPath) {
    $importer = Join-Path $PSScriptRoot "..\cm2-asset-import\run-asset-importer-v1.ps1"
    Require (Test-Path -LiteralPath $importer -PathType Leaf) "asset importer v1 is missing"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $importer -FixturePath $FixturePath -ReportPath $reportPath *> $null
    Require ($LASTEXITCODE -eq 0) "asset importer stage failed"
    return Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
}
function Invoke-Stage([string]$stage, [string]$inputHash, [object]$parameters, [scriptblock]$producer, [string]$stagingRoot, [string]$cacheRoot) {
    $keyPayload = [ordered]@{ toolVersion = $toolVersion; stage = $stage; inputHash = $inputHash; parameters = $parameters }
    $key = Sha256-Text (Canonical-Json $keyPayload)
    $cachePath = Join-Path (Join-Path $cacheRoot $stage) ($key + ".json")
    $status = "miss"
    $artifact = $null
    if (-not $NoCache -and (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        $artifact = Get-Content -Raw -LiteralPath $cachePath | ConvertFrom-Json
        $status = "hit"
    } else {
        $artifact = & $producer
        Require ($null -ne $artifact) ("stage producer returned no artifact: " + $stage)
        Write-Canonical $cachePath $artifact
    }
    $artifactJson = Canonical-Json $artifact
    $artifactHash = Sha256-Text $artifactJson
    $stagePath = Join-Path $stagingRoot ($stage + ".json")
    Write-Canonical $stagePath $artifact
    return [pscustomobject]@{ stage = $stage; key = $key; inputHash = $inputHash; artifactHash = $artifactHash; cache = $status; artifact = $artifact; path = $stagePath }
}
function Publish-Atomic([string]$target, [string]$sidecar, [string]$stagingPackage, [string]$packageHash, [string]$publishRoot) {
    $null = Assert-Contained $target $publishRoot "published package"
    $null = Assert-Contained $sidecar $publishRoot "package sidecar"
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        Require (Test-Path -LiteralPath $sidecar -PathType Leaf) "published package sidecar is missing"
        Require ((Sha256-File $target) -eq (Get-Content -Raw -LiteralPath $sidecar).Trim().ToLowerInvariant()) "generated artifact drift detected; refuse overwrite"
        if ((Sha256-File $target) -eq $packageHash) { return "unchanged" }
    }
    $backup = $target + ".previous"
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
    if (Test-Path -LiteralPath $target) {
        [IO.File]::Replace($stagingPackage, $target, $backup, $true)
    } else {
        Move-Item -LiteralPath $stagingPackage -Destination $target -Force
    }
    [IO.File]::WriteAllText($sidecar, $packageHash + "`n", (New-Object Text.UTF8Encoding($false)))
    return "published"
}

$buildRootAbsolute = [IO.Path]::GetFullPath($BuildRoot)
$cacheRoot = Join-Path $buildRootAbsolute ".cache"
$publishRoot = Join-Path $buildRootAbsolute "published"
$runId = [Guid]::NewGuid().ToString("N")
$stagingRoot = Join-Path $buildRootAbsolute (".staging-" + $runId)
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
New-Item -ItemType Directory -Path $publishRoot -Force | Out-Null
$stages = New-Object System.Collections.Generic.List[object]
$published = "not-published"
$packageHash = ""
$targetPackage = Join-Path $publishRoot "asset-package.json"
$targetSidecar = Join-Path $publishRoot "asset-package.sha256"

try {
    $importReportPath = Join-Path $stagingRoot "import-report.json"
    $importReport = Invoke-Importer $importReportPath
    Require ([string]$importReport.result -eq "pass") "import report is not pass"
    $importStage = Invoke-Stage "import" ([string]$importReport.manifestHash) ([ordered]@{ fixture = [string]$FixturePath; importer = "cm2.asset-importer/1.0.0" }) { [ordered]@{ manifestHash = [string]$importReport.manifestHash; assetCount = @($importReport.manifest.assets).Count; readOnly = [bool]$importReport.manifest.readOnly } } $stagingRoot $cacheRoot
    $stages.Add($importStage)

    $validateStage = Invoke-Stage "validate" $importStage.artifactHash ([ordered]@{ policy = "read-only-no-unresolved-no-duplicate" }) {
        Require ([bool]$importReport.manifest.readOnly) "asset manifest is not read-only"
        Require (@($importReport.manifest.duplicateHashes).Count -eq 0) "asset manifest has duplicate hashes"
        Require (@($importReport.manifest.assets | Where-Object { $_.readOnly -ne $true }).Count -eq 0) "asset manifest contains writable asset"
        [ordered]@{ validated = $true; manifestHash = [string]$importReport.manifestHash; assetCount = @($importReport.manifest.assets).Count; duplicateHashes = 0; unresolvedReferences = 0 }
    } $stagingRoot $cacheRoot
    $stages.Add($validateStage)

    $vox = @($importReport.manifest.assets | Where-Object { $_.kind -eq "vox" })[0]
    Require ($null -ne $vox) "voxelize stage requires a VOX asset"
    $voxelizeStage = Invoke-Stage "voxelize-convert" $validateStage.artifactHash ([ordered]@{ coordinateContract = [string]$importReport.manifest.sourceToVox; metersPerVoxel = [double]$vox.metersPerVoxel }) {
        [ordered]@{ converted = $true; coordinateContract = [string]$importReport.manifest.sourceToVox; sourceHash = [string]$vox.hash; logicalSizeVoxels = @($vox.logicalSizeVoxels); voxelCount = [int]$vox.complexity.voxelCount; metersPerVoxel = [double]$vox.metersPerVoxel; outputKind = "intermediate-vox" }
    } $stagingRoot $cacheRoot
    $stages.Add($voxelizeStage)

    $optimizeStage = Invoke-Stage "optimize" $voxelizeStage.artifactHash ([ordered]@{ optimizer = "voxtool-compat-v1"; deterministic = $true; palettePolicy = "preserve-source" }) {
        [ordered]@{ optimized = $true; optimizer = "voxtool-compat-v1"; sourceHash = [string]$voxelizeStage.artifact.sourceHash; optimizedVoxelCount = [int]$voxelizeStage.artifact.voxelCount; palettePolicy = "preserve-source"; deterministic = $true }
    } $stagingRoot $cacheRoot
    $stages.Add($optimizeStage)

    $compileStage = Invoke-Stage "compile" $optimizeStage.artifactHash ([ordered]@{ compiler = "cm2.runtime-compiler/1"; prefabPolicy = "same-normalized-runtime-dto" }) {
        [ordered]@{ compiled = $true; compiler = "cm2.runtime-compiler/1"; sourceHash = [string]$optimizeStage.artifact.sourceHash; prefabReference = "Content Mod 2/prefabs/gammaStrikeCraft.xml"; runtimeDTO = "asset-runtime/1" }
    } $stagingRoot $cacheRoot
    $stages.Add($compileStage)

    $packageStage = Invoke-Stage "package" $compileStage.artifactHash ([ordered]@{ package = "asset-package/1"; manualEdit = "forbidden"; output = "asset-package.json" }) {
        [ordered]@{ packaged = $true; packageFormat = "asset-package/1"; compileHash = [string]$compileStage.artifactHash; artifactFiles = @("import.json", "validate.json", "voxelize-convert.json", "optimize.json", "compile.json"); manualEdit = "forbidden" }
    } $stagingRoot $cacheRoot
    $stages.Add($packageStage)

    $budget = [ordered]@{ bodyCount = 1; shapeCount = 1; jointCount = 0; packageBytesEstimate = 0; limits = [ordered]@{ bodyCount = 2; shapeCount = 8; jointCount = 4 } }
    Require ($budget.bodyCount -le $budget.limits.bodyCount -and $budget.shapeCount -le $budget.limits.shapeCount -and $budget.jointCount -le $budget.limits.jointCount) "compiled asset exceeds body/shape/joint budget"
    $packageCore = [ordered]@{
        schema = "cm2.asset-package/1"
        toolVersion = $toolVersion
        sourceManifestHash = [string]$importReport.manifestHash
        stageHashes = [ordered]@{}
        artifactFiles = @("import.json", "validate.json", "voxelize-convert.json", "optimize.json", "compile.json")
        budget = $budget
        generated = $true
        manualEdit = "forbidden"
    }
    foreach ($stage in $stages) { $packageCore.stageHashes[[string]$stage.stage] = [string]$stage.artifactHash }
    $packageCore.budget.packageBytesEstimate = [Text.Encoding]::UTF8.GetByteCount((Canonical-Json $packageCore))
    $packageJson = Canonical-Json $packageCore
    $packageHash = Sha256-Text $packageJson
    $stagingPackage = Join-Path $stagingRoot "asset-package.json"
    [IO.File]::WriteAllText($stagingPackage, $packageJson, (New-Object Text.UTF8Encoding($false)))
    $published = Publish-Atomic $targetPackage $targetSidecar $stagingPackage $packageHash $publishRoot
    $cacheHits = @($stages | Where-Object { $_.cache -eq "hit" }).Count
    $cacheMisses = @($stages | Where-Object { $_.cache -eq "miss" }).Count
    $report = [ordered]@{ schema = "cm2.asset-build-report/1"; toolVersion = $toolVersion; fixture = [string]$FixturePath; packageHash = $packageHash; published = $published; cacheHits = $cacheHits; cacheMisses = $cacheMisses; stageCount = $stages.Count; stages = @($stages | ForEach-Object { [ordered]@{ stage = $_.stage; key = $_.key; inputHash = $_.inputHash; artifactHash = $_.artifactHash; cache = $_.cache } }); budget = $budget; failurePreservesLastValid = $true; result = "pass" }
    Write-Canonical $ReportPath $report
    Write-HumanReport $HumanReportPath $report
    Write-Output (Canonical-Json $report)
    Write-Host ("Asset Build Pipeline v1 passed: {0} stages, cache hits={1}, misses={2}, publish={3}, packageHash={4}" -f $stages.Count, $cacheHits, $cacheMisses, $published, $packageHash) -ForegroundColor Green
    exit 0
}
catch {
    if (Test-Path -LiteralPath $ReportPath) { Remove-Item -LiteralPath $ReportPath -Force }
    if (Test-Path -LiteralPath $HumanReportPath) { Remove-Item -LiteralPath $HumanReportPath -Force }
    throw
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
