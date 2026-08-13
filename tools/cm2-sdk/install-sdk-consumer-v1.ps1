# Install an exact Creator SDK build into an independent Teardown Consumer Mod.
# The Consumer receives only the data package and immutable metadata params.

param(
    [string]$BuildPath = "",
    [string]$ConsumerRoot = "",
    [string]$TracePath = "",
    [string]$BuildId = "sdk-cli-alpha-build-v1"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($BuildPath -eq "") { $BuildPath = Join-Path $root "testing\fixtures\creator_sdk\alpha_project\.cm2-sdk\package" }
if ($ConsumerRoot -eq "") { $ConsumerRoot = Join-Path $root "_AI Test Consumer SDK Alpha" }
if ($TracePath -eq "") { $TracePath = Join-Path $root "docs\candidates\sdk-cli-v1.consumer-trace.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Fail([string]$message) { throw ("Creator SDK Consumer install failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-TextAtomic([string]$path, [string]$text) {
    $full = [IO.Path]::GetFullPath($path)
    $parent = Split-Path -Parent $full
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = $full + ".tmp." + [Guid]::NewGuid().ToString("N")
    try { [IO.File]::WriteAllText($temporary, $text, $utf8); Move-Item -LiteralPath $temporary -Destination $full -Force }
    finally { if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue } }
}
function Write-Json([string]$path, [object]$value) { Write-TextAtomic $path (Canonical-Json $value) }
function Xml-Escape([string]$value) { return [Security.SecurityElement]::Escape($value) }

Require (Test-Path -LiteralPath $BuildPath -PathType Container) "SDK package build directory is missing"
Require (Test-Path -LiteralPath $ConsumerRoot -PathType Container) "independent SDK Consumer Mod is missing"
$requiredFiles = @("package.artifact.json", "build-report.json", "build-report.sha256", "compiler-manifest.json", "compiler-report.json", "fingerprint.sha256")
foreach ($name in $requiredFiles) { Require (Test-Path -LiteralPath (Join-Path $BuildPath $name) -PathType Leaf) ("SDK build output is missing: " + $name) }

$buildReportPath = Join-Path $BuildPath "build-report.json"
$buildReport = Get-Content -Raw -LiteralPath $buildReportPath | ConvertFrom-Json
$buildReportHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $buildReportPath).Hash.ToLowerInvariant()
$expectedBuildReportHash = (Get-Content -Raw -LiteralPath (Join-Path $BuildPath "build-report.sha256")).Trim().ToLowerInvariant()
Require ($buildReportHash -eq $expectedBuildReportHash) "SDK build report integrity mismatch"
Require ([string]$buildReport.schema -eq "cm2.sdk-build-report/1" -and [string]$buildReport.result -eq "pass") "SDK build report is not a passing Alpha build"
Require ([string]$buildReport.compilerMode -eq "shared-compiler" -and [int]$buildReport.definitionCount -eq 5) "SDK build did not use the shared Compiler over Hello Ship"
Require (-not [bool]$buildReport.runtimeLua) "SDK build attempts to publish Runtime Lua"

$artifactPath = Join-Path $BuildPath "package.artifact.json"
$artifactText = [IO.File]::ReadAllText($artifactPath)
$artifact = $artifactText | ConvertFrom-Json
$artifactHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash.ToLowerInvariant()
Require ($artifactHash -eq [string]$buildReport.fingerprint) "SDK package artifact does not match its build fingerprint"
Require ($artifactHash -eq (Get-Content -Raw -LiteralPath (Join-Path $BuildPath "fingerprint.sha256")).Trim().ToLowerInvariant()) "SDK fingerprint companion mismatch"
Require ([string]$artifact.schema -eq "cm2.package-artifact/1") "SDK package artifact schema mismatch"
Require ([string]$artifact.manifest.entrypoints.runtime -eq "data-only" -and $null -eq $artifact.manifest.entrypoints.lua) "SDK artifact supplies a Runtime Lua entrypoint"
Require ("Ship" -in @($artifact.manifest.capabilities)) "SDK artifact does not expose the valid Ship capability"
Require ("ExecuteLua" -notin @($artifact.manifest.capabilities)) "SDK artifact unexpectedly exposes ExecuteLua"

$consumerHost = Join-Path $ConsumerRoot "script\testing\sdk_cli\consumer_host.lua"
Require (Test-Path -LiteralPath $consumerHost -PathType Leaf) "SDK Consumer host is missing"
$consumerSource = Get-Content -Raw -LiteralPath $consumerHost
foreach ($forbidden in @("Content Mod 2", "Global Mod", "include(", "dofile(", "loadfile(")) { Require (-not $consumerSource.Contains($forbidden)) ("Consumer host contains a private/runtime loader reference: " + $forbidden) }

$packageId = [string]$artifact.manifest.packageId
$installRoot = Join-Path $ConsumerRoot ("packages\" + $packageId)
$installedArtifact = Join-Path $installRoot "package.artifact.json"
Write-TextAtomic $installedArtifact $artifactText
Require ((Get-FileHash -Algorithm SHA256 -LiteralPath $installedArtifact).Hash.ToLowerInvariant() -eq $artifactHash) "installed SDK artifact hash mismatch"
Require (@(Get-ChildItem -LiteralPath $installRoot -Recurse -File -Filter "*.lua").Count -eq 0) "installed SDK package contains Runtime Lua"

$validOperation = "accepted:Ship"
$invalidOperation = "rejected:unknown-capability:ExecuteLua"
$mainXml = @"
<scene version="2.0.1" shadowVolume="40 20 40">
    <environment template="sunny"/>
    <script file="MOD/script/testing/sdk_cli/consumer_host.lua" param0="packageId=$(Xml-Escape $packageId)" param1="packageVersion=$(Xml-Escape ([string]$artifact.manifest.packageVersion))" param2="packageHash=$(Xml-Escape $artifactHash)" param3="validOperation=$(Xml-Escape $validOperation)" param4="invalidOperation=$(Xml-Escape $invalidOperation)" param5="buildId=$(Xml-Escape $BuildId)" param6="compilerHash=$(Xml-Escape ([string]$buildReport.compilerCatalogHash))"/>
    <body name="SDK Consumer Fixture Floor" dynamic="false" pos="0 -0.1 0">
        <voxbox size="20 1 20" material="masonry"/>
    </body>
    <location name="Player" tags="player" pos="0 1 4" rot="0 0 0"/>
</scene>
"@
Write-TextAtomic (Join-Path $ConsumerRoot "main.xml") $mainXml

$trace = [ordered]@{
    schema="cm2.sdk-consumer-install-trace/1"; buildId=$BuildId; consumerMod="_AI Test Consumer SDK Alpha"
    packageId=$packageId; packageVersion=[string]$artifact.manifest.packageVersion; packageArtifactHash=$artifactHash
    compilerCatalogHash=[string]$buildReport.compilerCatalogHash; compilerMode=[string]$buildReport.compilerMode; definitionCount=[int]$buildReport.definitionCount
    installedArtifact=("packages/" + $packageId + "/package.artifact.json"); validOperation=$validOperation; invalidOperation=$invalidOperation
    runtimeEntrypoint="data-only"; runtimeLuaLoaded=$false; consumerPrivateIncludes=0; exactBuildIntegrity=$true; install="pass"; result="pass"
}
Write-Json $TracePath $trace
Write-Output (Canonical-Json $trace)
Write-Host "Creator SDK Consumer install passed: exact data-only package installed; Ship accepted; ExecuteLua rejected." -ForegroundColor Green
exit 0
