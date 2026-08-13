# Install a policy-compatible package in an independent Teardown Consumer Mod.
# Compatibility is resolved before any Consumer artifact is replaced.

param(
    [string]$BuildPath = "",
    [string]$ConsumerRoot = "",
    [string]$TracePath = "",
    [string]$CoreApiVersion = "1.2.0",
    [string]$SdkVersion = "1.0.0",
    [string]$InstallId = "compatibility-consumer-install-v1"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($BuildPath -eq "") { $BuildPath = Join-Path $root "testing\fixtures\creator_sdk\alpha_project\.cm2-sdk\package" }
if ($ConsumerRoot -eq "") { $ConsumerRoot = Join-Path $root "_AI Test Consumer Compatibility V1" }
if ($TracePath -eq "") { $TracePath = Join-Path $root "docs\candidates\compatibility-policy-v1.consumer-trace.json" }
$resolver = Join-Path $PSScriptRoot "resolve-compatibility-v1.ps1"
$utf8 = New-Object Text.UTF8Encoding($false)

function Fail([string]$message) { throw ("Compatibility Consumer install failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Write-TextAtomic([string]$path, [string]$text) {
    $full = [IO.Path]::GetFullPath($path)
    $parent = Split-Path -Parent $full
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = $full + ".tmp." + [Guid]::NewGuid().ToString("N")
    try { [IO.File]::WriteAllText($temporary, $text, $utf8); Move-Item -LiteralPath $temporary -Destination $full -Force }
    finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue } }
}
function Xml-Escape([string]$value) { return [Security.SecurityElement]::Escape($value) }
function Invoke-Resolution([object]$manifest, [string]$core, [string]$sdk, [string]$reportPath) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $resolver `
        -PackageSchema ([string]$manifest.schemaVersion) `
        -PackageCoreRange ([string]$manifest.coreApiVersionRange) `
        -PackageSdkRange ([string]$manifest.sdkVersionRange) `
        -BuildFormat ([string]$manifest.buildFormatVersion) `
        -CoreApiVersion $core -SdkVersion $sdk -PackageId ([string]$manifest.packageId) `
        -ReportPath $reportPath *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    Require (Test-Path -LiteralPath $reportPath -PathType Leaf) "compatibility resolver did not produce a report"
    return [pscustomobject]@{ code = $code; report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json }
}

Require (Test-Path -LiteralPath $BuildPath -PathType Container) "SDK package build directory is missing"
Require (Test-Path -LiteralPath $ConsumerRoot -PathType Container) "independent Compatibility Consumer Mod is missing"
Require (Test-Path -LiteralPath $resolver -PathType Leaf) "public compatibility resolver is missing"
foreach ($name in @("package.artifact.json", "package-report.json", "build-report.json", "build-report.sha256", "fingerprint.sha256")) {
    Require (Test-Path -LiteralPath (Join-Path $BuildPath $name) -PathType Leaf) ("build output is missing: " + $name)
}

$buildReportPath = Join-Path $BuildPath "build-report.json"
$buildReport = Get-Content -Raw -LiteralPath $buildReportPath | ConvertFrom-Json
Require ((Sha256-File $buildReportPath) -eq (Get-Content -Raw -LiteralPath (Join-Path $BuildPath "build-report.sha256")).Trim().ToLowerInvariant()) "build report integrity mismatch"
$packageReport = Get-Content -Raw -LiteralPath (Join-Path $BuildPath "package-report.json") | ConvertFrom-Json
$artifactPath = Join-Path $BuildPath "package.artifact.json"
$artifactText = [IO.File]::ReadAllText($artifactPath)
$artifact = $artifactText | ConvertFrom-Json
$artifactHash = Sha256-File $artifactPath
Require ($artifactHash -eq [string]$buildReport.fingerprint -and $artifactHash -eq (Get-Content -Raw -LiteralPath (Join-Path $BuildPath "fingerprint.sha256")).Trim().ToLowerInvariant()) "package artifact integrity mismatch"
Require ([string]$artifact.schema -eq "cm2.package-artifact/1") "package artifact schema mismatch"
Require ([string]$artifact.manifest.entrypoints.runtime -eq "data-only" -and $null -eq $artifact.manifest.entrypoints.lua) "Consumer package is not data-only"

$validReportPath = Join-Path ([IO.Path]::GetTempPath()) ("cm2-compat-install-valid-" + [Guid]::NewGuid().ToString("N") + ".json")
$invalidReportPath = Join-Path ([IO.Path]::GetTempPath()) ("cm2-compat-install-invalid-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
    $validResolution = Invoke-Resolution $artifact.manifest $CoreApiVersion $SdkVersion $validReportPath
    Require ($validResolution.code -eq 0 -and [bool]$validResolution.report.compatible) ("selected package is incompatible: " + [string]$validResolution.report.code)
    Require ([string]$validResolution.report.policyHash -eq [string]$packageReport.compatibilityPolicyHash) "package report and resolver policy hashes differ"
    Require ([string]$validResolution.report.policyHash -eq [string]$buildReport.compatibilityPolicyHash) "build report and resolver policy hashes differ"
    $invalidResolution = Invoke-Resolution $artifact.manifest "2.0.0" $SdkVersion $invalidReportPath
    Require ($invalidResolution.code -ne 0 -and [string]$invalidResolution.report.code -eq "core-policy-version") "future Core rejection contract changed"

    $consumerHost = Join-Path $ConsumerRoot "script\testing\compatibility\consumer_host.lua"
    Require (Test-Path -LiteralPath $consumerHost -PathType Leaf) "Compatibility Consumer host is missing"
    $consumerSource = Get-Content -Raw -LiteralPath $consumerHost
    foreach ($forbidden in @("Content Mod 2", "Global Mod", "include(", "dofile(", "loadfile(")) {
        Require (-not $consumerSource.Contains($forbidden)) ("Consumer host contains a private loader reference: " + $forbidden)
    }

    $packageId = [string]$artifact.manifest.packageId
    $installRoot = Join-Path $ConsumerRoot ("packages\" + $packageId)
    $installedArtifact = Join-Path $installRoot "package.artifact.json"
    Write-TextAtomic $installedArtifact $artifactText
    Require ((Sha256-File $installedArtifact) -eq $artifactHash) "installed artifact hash mismatch"
    Require (@(Get-ChildItem -LiteralPath $installRoot -Recurse -File -Filter "*.lua").Count -eq 0) "installed package contains Runtime Lua"

    $validOperation = "accepted:core-1.2.0/sdk-1.0.0/package-1"
    $invalidOperation = "rejected:core-policy-version:2.0.0"
    $mainXml = @"
<scene version="2.0.1" shadowVolume="40 20 40">
    <environment template="sunny"/>
    <script file="MOD/script/testing/compatibility/consumer_host.lua" param0="packageId=$(Xml-Escape $packageId)" param1="packageHash=$(Xml-Escape $artifactHash)" param2="policyHash=$(Xml-Escape ([string]$validResolution.report.policyHash))" param3="validOperation=$(Xml-Escape $validOperation)" param4="invalidOperation=$(Xml-Escape $invalidOperation)" param5="installId=$(Xml-Escape $InstallId)"/>
    <body name="Compatibility Consumer Fixture Floor" dynamic="false" pos="0 -0.1 0">
        <voxbox size="20 1 20" material="masonry"/>
    </body>
    <location name="Player" tags="player" pos="0 1 4" rot="0 0 0"/>
</scene>
"@
    Write-TextAtomic (Join-Path $ConsumerRoot "main.xml") $mainXml

    $trace = [ordered]@{
        schema = "cm2.compatibility-consumer-install-trace/1"
        installId = $InstallId
        consumerMod = "_AI Test Consumer Compatibility V1"
        packageId = $packageId
        packageVersion = [string]$artifact.manifest.packageVersion
        packageArtifactHash = $artifactHash
        policyHash = [string]$validResolution.report.policyHash
        compatibleOperation = [ordered]@{ core = $CoreApiVersion; sdk = $SdkVersion; code = "pass"; result = "accepted" }
        incompatibleOperation = [ordered]@{ core = "2.0.0"; sdk = $SdkVersion; code = [string]$invalidResolution.report.code; result = "rejected" }
        installedArtifact = ("packages/" + $packageId + "/package.artifact.json")
        validOperation = $validOperation
        invalidOperation = $invalidOperation
        runtimeEntrypoint = "data-only"
        runtimeLuaLoaded = $false
        consumerPrivateIncludes = 0
        exactBuildIntegrity = $true
        lastValidOverwritePolicy = "resolve-before-write"
        install = "pass"
        result = "pass"
    }
    Write-TextAtomic $TracePath (Canonical-Json $trace)
    Write-Output (Canonical-Json $trace)
    Write-Host "Compatibility Consumer install passed: compatible package installed; future Core rejected before write." -ForegroundColor Green
}
finally {
    foreach ($temporary in @($validReportPath, $invalidReportPath)) {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
    }
}
exit 0
