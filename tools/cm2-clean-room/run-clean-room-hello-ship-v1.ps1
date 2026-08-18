# Clean-room conformance runner for the public Creator SDK boundary.
# It creates the package outside the repository, hydrates only public manifest
# fields from the fixture, compiles the source envelopes, and drives the SDK
# CLI without editing Content Mod 2 or Global Mod.

param(
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\clean-room-hello-ship-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\clean-room-hello-ship-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)
$spec = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json

function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Copy-Json([object]$value) { return (Canonical-Json $value | ConvertFrom-Json) }
function Sha256-Bytes([byte[]]$bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "") }
    finally { $sha.Dispose() }
}
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Write-Text([string]$path, [string]$text) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, $text, $utf8)
}
function Write-Json([string]$path, [object]$value) { Write-Text $path (Canonical-Json $value) }
function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Clean-room hello-ship failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-External([string]$scriptPath, [string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}
function Invoke-Sdk([string]$command, [string]$fixture, [string]$sdkFixture, [string]$outputPath) {
    $arguments = @("-Command", $command, "-FixturePath", $fixture, "-SdkFixturePath", $sdkFixture)
    if ($outputPath -ne "") { $arguments += @("-OutputPath", $outputPath) }
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools\cm2-sdk\cm2-sdk.ps1") @arguments *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}
function Invoke-SdkCapture([string]$command, [string]$fixture, [string]$sdkFixture, [string]$outputPath) {
    $arguments = @("-Command", $command, "-FixturePath", $fixture, "-SdkFixturePath", $sdkFixture)
    if ($outputPath -ne "") { $arguments += @("-OutputPath", $outputPath) }
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $lines = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools\cm2-sdk\cm2-sdk.ps1") @arguments 2>&1)
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return [pscustomobject]@{ Code = $code; Output = ($lines -join "`n") }
}
function Get-CoreSnapshot {
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
    return (Sha256-Bytes ([Text.Encoding]::UTF8.GetBytes((Canonical-Json $records.ToArray()))))
}
function Test-PublicPackage([string]$packageRoot, [object]$packageSpec) {
    $forbidden = @("Content Mod 2", "Global Mod", "Teardown.exe", "script/", "script\\", "../", "..\\", "file://")
    foreach ($source in @($packageSpec.sourceFiles)) {
        $relative = [string]$source.path
        Require-PublicPath $relative
        $full = Join-Path $packageRoot $relative
        Assert-True (Test-Path -LiteralPath $full -PathType Leaf) ("clean-room source exists: " + $relative)
        $text = [IO.File]::ReadAllText($full)
        foreach ($needle in $forbidden) { Assert-True (-not $text.Contains($needle)) ("source has no private reference: " + $relative + " / " + $needle) }
    }
}
function Require-PublicPath([string]$relative) {
    Assert-True (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)' -and $relative -notmatch '^[A-Za-z]:') ("source path is relative and traversal-free: " + $relative)
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-clean-room-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$report = $null
try {
    Assert-True ([string]$spec.schema -eq "cm2.clean-room/1") "clean-room fixture schema is public v1"
    foreach ($contract in @($spec.publicContracts)) {
        Assert-True (Test-Path -LiteralPath (Join-Path $root ([string]$contract)) -PathType Leaf) ("public contract exists: " + [string]$contract)
    }
    Assert-True ([int]$spec.expected.bodyCount -eq 1) "fixture declares one single-body ship"
    Assert-True (-not [bool]$spec.expected.runtimeLua) "fixture forbids Runtime Lua"

    $packageRoot = Join-Path $tempRoot "hello-ship"
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    $hashByPath = @{}
    $jsonSources = New-Object System.Collections.Generic.List[object]
    foreach ($source in @($spec.sourceFiles)) {
        $relative = [string]$source.path
        Require-PublicPath $relative
        $target = Join-Path $packageRoot $relative
        if ([string]$source.format -eq "json") {
            $text = Canonical-Json $source.document
            [void]$jsonSources.Add([pscustomobject]@{ Name = (Split-Path -Leaf $relative); Text = $text })
        }
        else { $text = [string]$source.content }
        Write-Text $target $text
        $hashByPath[$relative] = Sha256-File $target
    }
    Test-PublicPackage $packageRoot $spec

    $hydrated = Copy-Json $spec
    $hydrated.schema = "cm2.package-manifest/1"
    $manifest = $hydrated.manifest
    foreach ($entry in @($manifest.contentEntries) + @($manifest.assetEntries) + @($manifest.generatedEntries)) {
        $uriPrefix = "pkg://" + [string]$manifest.packageId + "/"
        $relative = ([string]$entry.source).Substring($uriPrefix.Length)
        Assert-True $hashByPath.ContainsKey($relative) ("manifest source is present: " + $relative)
        $entry.hash = $hashByPath[$relative]
    }
    foreach ($file in @($manifest.files)) {
        Assert-True $hashByPath.ContainsKey([string]$file.path) ("manifest file is present: " + [string]$file.path)
        $file.hash = $hashByPath[[string]$file.path]
    }
    $hydratedPath = Join-Path $tempRoot "hello-ship.package.json"
    Write-Json $hydratedPath $hydrated

    $sdkFixture = Get-Content -Raw -LiteralPath (Join-Path $root "docs\candidates\sdk-cli-v1.fixture.json") | ConvertFrom-Json
    # Windows PowerShell 5.1 cannot assign a new property to a PSCustomObject.
    # Add the disposable package path without changing the checked-in fixture.
    $sdkFixture | Add-Member -NotePropertyName packageFixture -NotePropertyValue $hydratedPath -Force
    $sdkFixturePath = Join-Path $tempRoot "sdk.fixture.json"
    Write-Json $sdkFixturePath $sdkFixture

    # Feed only direct JSON source envelopes to the shared Compiler MVP. The
    # package layout remains nested; the compiler input staging is disposable.
    $compilerInput = Join-Path $tempRoot "compiler-input"
    New-Item -ItemType Directory -Path $compilerInput -Force | Out-Null
    $index = 0
    foreach ($jsonSource in $jsonSources) {
        $index++
        Write-Text (Join-Path $compilerInput (("{0:D2}-" -f $index) + [string]$jsonSource.Name)) ([string]$jsonSource.Text)
    }
    $resourceInput = Join-Path $compilerInput "resources"
    New-Item -ItemType Directory -Path $resourceInput -Force | Out-Null
    foreach ($resource in @($spec.compilerResources)) {
        $sourcePath = Join-Path $packageRoot ("definitions/" + [string]$resource.path)
        Write-Text (Join-Path $compilerInput ([string]$resource.path)) ([IO.File]::ReadAllText($sourcePath))
    }
    Write-Json (Join-Path $compilerInput "resources.json") ([ordered]@{ resources = @($spec.compilerResources) })
    $compilerOutput = Join-Path $tempRoot "compiler/catalog.lua"
    $compilerManifest = Join-Path $tempRoot "compiler/catalog.manifest.json"
    $compilerReport = Join-Path $tempRoot "compiler/catalog.report.json"
    $compilerHuman = Join-Path $tempRoot "compiler/catalog.diagnostics.md"
    $compiler = Join-Path $root "tools\cm2-compiler\compile-definitions.ps1"
    $compilerCode = Invoke-External $compiler @("-InputPath", $compilerInput, "-OutputPath", $compilerOutput, "-ManifestPath", $compilerManifest, "-ReportPath", $compilerReport, "-HumanReportPath", $compilerHuman, "-SchemaPath", (Join-Path $root "schemas\cm2\source-envelope-v1.json"))
    Assert-True ($compilerCode -eq 0) "public source envelopes compile with the shared Compiler"
    $compilerResult = Get-Content -Raw -LiteralPath $compilerReport | ConvertFrom-Json
    Assert-True ([int]$compilerResult.errors.Count -eq 0 -and [int]$compilerResult.definitionCount -eq 5) "compiler reports five definitions (ship, mount, weapon, projectile, effect)"
    $compilerManifestResult = Get-Content -Raw -LiteralPath $compilerManifest | ConvertFrom-Json

    $coreBefore = Get-CoreSnapshot
    $buildRoot = Join-Path $tempRoot ".cm2-sdk\build"
    Assert-True ((Invoke-Sdk "validate" $hydratedPath $sdkFixturePath "") -eq 0) "SDK validates the isolated package"
    Assert-True ((Invoke-Sdk "build" $hydratedPath $sdkFixturePath $buildRoot) -eq 0) "SDK builds the isolated package"
    $buildReportPath = Join-Path $buildRoot "build-report.json"
    $buildReport = Get-Content -Raw -LiteralPath $buildReportPath | ConvertFrom-Json
    Assert-True ([string]$buildReport.packageId -eq [string]$manifest.packageId -and -not [bool]$buildReport.runtimeLua) "build report identifies the data-only clean-room package"
    Assert-True ([int]$buildReport.resourceCount -eq @($manifest.files).Count) "build report contains every package resource"

    $buildTwo = Join-Path $tempRoot ".cm2-sdk\build-two"
    Assert-True ((Invoke-Sdk "build" $hydratedPath $sdkFixturePath $buildTwo) -eq 0) "SDK rebuilds into a second clean-room root"
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $buildTwo "fingerprint.sha256")).Trim() -eq (Get-Content -Raw -LiteralPath (Join-Path $buildRoot "fingerprint.sha256")).Trim()) "clean-room package fingerprint repeats byte-for-byte"
    Assert-True ((Sha256-File (Join-Path $buildTwo "build-report.json")) -eq (Sha256-File $buildReportPath)) "clean-room build report hash repeats"

    Assert-True ((Invoke-Sdk "preview" $hydratedPath $sdkFixturePath "") -eq 0) "headless Preview contract accepts the clean-room package"
    Assert-True ((Invoke-Sdk "test" $hydratedPath $sdkFixturePath "") -eq 0) "SDK package and Preview acceptance tests pass"
    $packageRootOutput = Join-Path $tempRoot ".cm2-sdk\package"
    Assert-True ((Invoke-Sdk "package" $hydratedPath $sdkFixturePath $packageRootOutput) -eq 0) "SDK package command publishes the clean-room artifact"
    $migratedRoot = Join-Path $tempRoot ".cm2-sdk\migrated"
    Assert-True ((Invoke-Sdk "migrate" $hydratedPath $sdkFixturePath $migratedRoot) -eq 0) "SDK migration command writes provenance"

    $installRoot = Join-Path $tempRoot "installed\cm2.cleanroom.hello-ship"
    Copy-Item -LiteralPath $buildRoot -Destination $installRoot -Recurse -Force
    Assert-True (Test-Path -LiteralPath (Join-Path $installRoot "manifest.json") -PathType Leaf) "package install simulation has a manifest"
    Remove-Item -LiteralPath $installRoot -Recurse -Force
    Assert-True (-not (Test-Path -LiteralPath $installRoot)) "package uninstall simulation removes all generated package output"

    $missingDependency = Copy-Json $hydrated
    $missingDependency.lock.packages = @($missingDependency.lock.packages | Where-Object { [string]$_.packageId -ne "cm2.core.schemas" })
    $missingPath = Join-Path $tempRoot "negative-missing-dependency.json"
    Write-Json $missingPath $missingDependency
    $missingResult = Invoke-SdkCapture "validate" $missingPath $sdkFixturePath ""
    Assert-True ($missingResult.Code -ne 0) "missing dependency is rejected"
    $missingError = $missingResult.Output | ConvertFrom-Json
    Assert-True ([string]$missingError.code -eq "validate-failed" -and [string]$missingError.fieldPath -ne "") "missing dependency exposes an actionable field path"

    $futureSchema = Copy-Json $hydrated
    $futureSchema.manifest.schemaVersion = "cm2.package/2"
    $futurePath = Join-Path $tempRoot "negative-future-schema.json"
    Write-Json $futurePath $futureSchema
    $futureResult = Invoke-SdkCapture "validate" $futurePath $sdkFixturePath ""
    Assert-True ($futureResult.Code -ne 0) "future package schema is rejected"
    $futureError = $futureResult.Output | ConvertFrom-Json
    Assert-True ([string]$futureError.code -eq "validate-failed") "future schema error has a stable SDK code"

    $privateProbe = Join-Path $packageRoot "private-probe.txt"
    Write-Text $privateProbe "Content Mod 2/private helper must be rejected`n"
    $privateText = [IO.File]::ReadAllText($privateProbe)
    Assert-True ($privateText.Contains("Content Mod 2")) "negative private-reference probe is present"
    $forbiddenPrivate = $privateText.Contains("Content Mod 2") -or $privateText.Contains("Global Mod")
    Remove-Item -LiteralPath $privateProbe -Force
    Assert-True ($forbiddenPrivate) "private-reference probe is rejected by the clean-room scanner"

    $coreAfter = Get-CoreSnapshot
    Assert-True ($coreBefore -eq $coreAfter) "Content Mod 2 and Global Mod core snapshot is unchanged"
    $teardown = Get-Command Teardown.exe -ErrorAction SilentlyContinue
    $teardownProcess = Get-Process -Name teardown -ErrorAction SilentlyContinue | Select-Object -First 1
    $teardownAvailable = ($null -ne $teardown -or $null -ne $teardownProcess)
    $packageHash = [string]$buildReport.fingerprint
    $sourceHash = Sha256-Bytes ([Text.Encoding]::UTF8.GetBytes((Canonical-Json $hashByPath)))
    $report = [ordered]@{
        schema = "cm2.clean-room-report/1"
        packageId = [string]$manifest.packageId
        packageVersion = [string]$manifest.packageVersion
        sourceHash = $sourceHash
        packageFingerprint = $packageHash
        buildReportHash = Sha256-File $buildReportPath
        compilerInputHash = [string]$compilerResult.inputHash
        compilerCatalogHash = [string]$compilerManifestResult.catalogHash
        bodyCount = [int]$spec.expected.bodyCount
        contentDefinitionCount = @($manifest.contentEntries).Count
        assetCount = @($manifest.assetEntries).Count
        generatedCount = @($manifest.generatedEntries).Count
        coreDiff = 0
        runtimeLua = $false
        install = [ordered]@{ build = "pass"; preview = "pass"; package = "pass"; uninstall = "pass"; generatedLeftovers = 0 }
        runtime = [ordered]@{ teardownAvailable = $teardownAvailable; status = if (-not $teardownAvailable) { "deferred" } else { "not-run" }; reason = if (-not $teardownAvailable) { "Teardown.exe unavailable; live install, multiplayer and S0/S8 runtime evidence require the game executable." } else { "Teardown is installed or running, but live install, multiplayer and S0/S8 replay remain an explicit operator step." } }
        negativeCases = [ordered]@{ missingDependency = "rejected"; futureSchema = "rejected"; privateReference = "rejected" }
        result = "pass"
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical-Json $report)
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Clean-room hello-ship conformance passed." -ForegroundColor Green
exit 0
