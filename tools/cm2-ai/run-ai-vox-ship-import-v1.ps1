# Existing-VOX Ship Import Assistant. It validates and analyzes source VOX files
# using the v150 coordinate contract, but never rewrites a binary or registers
# a Runtime ship.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-vox-ship-import-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-vox-ship-import-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\ai-vox-ship-import-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical $value) + [Environment]::NewLine, $utf8)
}
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)) | ForEach-Object { $_.ToString("x2") }) -join "") }
    finally { $sha.Dispose() }
}
function Read-U32([byte[]]$bytes, [int]$offset) {
    if ($offset -lt 0 -or $offset + 4 -gt $bytes.Length) { throw ("VOX read beyond file at " + $offset) }
    return [BitConverter]::ToUInt32($bytes, $offset)
}
function Read-Tag([byte[]]$bytes, [int]$offset) {
    if ($offset -lt 0 -or $offset + 4 -gt $bytes.Length) { throw ("VOX tag beyond file at " + $offset) }
    return [Text.Encoding]::ASCII.GetString($bytes, $offset, 4)
}
function Fail([string]$code, [string]$message, [string]$fieldPath, [string]$suggestion) {
    $report = [ordered]@{
        schema = "cm2.ai-vox-import-report/1"
        status = "candidate-only"
        result = "fail"
        code = $code
        fieldPath = $fieldPath
        message = $message
        suggestion = $suggestion
        assetWrites = 0
        runtimeRegistration = 0
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    exit 1
}
function Snapshot-Scopes {
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($scope in @("Content Mod 2", "Global Mod")) {
        $scopePath = Join-Path $root $scope
        if (-not (Test-Path -LiteralPath $scopePath -PathType Container)) { continue }
        $scopeFull = (Resolve-Path -LiteralPath $scopePath).Path
        foreach ($file in @(Get-ChildItem -LiteralPath $scopeFull -Recurse -File | Sort-Object FullName)) {
            $relative = $file.FullName.Substring($scopeFull.Length).TrimStart("\", "/").Replace("\", "/")
            [void]$records.Add([ordered]@{ path = $scope + "/" + $relative; hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant() })
        }
    }
    return Sha256-Text (Canonical $records.ToArray())
}
function Invoke-VoxValidator([string]$validatorPath, [string]$voxPath) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validatorPath -Path $voxPath *> $null
    $exitCode = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return [ordered]@{ passed = ($exitCode -eq 0); exitCode = $exitCode; tool = "build-teardown-vox-models/scripts/validate-vox.ps1" }
}
function Parse-VoxFile([string]$voxPath) {
    [byte[]]$bytes = [IO.File]::ReadAllBytes($voxPath)
    if ($bytes.Length -lt 20 -or (Read-Tag $bytes 0) -ne "VOX ") { throw "invalid VOX header" }
    $version = [int](Read-U32 $bytes 4)
    if ($version -ne 150) { throw ("unsupported VOX version " + $version) }
    if ((Read-Tag $bytes 8) -ne "MAIN") { throw "missing MAIN chunk" }
    $mainContentSize = [int](Read-U32 $bytes 12)
    $mainChildrenSize = [int](Read-U32 $bytes 16)
    $offset = 20 + $mainContentSize
    $mainEnd = $offset + $mainChildrenSize
    if ($mainEnd -ne $bytes.Length) { throw "MAIN child size does not match file length" }
    $models = New-Object System.Collections.Generic.List[object]
    $current = $null
    $sizeCount = 0
    $xyziCount = 0
    $rgbaCount = 0
    while ($offset -lt $mainEnd) {
        if ($offset + 12 -gt $mainEnd) { throw "incomplete VOX chunk header" }
        $tag = Read-Tag $bytes $offset
        $contentSize = [int](Read-U32 $bytes ($offset + 4))
        $childrenSize = [int](Read-U32 $bytes ($offset + 8))
        $contentStart = $offset + 12
        $nextOffset = $contentStart + $contentSize + $childrenSize
        if ($nextOffset -gt $mainEnd) { throw ("chunk " + $tag + " extends beyond MAIN") }
        if ($tag -eq "SIZE") {
            if ($contentSize -ne 12) { throw "SIZE must be 12 bytes" }
            $current = [ordered]@{ sizeX = [int](Read-U32 $bytes $contentStart); sizeY = [int](Read-U32 $bytes ($contentStart + 4)); sizeZ = [int](Read-U32 $bytes ($contentStart + 8)); voxels = (New-Object System.Collections.Generic.List[object]) }
            [void]$models.Add($current)
            $sizeCount++
        }
        elseif ($tag -eq "XYZI") {
            if ($null -eq $current -or $contentSize -lt 4) { throw "XYZI has no preceding SIZE or is too short" }
            $voxelCount = [int](Read-U32 $bytes $contentStart)
            if ($contentSize -ne 4 + ($voxelCount * 4)) { throw "XYZI content size mismatch" }
            for ($index = 0; $index -lt $voxelCount; $index++) {
                $voxelOffset = $contentStart + 4 + ($index * 4)
                [void]$current.voxels.Add([ordered]@{ x = [int]$bytes[$voxelOffset]; y = [int]$bytes[$voxelOffset + 1]; z = [int]$bytes[$voxelOffset + 2]; color = [int]$bytes[$voxelOffset + 3] })
            }
            $xyziCount++
        }
        elseif ($tag -eq "RGBA") {
            if ($contentSize -ne 1024) { throw "RGBA must be 1024 bytes" }
            $rgbaCount++
        }
        $offset = $nextOffset
    }
    if ($sizeCount -ne $xyziCount -or $rgbaCount -ne 1) { throw "VOX SIZE/XYZI/RGBA chunk contract failed" }
    return [ordered]@{ voxVersion = $version; byteLength = $bytes.Length; sizeChunks = $sizeCount; xyziChunks = $xyziCount; rgbaChunks = $rgbaCount; models = @($models.ToArray()) }
}
function Analyze-VoxModel([object]$model, [int]$modelIndex, [string]$assetHash, [object]$policy, [object]$validator) {
    $sizeX = [int]$model.sizeX
    $sizeY = [int]$model.sizeY
    $sizeZ = [int]$model.sizeZ
    $logicalSizeX = $sizeX
    $logicalSizeY = $sizeZ
    $logicalSizeZ = $sizeY
    $voxels = @($model.voxels.ToArray())
    $minX = $sizeX; $minY = $sizeZ; $minZ = $sizeY
    $maxX = 0; $maxY = 0; $maxZ = 0
    $occupancy = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($voxel in $voxels) {
        $logicalX = [int]$voxel.x
        $logicalY = [int]$voxel.z
        $logicalZ = $logicalSizeZ - 1 - [int]$voxel.y
        if ($logicalX -lt $minX) { $minX = $logicalX }; if ($logicalX -gt $maxX) { $maxX = $logicalX }
        if ($logicalY -lt $minY) { $minY = $logicalY }; if ($logicalY -gt $maxY) { $maxY = $logicalY }
        if ($logicalZ -lt $minZ) { $minZ = $logicalZ }; if ($logicalZ -gt $maxZ) { $maxZ = $logicalZ }
        [void]$occupancy.Add(($logicalX.ToString() + "|" + $logicalY.ToString() + "|" + $logicalZ.ToString()))
    }
    $mirrorMatches = 0
    foreach ($voxel in $voxels) {
        $logicalX = [int]$voxel.x
        $logicalY = [int]$voxel.z
        $logicalZ = $logicalSizeZ - 1 - [int]$voxel.y
        $mirrorX = $logicalSizeX - 1 - $logicalX
        if ($occupancy.Contains(($mirrorX.ToString() + "|" + $logicalY.ToString() + "|" + $logicalZ.ToString()))) { $mirrorMatches++ }
    }
    $symmetryScore = if ($voxels.Count -eq 0) { 0.0 } else { [Math]::Round($mirrorMatches / $voxels.Count, 4) }
    $symmetryClass = "asymmetric"
    if ($symmetryScore -ge 0.8) { $symmetryClass = "symmetric" } elseif ($symmetryScore -ge 0.5) { $symmetryClass = "partial" }
    $dimensions = @(
        [pscustomobject]@{ axis = "X"; value = $logicalSizeX },
        [pscustomobject]@{ axis = "Y"; value = $logicalSizeY },
        [pscustomobject]@{ axis = "Z"; value = $logicalSizeZ }
    )
    $principalAxes = @($dimensions | Sort-Object value -Descending | ForEach-Object { [string]$_.axis })
    $axisSignature = $principalAxes -join ">"
    $scaleClass = "small"
    $largest = [Math]::Max($logicalSizeX, [Math]::Max($logicalSizeY, $logicalSizeZ))
    if ($largest -ge 128) { $scaleClass = "large" } elseif ($largest -ge 64) { $scaleClass = "medium" }
    $complexityClass = "low"
    if ($voxels.Count -ge 100000) { $complexityClass = "high" } elseif ($voxels.Count -ge 10000) { $complexityClass = "medium" }
    $centerX = ($minX + $maxX) / 2.0
    $centerY = ($minY + $maxY) / 2.0
    $centerZ = ($minZ + $maxZ) / 2.0
    $normalizedCenter = [ordered]@{ x = [Math]::Round($centerX / $logicalSizeX, 4); y = [Math]::Round($centerY / $logicalSizeY, 4); z = [Math]::Round($centerZ / $logicalSizeZ, 4) }
    $engineCandidates = @(
        [ordered]@{ id = "rear-minus-z"; normalized = [ordered]@{ x = [Math]::Round($centerX / $logicalSizeX, 4); y = [Math]::Round($minY / $logicalSizeY, 4); z = [Math]::Round($minZ / $logicalSizeZ, 4) }; confidence = 0.35; reviewStatus = "needs-human-review" },
        [ordered]@{ id = "rear-plus-z"; normalized = [ordered]@{ x = [Math]::Round($centerX / $logicalSizeX, 4); y = [Math]::Round($minY / $logicalSizeY, 4); z = [Math]::Round($maxZ / $logicalSizeZ, 4) }; confidence = 0.35; reviewStatus = "needs-human-review" }
    )
    $mountRecommendation = if ($symmetryClass -eq "asymmetric") { "manual-anchor-selection" } else { "left-right-symmetry-candidate" }
    return [ordered]@{
        modelIndex = $modelIndex
        assetHash = $assetHash
        voxVersion = [int]$validator.voxVersion
        parserVersion = [string]$policy.parserVersion
        binary = [ordered]@{ byteLength = [int]$validator.byteLength; sizeChunks = [int]$validator.sizeChunks; xyziChunks = [int]$validator.xyziChunks; rgbaChunks = [int]$validator.rgbaChunks; voxelCount = $voxels.Count; validator = "pass" }
        voxSize = [ordered]@{ x = $sizeX; y = $sizeY; z = $sizeZ }
        logicalSize = [ordered]@{ x = $logicalSizeX; y = $logicalSizeY; z = $logicalSizeZ }
        logicalBounds = [ordered]@{ min = [ordered]@{ x = $minX; y = $minY; z = $minZ }; max = [ordered]@{ x = $maxX; y = $maxY; z = $maxZ } }
        principalAxisCandidates = $principalAxes
        axisSignature = $axisSignature
        symmetryScore = $symmetryScore
        symmetryClass = $symmetryClass
        scaleClass = $scaleClass
        complexityClass = $complexityClass
        orientation = [ordered]@{ upAxis = "logical+Y"; forwardCandidates = @("logical+Z", "logical-Z"); selected = $null; confidence = 0.0; reviewStatus = "needs-human-review"; pcaSelection = "candidate-only" }
        scale = [ordered]@{ metersPerVoxelCandidates = @($policy.scaleCandidatesMetersPerVoxel); recommended = 0.1; confidence = 0.5; reviewStatus = "measure-rendered-Shape-before-build" }
        engineCandidates = $engineCandidates
        cameraCandidate = [ordered]@{ normalized = $normalizedCenter; mode = "center-top"; confidence = 0.45; reviewStatus = "needs-human-review" }
        mountRecommendation = $mountRecommendation
        confidence = 0.0
        reviewStatus = "needs-human-review"
        finalBuildHash = "not-built:human-review"
        autoBuild = $false
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-vox-import-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Fail "policy-missing" "VOX import policy does not exist" "policy" "Restore the reviewed policy." }
    if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { Fail "fixture-missing" "VOX import fixture does not exist" "fixture" "Restore the three-asset fixture." }
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.schema -ne "cm2.ai-vox-import-policy/1") { Fail "policy-schema" "VOX import policy schema mismatch" "policy.schema" "Use policy v1." }
    if ([string]$fixture.schema -ne "cm2.ai-vox-import-fixtures/1") { Fail "fixture-schema" "VOX import fixture schema mismatch" "fixture.schema" "Use fixture v1." }
    $validatorPath = [string]$fixture.validator
    if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) { Fail "validator-missing" "VOX validator is unavailable" "fixture.validator" "Install or attach the build-teardown-vox-models validator." }
    $coreBefore = Snapshot-Scopes
    $fileReports = New-Object System.Collections.Generic.List[object]
    $allModels = New-Object System.Collections.Generic.List[object]
    foreach ($required in @($fixture.requiredModels)) {
        $relativePath = [string]$required.path
        $voxPath = Join-Path $root ($relativePath.Replace("/", "\"))
        if (-not (Test-Path -LiteralPath $voxPath -PathType Leaf)) { Fail "asset-missing" ("VOX asset does not exist: " + $relativePath) ("requiredModels." + [string]$required.id) "Restore the source VOX." }
        $assetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $voxPath).Hash.ToLowerInvariant()
        $validation = Invoke-VoxValidator $validatorPath $voxPath
        if (-not [bool]$validation.passed) { Fail "vox-validation" ("VOX validator failed: " + $relativePath) ("requiredModels." + [string]$required.id) "Repair the binary before importing." }
        $parsed = Parse-VoxFile $voxPath
        $validation.voxVersion = [int]$parsed.voxVersion
        $validation.byteLength = [int]$parsed.byteLength
        $validation.sizeChunks = [int]$parsed.sizeChunks
        $validation.xyziChunks = [int]$parsed.xyziChunks
        $validation.rgbaChunks = [int]$parsed.rgbaChunks
        $modelAnalyses = New-Object System.Collections.Generic.List[object]
        $modelIndex = 0
        foreach ($parsedModel in @($parsed.models)) {
            $modelIndex++
            $analysis = Analyze-VoxModel $parsedModel $modelIndex $assetHash $policy $validation
            [void]$modelAnalyses.Add($analysis)
            [void]$allModels.Add([ordered]@{ assetId = [string]$required.id; sourcePath = $relativePath; analysis = $analysis })
        }
        [void]$fileReports.Add([ordered]@{ assetId = [string]$required.id; sourcePath = $relativePath; assetHash = $assetHash; validation = $validation; modelCount = $modelAnalyses.Count; models = $modelAnalyses.ToArray() })
    }
    $coreAfter = Snapshot-Scopes
    $axisSignatures = @($allModels.ToArray() | ForEach-Object { [string]$_.analysis.axisSignature } | Sort-Object -Unique)
    $symmetryClasses = @($allModels.ToArray() | ForEach-Object { [string]$_.analysis.symmetryClass } | Sort-Object -Unique)
    $scaleClasses = @($allModels.ToArray() | ForEach-Object { [string]$_.analysis.scaleClass } | Sort-Object -Unique)
    $allAutoBuildDisabled = @($allModels.ToArray() | Where-Object { [bool]$_.analysis.autoBuild }).Count -eq 0
    $determinismHash = Sha256-Text (Canonical $allModels.ToArray())
    $repoUnchanged = $coreBefore -eq $coreAfter
    $validationsPass = @($fileReports.ToArray() | Where-Object { -not [bool]$_.validation.passed }).Count -eq 0
    $expected = $fixture.expected
    $report = [ordered]@{
        schema = "cm2.ai-vox-import-report/1"
        status = "candidate-only"
        policySchema = [string]$policy.schema
        toolVersion = [string]$policy.toolVersion
        modelVersion = [string]$policy.modelVersion
        parserVersion = [string]$policy.parserVersion
        coordinateContract = [ordered]@{ logicalAxes = $policy.coordinateContract.logicalAxes; mapping = [string]$policy.coordinateContract.mapping; sizeMapping = [string]$policy.coordinateContract.sizeMapping; upAxis = "logical+Y"; forwardSelection = "human-required" }
        files = $fileReports.ToArray()
        modelRecords = $allModels.Count
        axisSignatures = $axisSignatures
        symmetryClasses = $symmetryClasses
        scaleClasses = $scaleClasses
        diversity = [ordered]@{ distinctAxisSignatures = $axisSignatures.Count; distinctSymmetryClasses = $symmetryClasses.Count; distinctScaleClasses = $scaleClasses.Count; expectedMinimumsMet = ($allModels.Count -ge [int]$expected.minModelRecords -and $axisSignatures.Count -ge [int]$expected.minDistinctAxisSignatures -and $symmetryClasses.Count -ge [int]$expected.minDistinctSymmetryClasses) }
        review = [ordered]@{ autoBuild = $false; allRecommendationsHumanReview = $allAutoBuildDisabled; lowConfidenceBlocksBuild = [bool]$policy.confidencePolicy.lowConfidenceBlocksBuild; forwardAxisSelected = $false; pcaAutoSelected = $false }
        provenance = [ordered]@{ sourceHashesPresent = $true; modelIndexPresent = $true; scaleCandidates = @($policy.scaleCandidatesMetersPerVoxel); finalBuildHash = "not-built:human-review" }
        repositoryIntegrity = [ordered]@{ coreDiff = if ($repoUnchanged) { 0 } else { 1 }; sourceOfTruthPreserved = $repoUnchanged; assetWrites = 0; runtimeRegistration = 0 }
        runtime = [ordered]@{ status = "deferred"; teardownAvailable = ($null -ne (Get-Command Teardown.exe -ErrorAction SilentlyContinue)); reason = "VOX binary/axis analysis is headless; rendered Shape orientation, scale and moving attachment follow-up require Teardown.exe." }
        rollback = "Discard recommendations and retain original VOX/source; no binary rewrite or Runtime registration occurred."
        determinismHash = $determinismHash
        result = if ($validationsPass -and $allModels.Count -ge [int]$expected.minModelRecords -and $axisSignatures.Count -ge [int]$expected.minDistinctAxisSignatures -and $symmetryClasses.Count -ge [int]$expected.minDistinctSymmetryClasses -and $allAutoBuildDisabled -and $repoUnchanged) { "pass" } else { "fail" }
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ([string]$report.result -ne "pass") { exit 1 }
    exit 0
}
catch {
    $detail = $_.Exception.Message + " at " + $_.InvocationInfo.PositionMessage
    Fail "ai-vox-import-runner-error" $detail "runner" "Inspect the VOX binary, validator or coordinate fixture."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
