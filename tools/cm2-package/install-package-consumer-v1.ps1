# Build/install the PackageManifest v1 artifact into the independent Teardown
# consumer fixture. The installed package contributes data and script params;
# it never supplies a Runtime Lua entrypoint.

param(
    [string]$FixturePath = "",
    [string]$ConsumerRoot = "",
    [string]$TracePath = "",
    [string]$ValidCapability = "Ship",
    [string]$InvalidCapability = "ExecuteLua",
    [string]$BuildId = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\package-manifest-v1.fixture.json" }
if ($ConsumerRoot -eq "") { $ConsumerRoot = Join-Path $root "_AI Test Consumer Basic" }
if ($TracePath -eq "") { $TracePath = Join-Path $root "docs\candidates\package-manifest-v1.consumer-trace.json" }
if ($BuildId -eq "") { $BuildId = "package-consumer-build-v1" }
$utf8 = New-Object Text.UTF8Encoding($false)
$runner = Join-Path $PSScriptRoot "run-package-manifest-v1.ps1"
$approved = @("Ship", "Mount", "Turret", "Weapon", "Projectile", "Effect", "Localization", "Assets")

function Fail([string]$message) { throw ("Package consumer install failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-TextAtomic([string]$path, [string]$text) {
    $full = [IO.Path]::GetFullPath($path)
    $parent = Split-Path -Parent $full
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = $full + ".tmp." + [Guid]::NewGuid().ToString("N")
    try {
        [IO.File]::WriteAllText($temporary, $text, $utf8)
        Move-Item -LiteralPath $temporary -Destination $full -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
    }
}
function Write-Json([string]$path, [object]$value) { Write-TextAtomic $path (Canonical-Json $value) }
function Xml-Escape([string]$value) { return [Security.SecurityElement]::Escape($value) }

Require (Test-Path -LiteralPath $FixturePath -PathType Leaf) "fixture is missing"
Require (Test-Path -LiteralPath $ConsumerRoot -PathType Container) "independent consumer Mod is missing"
$consumerHost = Join-Path $ConsumerRoot "script\testing\package_manifest\consumer_host.lua"
Require (Test-Path -LiteralPath $consumerHost -PathType Leaf) "consumer host is missing"
$consumerSource = Get-Content -Raw -LiteralPath $consumerHost
foreach ($forbidden in @("Content Mod 2", "Global Mod", "include(", "dofile(", "loadfile(")) {
    Require (-not $consumerSource.Contains($forbidden)) ("consumer host contains a private/runtime loader reference: " + $forbidden)
}

$stageRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-package-consumer-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
try {
    $stageReport = Join-Path $stageRoot "package.report.json"
    $stageArtifact = Join-Path $stageRoot "package.artifact.json"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -FixturePath $FixturePath -ReportPath $stageReport -ArtifactPath $stageArtifact *> $null
    Require ($LASTEXITCODE -eq 0) "PackageManifest validator rejected the clean-room fixture"
    $report = Get-Content -Raw -LiteralPath $stageReport | ConvertFrom-Json
    $artifact = Get-Content -Raw -LiteralPath $stageArtifact | ConvertFrom-Json
    Require ([string]$artifact.schema -eq "cm2.package-artifact/1") "artifact schema mismatch"
    Require ([string]$artifact.manifest.entrypoints.runtime -eq "data-only" -and $null -eq $artifact.manifest.entrypoints.lua) "artifact attempts to install Runtime Lua"
    Require ($ValidCapability -in @($artifact.manifest.capabilities) -and $ValidCapability -in $approved) "valid public capability was not accepted"
    Require ($InvalidCapability -notin $approved) "invalid capability probe was unexpectedly approved"

    $installRoot = Join-Path $ConsumerRoot "packages\cm2.thirdparty.hello-ship"
    $installedArtifact = Join-Path $installRoot "package.artifact.json"
    Write-TextAtomic $installedArtifact ([IO.File]::ReadAllText($stageArtifact))
    Require ((Get-FileHash -Algorithm SHA256 -LiteralPath $installedArtifact).Hash.ToLowerInvariant() -eq [string]$report.packageArtifactHash) "installed artifact hash mismatch"
    Require (@(Get-ChildItem -LiteralPath $installRoot -Recurse -File -Filter "*.lua").Count -eq 0) "installed data package contains Runtime Lua"

    $validOperation = "accepted:" + $ValidCapability
    $invalidOperation = "rejected:unknown-capability:" + $InvalidCapability
    $mainXml = @"
<scene version="2.0.1" shadowVolume="40 20 40">
    <environment template="sunny"/>
    <script file="MOD/script/testing/package_manifest/consumer_host.lua" param0="packageId=$(Xml-Escape ([string]$report.packageId))" param1="packageVersion=$(Xml-Escape ([string]$report.packageVersion))" param2="packageHash=$(Xml-Escape ([string]$report.packageArtifactHash))" param3="validOperation=$(Xml-Escape $validOperation)" param4="invalidOperation=$(Xml-Escape $invalidOperation)" param5="buildId=$(Xml-Escape $BuildId)"/>
    <body name="Consumer Fixture Floor" dynamic="false" pos="0 -0.1 0">
        <voxbox size="20 1 20" material="masonry"/>
    </body>
    <location name="Player" tags="player" pos="0 1 4" rot="0 0 0"/>
</scene>
"@
    Write-TextAtomic (Join-Path $ConsumerRoot "main.xml") $mainXml

    $trace = [ordered]@{
        schema = "cm2.package-consumer-install-trace/1"
        buildId = $BuildId
        consumerMod = "_AI Test Consumer Basic"
        packageId = [string]$report.packageId
        packageVersion = [string]$report.packageVersion
        packageArtifactHash = [string]$report.packageArtifactHash
        installedArtifact = "packages/cm2.thirdparty.hello-ship/package.artifact.json"
        validOperation = $validOperation
        invalidOperation = $invalidOperation
        runtimeEntrypoint = "data-only"
        runtimeLuaLoaded = $false
        consumerPrivateIncludes = 0
        install = "pass"
        result = "pass"
    }
    Write-Json $TracePath $trace
    Write-Output (Canonical-Json $trace)
}
finally {
    if (Test-Path -LiteralPath $stageRoot -PathType Container) { Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Package consumer install passed: valid capability accepted, unknown capability rejected, no Runtime Lua installed." -ForegroundColor Green
exit 0
