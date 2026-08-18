# Provider-neutral, offline external image/text/mesh-to-3D pipeline contract.
# It records candidate stages and invokes the existing Asset Build Pipeline in
# a disposable root; it never contacts a provider or publishes Runtime output.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-external-3d-pipeline-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-external-3d-pipeline-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\ai-external-3d-pipeline-v1.result.json" }
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
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Fail([string]$code, [string]$message, [string]$fieldPath, [string]$suggestion) {
    $report = [ordered]@{
        schema = "cm2.ai-external-3d-report/1"
        status = "candidate-only"
        result = "fail"
        code = $code
        fieldPath = $fieldPath
        message = $message
        suggestion = $suggestion
        networkCalls = 0
        runtimeRegistration = 0
        publishedArtifacts = 0
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
            [void]$records.Add([ordered]@{ path = $scope + "/" + $relative; hash = (Sha256-File $file.FullName) })
        }
    }
    return Sha256-Text (Canonical $records.ToArray())
}
function Get-InputHash([object]$inputSpec) {
    $source = [string]$inputSpec.sourceFile
    if ($source.StartsWith("Content Mod 2/", [StringComparison]::OrdinalIgnoreCase)) {
        $path = Join-Path $root ($source.Replace("/", "\"))
        if (Test-Path -LiteralPath $path -PathType Leaf) { return Sha256-File $path }
    }
    return Sha256-Text (Canonical $inputSpec)
}
function Invoke-DownstreamAssetBuild([string]$tempRoot) {
    $buildRoot = Join-Path $tempRoot "downstream-asset-build"
    $buildReportPath = Join-Path $buildRoot "build-report.json"
    $buildScript = Join-Path $root "tools\cm2-asset-build\run-asset-build-pipeline-v1.ps1"
    $fixturePath = Join-Path $root "docs\candidates\asset-importer-v1.fixture.json"
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript -FixturePath $fixturePath -BuildRoot $buildRoot -ReportPath $buildReportPath -NoCache *> $null
    $exitCode = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    $buildReport = $null
    if (Test-Path -LiteralPath $buildReportPath -PathType Leaf) { $buildReport = Get-Content -Raw -LiteralPath $buildReportPath | ConvertFrom-Json }
    return [ordered]@{
        passed = ($exitCode -eq 0 -and $null -ne $buildReport -and [string]$buildReport.result -eq "pass")
        exitCode = $exitCode
        stageCount = if ($null -eq $buildReport) { 0 } else { [int]$buildReport.stageCount }
        packageHash = if ($null -eq $buildReport) { "" } else { [string]$buildReport.packageHash }
        published = if ($null -eq $buildReport) { "not-run" } else { [string]$buildReport.published }
        failurePreservesLastValid = if ($null -eq $buildReport) { $false } else { [bool]$buildReport.failurePreservesLastValid }
        outputScope = "disposable-temp-only"
    }
}
function Evaluate-ExternalCase([object]$testCase, [object]$policy, [object]$fixture, [object]$downstream) {
    $inputSpec = $testCase.input
    $providerSpec = $testCase.provider
    $mesh = $testCase.mesh
    $inputHash = Get-InputHash $inputSpec
    $promptHash = Sha256-Text ([string]$testCase.prompt)
    $decision = "accept"
    $code = "candidate-valid"
    $reasons = New-Object System.Collections.Generic.List[string]
    $stages = New-Object System.Collections.Generic.List[object]
    $stageHashes = [ordered]@{}
    if ([bool]$providerSpec.network) {
        $decision = "reject"; $code = "network-denied"; [void]$reasons.Add("Provider network access is disabled in this candidate-only pipeline.")
    }
    elseif ([string]$testCase.requestedOperation -in @($policy.permissions.deny)) {
        $decision = "reject"; $code = "operation-denied"; [void]$reasons.Add("Runtime registration and publish operations are denied.")
    }
    elseif ([string]$inputSpec.sourceLicense -eq "" -or [string]$providerSpec.license -eq "") {
        $decision = "reject"; $code = "license-missing"; [void]$reasons.Add("Input and provider license/provenance are required.")
    }
    elseif (-not [bool]$inputSpec.sourceExists) {
        $decision = "reject"; $code = "source-missing"; [void]$reasons.Add("Input source is not available for a reproducible candidate.")
    }
    elseif ([int]$mesh.components -gt [int]$policy.limits.maxDisconnectedComponents) {
        $decision = "reject"; $code = "disconnected-components"; [void]$reasons.Add("Disconnected components exceed the publication limit.")
    }
    elseif ([int]$mesh.wallThicknessVoxels -lt [int]$policy.limits.minWallThicknessVoxels) {
        $decision = "reject"; $code = "thin-wall"; [void]$reasons.Add("Mesh repair must establish the minimum wall thickness.")
    }
    elseif ([int]$mesh.paletteColors -gt [int]$policy.limits.maxPaletteColors) {
        $decision = "reject"; $code = "palette-overflow"; [void]$reasons.Add("Palette/material mapping exceeds the v150 palette budget.")
    }
    elseif ([int]$mesh.voxelCount -gt [int]$policy.limits.maxVoxelCount) {
        $decision = "reject"; $code = "voxel-budget"; [void]$reasons.Add("Voxelization exceeds the importer budget.")
    }
    elseif ([string]$mesh.axis -notin @($policy.limits.allowedAxisCandidates)) {
        $decision = "reject"; $code = "axis-invalid"; [void]$reasons.Add("Axis candidate is not part of the reviewed coordinate contract.")
    }
    $finalBuildHash = "not-built:review"
    $manifestCandidate = $null
    if ($decision -eq "accept") {
        $currentHash = $inputHash
        foreach ($stageSpec in @($policy.stages)) {
            $stageId = [string]$stageSpec.id
            $parameters = [ordered]@{ seed = [int]$fixture.fixedSeed; inputKind = [string]$inputSpec.kind; provider = [string]$providerSpec.id; modelVersion = [string]$providerSpec.modelVersion; mesh = $mesh; stage = $stageId }
            $parameterHash = Sha256-Text (Canonical $parameters)
            $stagePayload = [ordered]@{ stage = $stageId; inputHash = $currentHash; parameterHash = $parameterHash; tool = [string]$stageSpec.tool }
            $outputHash = Sha256-Text (Canonical $stagePayload)
            [void]$stageHashes.Add($stageId, $outputHash)
            [void]$stages.Add([ordered]@{ id = $stageId; tool = [string]$stageSpec.tool; inputHash = $currentHash; parameterHash = $parameterHash; outputHash = $outputHash; deterministic = [bool]$stageSpec.deterministic; status = "pass" })
            $currentHash = $outputHash
        }
        $finalBuildHash = $currentHash
        $manifestCandidate = [ordered]@{
            schema = "cm2.asset-manifest-candidate/1"
            sourceFile = [string]$inputSpec.sourceFile
            inputKind = [string]$inputSpec.kind
            inputHash = $inputHash
            promptHash = $promptHash
            provider = [string]$providerSpec.id
            modelVersion = [string]$providerSpec.modelVersion
            license = [string]$providerSpec.license
            meshHash = [string]$providerSpec.meshHash
            voxelizationParamsHash = [string]$stageHashes["voxelization"]
            stageHashes = $stageHashes
            reviewStatus = "needs-human-editor-review"
            finalBuildHash = $finalBuildHash
            readOnly = $true
            runtimeRegistration = $false
        }
    }
    return [ordered]@{
        id = [string]$testCase.id
        prompt = [string]$testCase.prompt
        input = $inputSpec
        expected = [string]$testCase.expected
        decision = $decision
        code = $code
        reasons = $reasons.ToArray()
        inputHash = $inputHash
        promptHash = $promptHash
        provider = [ordered]@{ id = [string]$providerSpec.id; modelVersion = [string]$providerSpec.modelVersion; network = [bool]$providerSpec.network; license = [string]$providerSpec.license; replaceableAdapter = $true }
        meshChecks = [ordered]@{ components = [int]$mesh.components; wallThicknessVoxels = [int]$mesh.wallThicknessVoxels; paletteColors = [int]$mesh.paletteColors; voxelCount = [int]$mesh.voxelCount; axis = [string]$mesh.axis }
        stages = $stages.ToArray()
        stageHashes = $stageHashes
        manifestCandidate = $manifestCandidate
        preview = [ordered]@{ status = "deferred"; runtimeRequired = $true; packageConformance = "downstream-shared-build"; downstreamPackageHash = [string]$downstream.packageHash; compiler = "cm2.runtime-compiler/1"; humanReviewRequired = $true }
        reviewStatus = if ($decision -eq "accept") { "needs-human-editor-review" } else { "blocked:" + $code }
        finalBuildHash = $finalBuildHash
        networkCalls = 0
        runtimeRegistration = 0
        publishedArtifacts = 0
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-external-3d-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Fail "policy-missing" "External 3D policy does not exist" "policy" "Restore the reviewed policy." }
    if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { Fail "fixture-missing" "External 3D fixture does not exist" "fixture" "Restore the fixed provider/quality fixture." }
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.schema -ne "cm2.ai-external-3d-policy/1") { Fail "policy-schema" "External 3D policy schema mismatch" "policy.schema" "Use policy v1." }
    if ([string]$fixture.schema -ne "cm2.ai-external-3d-fixtures/1") { Fail "fixture-schema" "External 3D fixture schema mismatch" "fixture.schema" "Use fixture v1." }
    $coreBefore = Snapshot-Scopes
    $downstream = Invoke-DownstreamAssetBuild $tempRoot
    if (-not [bool]$downstream.passed) { Fail "downstream-build" "Shared Asset Build Pipeline did not pass" "downstream" "Fix the existing importer/build contract before external adapters." }
    $evaluations = New-Object System.Collections.Generic.List[object]
    foreach ($testCase in @($fixture.cases)) { [void]$evaluations.Add((Evaluate-ExternalCase $testCase $policy $fixture $downstream)) }
    $coreAfter = Snapshot-Scopes
    $matching = @($evaluations.ToArray() | Where-Object { [string]$_.decision -eq [string]$_.expected }).Count
    $accepted = @($evaluations.ToArray() | Where-Object { [string]$_.decision -eq "accept" })
    $legalRate = [Math]::Round($matching / $evaluations.Count, 4)
    $determinismHash = Sha256-Text (Canonical $evaluations.ToArray())
    $repoUnchanged = $coreBefore -eq $coreAfter
    $stageComplete = @($accepted | Where-Object { @($_.stages).Count -eq @($policy.stages).Count }).Count -eq $accepted.Count
    $report = [ordered]@{
        schema = "cm2.ai-external-3d-report/1"
        status = "candidate-only"
        policySchema = [string]$policy.schema
        toolVersion = [string]$policy.toolVersion
        adapterVersion = [string]$policy.adapterVersion
        fixedSeed = [int]$fixture.fixedSeed
        caseCount = $evaluations.Count
        evaluations = $evaluations.ToArray()
        metrics = [ordered]@{ accepted = $accepted.Count; rejected = @($evaluations.ToArray() | Where-Object { $_.decision -eq "reject" }).Count; legalRate = $legalRate; deterministicStages = $stageComplete; determinismHash = $determinismHash; performanceRisk = "deferred-until-voxel-preview" }
        providerBoundary = [ordered]@{ replaceableAdapter = $true; networkCalls = 0; providerArbitraryExec = 0; licenseBypass = 0 }
        downstreamBuild = $downstream
        review = [ordered]@{ humanApprovalRequired = $true; autoPublish = $false; runtimeOnlyCompiledOutput = $true; failurePreservesLastValid = $true }
        repositoryIntegrity = [ordered]@{ coreDiff = if ($repoUnchanged) { 0 } else { 1 }; sourceOfTruthPreserved = $repoUnchanged; publishedArtifacts = 0; runtimeRegistration = 0 }
        runtime = [ordered]@{ status = "deferred"; teardownAvailable = ($null -ne (Get-Command Teardown.exe -ErrorAction SilentlyContinue)); reason = "External provider is offline fixture-only; real image/text generation and end-to-end Teardown Preview require an operator/provider and remain deferred." }
        rollback = "Discard candidate/intermediate metadata and retain the last valid AssetManifest/package; removing the provider leaves the source manually buildable."
        result = if ($legalRate -eq 1.0 -and $stageComplete -and [bool]$downstream.passed -and $repoUnchanged) { "pass" } else { "fail" }
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ([string]$report.result -ne "pass") { exit 1 }
    exit 0
}
catch {
    Fail "ai-external-3d-runner-error" $_.Exception.Message "runner" "Inspect adapter permissions, provenance/license fields, quality limits or shared Asset Build output."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
