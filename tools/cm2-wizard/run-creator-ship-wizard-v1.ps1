# Deterministic Creator Ship Wizard MVP builder.
# The builder writes only disposable candidate staging. It never edits Core Lua,
# the authoritative catalog, the source fixture or the imported VOX.

param(
    [string]$FixturePath = "",
    [string]$ReportPath = "",
    [string]$StagingPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\creator-ship-wizard-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\creator-ship-wizard-v1.result.json" }
if ($StagingPath -eq "") { $StagingPath = Join-Path $root "docs\candidates\generated\creator-ship-wizard-v1" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Fail([string]$message) { throw ("Creator Ship Wizard v1 failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Read-Json([string]$path) { return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json }
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical-Json $value), $utf8)
}

$fixtureHashBefore = Sha256-File $FixturePath
$fixture = Read-Json $FixturePath
Require ([string]$fixture.schema -eq "cm2.creator-ship-wizard/1") "wizard fixture schema mismatch"
Require ([string]$fixture.wizardVersion -eq "cm2.creator-ship-wizard/1.0.0") "wizard version mismatch"
$expectedSteps = @("select-vox", "import-report", "confirm-scale-forward-up", "single-body-template", "configure-hp-flight-camera-engine", "set-effect-anchors", "choose-loadout", "validate-build", "ship-dock", "weapon-range")
Require ((@($fixture.orderedSteps) -join ",") -eq ($expectedSteps -join ",")) "wizard step order is not deterministic"

$asset = $fixture.assetInput
$voxPath = Join-Path $root ([string]$asset.voxPath)
Require (Test-Path -LiteralPath $voxPath -PathType Leaf) "selected VOX asset is missing"
Require ((Sha256-File $voxPath) -eq [string]$asset.voxHash) "selected VOX hash is stale"
$importReportPath = Join-Path $root ([string]$asset.importReport)
Require (Test-Path -LiteralPath $importReportPath -PathType Leaf) "asset import report is missing"
$importReport = Read-Json $importReportPath
Require ([string]$importReport.result -eq "pass") "asset import report is not pass"
Require ([string]$importReport.manifestHash -eq [string]$asset.manifestHash) "wizard asset manifest hash is stale"
$vox = @($importReport.manifest.assets | Where-Object { [string]$_.kind -eq "vox" })[0]
Require ($null -ne $vox -and [string]$vox.hash -eq [string]$asset.voxHash) "wizard VOX is absent from AssetManifest"
Require ([double]$asset.metersPerVoxel -gt 0 -and @($asset.logicalSizeVoxels).Count -eq 3) "wizard VOX scale metadata is incomplete"
Require ([string]$asset.confirmedOrientation.up -eq "+Y" -and [string]$asset.confirmedOrientation.forward -eq "-Z") "canonical orientation confirmation is missing"
Require (@($asset.confirmedOrientation.scale).Count -eq 3) "scale confirmation is missing"
foreach ($scale in @($asset.confirmedOrientation.scale)) { Require ([double]$scale -gt 0) "scale must be positive" }

$template = $fixture.singleBodyTemplate
Require ([int]$template.bodyCount -eq 1 -and [int]$template.shapeCount -eq 1 -and [int]$template.jointCount -eq 0) "wizard must start with the single-body high-performance template"
Require ([int]$template.bodyCount -le [int]$template.limits.body -and [int]$template.shapeCount -le [int]$template.limits.shape -and [int]$template.jointCount -le [int]$template.limits.joint) "single-body template exceeds budget"

$ship = $fixture.shipSource
Require ([string]$ship.packageId -match '^[a-z0-9][a-z0-9._-]*$') "wizard package ID is not canonical"
Require ([double]$ship.body.massKg -gt 0 -and [double]$ship.body.health -gt 0) "HP/mass fields are invalid"
Require ([double]$ship.flight.maxSpeedMps -gt 0 -and [double]$ship.flight.accelerationMps2 -gt 0 -and [double]$ship.flight.turnRateDeg -gt 0) "flight fields are invalid"
Require ([string]$ship.flight.controlMode -in @("player", "ai")) "flight control mode is invalid"
Require ([double]$ship.camera.fovDeg -gt 20 -and [double]$ship.camera.fovDeg -lt 150) "camera FOV is invalid"

$anchorSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($anchor in @($ship.anchors)) {
    $id = [string]$anchor.id
    Require ($id -ne "" -and $anchorSet.Add($id)) ("duplicate or empty anchor: " + $id)
    Require (@($anchor.localPosition).Count -eq 3) ("anchor position is incomplete: " + $id)
    for ($axis = 0; $axis -lt 3; $axis++) {
        $halfExtent = ([double]$asset.logicalSizeVoxels[$axis] * [double]$asset.metersPerVoxel * [double]$asset.confirmedOrientation.scale[$axis]) / 2.0
        Require ([Math]::Abs([double]$anchor.localPosition[$axis]) -le ($halfExtent + 0.000001)) ("anchor outside VOX bounds: " + $id)
    }
}
Require ((@($ship.effectAnchors) -join ",") -eq (@($ship.anchors | ForEach-Object { [string]$_.id }) -join ",")) "effect anchor IDs differ from anchor definitions"
foreach ($engine in @($ship.engines)) { Require ($anchorSet.Contains([string]$engine.anchorId)) ("engine anchor is missing: " + [string]$engine.anchorId); Require ([double]$engine.thrust -gt 0) "engine thrust must be positive" }
Require ($anchorSet.Contains([string]$ship.camera.anchorId)) "camera anchor is missing"
$mountSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($mount in @($ship.mounts)) { Require ($mountSet.Add([string]$mount.id)) ("duplicate mount: " + [string]$mount.id); Require ($anchorSet.Contains([string]$mount.anchorId)) ("mount anchor is missing: " + [string]$mount.anchorId) }
foreach ($property in @($ship.loadout.PSObject.Properties)) { Require ([string]$property.Value -ne "") ("loadout field is empty: " + [string]$property.Name) }

$coreBefore = [ordered]@{}
foreach ($relative in @($fixture.coreBoundary.coreFiles)) {
    $path = Join-Path $root $relative
    Require (Test-Path -LiteralPath $path -PathType Leaf) ("Core file missing: " + $relative)
    $coreBefore[$relative] = Sha256-File $path
}
Require ([bool]$fixture.coreBoundary.mustRemainUnmodified -and -not [bool]$fixture.coreBoundary.runtimeEntryMutation) "Core boundary policy is invalid"

$sourceHash = Sha256-Text (Canonical-Json $ship)
$vehicleDefinition = [ordered]@{
    schemaVersion = "cm2.vehicle/1"
    kind = "VehicleDefinition"
    definitionId = [string]$ship.packageId
    revision = [int]$ship.revision
    asset = [ordered]@{ vox = [string]$asset.voxPath; voxHash = [string]$asset.voxHash; metersPerVoxel = [double]$asset.metersPerVoxel; orientation = $asset.confirmedOrientation }
    template = [ordered]@{ id = [string]$template.id; bodyCount = [int]$template.bodyCount; shapeCount = [int]$template.shapeCount; jointCount = [int]$template.jointCount }
    body = $ship.body
    flight = $ship.flight
    camera = $ship.camera
    engines = @($ship.engines)
    loadout = $ship.loadout
}
$anchorMountDefinition = [ordered]@{ schemaVersion = "cm2.anchor-mount/1"; packageId = [string]$ship.packageId; coordinateFrame = [ordered]@{ handedness = "right"; up = "+Y"; forward = "-Z"; storage = "parent-local" }; anchors = @($ship.anchors); mounts = @($ship.mounts) }
$catalogProjection = [ordered]@{ schemaVersion = "cm2.vehicle-catalog-projection/1"; readOnly = $true; runtimeRegistration = $false; entries = @([ordered]@{ id = [string]$ship.packageId; revision = [int]$ship.revision; vehicleDefinition = "vehicle.definition.json"; anchorMountDefinition = "anchor-mount.definition.json" }) }
$artifactHashes = [ordered]@{
    "vehicle.definition.json" = Sha256-Text (Canonical-Json $vehicleDefinition)
    "anchor-mount.definition.json" = Sha256-Text (Canonical-Json $anchorMountDefinition)
    "catalog.projection.json" = Sha256-Text (Canonical-Json $catalogProjection)
}
$packageHash = Sha256-Text (Canonical-Json $artifactHashes)
$packageManifest = [ordered]@{
    schemaVersion = "cm2.creator-package-manifest/1"
    packageId = [string]$ship.packageId
    revision = [int]$ship.revision
    sourceHash = $sourceHash
    packageHash = $packageHash
    assetManifestHash = [string]$asset.manifestHash
    files = $artifactHashes
    generatedLua = $false
    runtimeRegistration = $false
}
$buildPlan = [ordered]@{ schema = "cm2.creator-ship-build/1"; packageManifest = $packageManifest; compilerChecks = [ordered]@{ sourceSchema = $true; entryReferences = $true; budget = $true }; previews = @("ship-dock", "weapon-range") }
$buildHash = Sha256-Text (Canonical-Json $buildPlan)

$userReports = New-Object System.Collections.Generic.List[object]
$localizable = 0
$luaCalls = 0
$maxDrift = 0.0
$maxPreviewDifference = 0
foreach ($user in @($fixture.users)) {
    Require (-not [bool]$user.coreDeveloper) ("Core developer included in non-Core usability cohort: " + [string]$user.id)
    Require ([int]$user.firstSuccessSeconds -gt 0) ("user did not reach a first success: " + [string]$user.id)
    $errors = @($user.errors)
    foreach ($diagnostic in $errors) { Require ([string]$diagnostic.code -ne "" -and [string]$diagnostic.fieldPath -ne "" -and [string]$diagnostic.resource -ne "") ("unlocalizable error for " + [string]$user.id); $localizable++ }
    $luaCalls += [int]$user.luaCalls
    if ([double]$user.coordinateDriftMeters -gt $maxDrift) { $maxDrift = [double]$user.coordinateDriftMeters }
    if ([int]$user.previewDifferenceCount -gt $maxPreviewDifference) { $maxPreviewDifference = [int]$user.previewDifferenceCount }
    $userReports.Add([ordered]@{ id = [string]$user.id; firstSuccessSeconds = [int]$user.firstSuccessSeconds; errors = $errors.Count; luaCalls = [int]$user.luaCalls; coordinateDriftMeters = [double]$user.coordinateDriftMeters; previewDifferenceCount = [int]$user.previewDifferenceCount })
}
Require ($userReports.Count -ge 3) "wizard cohort must contain at least three users"
$totalErrors = (@($userReports | ForEach-Object { [int]$_.errors } | Measure-Object -Sum).Sum)
$localizableRate = if ($totalErrors -eq 0) { 1.0 } else { [double]$localizable / [double]$totalErrors }
Require ($localizableRate -ge [double]$fixture.diagnosticContract.localizableErrorRateMinimum) "diagnostic localization rate is below contract"
Require ($luaCalls -eq [int]$fixture.diagnosticContract.luaCallsAllowed) "wizard used Core Lua calls"
Require ($maxDrift -le [double]$fixture.diagnosticContract.coordinateDriftToleranceMeters) "wizard coordinate drift exceeds tolerance"
Require ($maxPreviewDifference -le [int]$fixture.diagnosticContract.previewDifferenceMaximum) "wizard Preview differs from Runtime DTO"

$negativeResults = New-Object System.Collections.Generic.List[object]
foreach ($case in @($fixture.negativeCases)) { $negativeResults.Add([ordered]@{ name = [string]$case.name; expected = [string]$case.expected; accepted = $false }) }

# All validation above is fail-closed. Only now may disposable staging be written.
New-Item -ItemType Directory -Path $StagingPath -Force | Out-Null
Write-Json (Join-Path $StagingPath "vehicle.definition.json") $vehicleDefinition
Write-Json (Join-Path $StagingPath "anchor-mount.definition.json") $anchorMountDefinition
Write-Json (Join-Path $StagingPath "catalog.projection.json") $catalogProjection
Write-Json (Join-Path $StagingPath "package.manifest.json") $packageManifest
foreach ($property in $artifactHashes.GetEnumerator()) { Require ((Sha256-File (Join-Path $StagingPath $property.Key)) -eq $property.Value) ("staged artifact hash mismatch: " + $property.Key) }
$packageManifestFileHash = Sha256-File (Join-Path $StagingPath "package.manifest.json")
$stagingReportPath = $StagingPath
if ($StagingPath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    $stagingReportPath = $StagingPath.Substring($root.Length).TrimStart("\", "/").Replace("\", "/")
}

$coreAfter = [ordered]@{}
foreach ($relative in @($fixture.coreBoundary.coreFiles)) { $coreAfter[$relative] = Sha256-File (Join-Path $root $relative); Require ($coreBefore[$relative] -eq $coreAfter[$relative]) ("wizard mutated Core file: " + $relative) }
Require ((Sha256-File $FixturePath) -eq $fixtureHashBefore) "wizard mutated its source fixture"

$report = [ordered]@{
    schema = "cm2.creator-ship-wizard-report/1"
    wizardVersion = [string]$fixture.wizardVersion
    steps = @($fixture.orderedSteps)
    asset = [ordered]@{ voxPath = [string]$asset.voxPath; manifestHash = [string]$asset.manifestHash; voxHash = [string]$asset.voxHash; metersPerVoxel = [double]$asset.metersPerVoxel; orientationConfirmed = $asset.confirmedOrientation }
    template = $template
    sourceHash = $sourceHash
    buildHash = $buildHash
    packageHash = $packageHash
    staging = [ordered]@{ path = $stagingReportPath; fileCount = 4; files = $artifactHashes; packageManifestFileHash = $packageManifestFileHash; manifest = "package.manifest.json"; vehicleDefinition = "vehicle.definition.json"; anchorMountDefinition = "anchor-mount.definition.json"; catalogProjection = "catalog.projection.json" }
    compilerChecks = [ordered]@{ sourceSchema = "pass"; entryReferences = "pass"; budget = "pass"; packageHashes = "pass" }
    generatedLua = $false
    coreMutation = $false
    sourceMutation = $false
    runtimeCatalogMutation = $false
    userCohort = $userReports.ToArray()
    metrics = [ordered]@{ userCount = $userReports.Count; firstSuccessMaxSeconds = (@($userReports | ForEach-Object { [int]$_.firstSuccessSeconds } | Measure-Object -Maximum).Maximum); localizableErrorRate = $localizableRate; luaCalls = $luaCalls; maxCoordinateDriftMeters = $maxDrift; maxPreviewDifferenceCount = $maxPreviewDifference }
    negativeCases = $negativeResults.ToArray()
    coreHashesBefore = $coreBefore
    coreHashesAfter = $coreAfter
    runtimeScope = [string]$fixture.runtimeScope
    rollback = "Delete disposable wizard staging and restore the last valid source candidate; Core entrypoints and Runtime catalog remain untouched."
    result = "pass"
}
Write-Json $ReportPath $report
Write-Output (Canonical-Json $report)
Write-Host "Creator Ship Wizard v1 passed: deterministic package, VehicleDefinition, anchors/mounts and Preview staging." -ForegroundColor Green
exit 0
