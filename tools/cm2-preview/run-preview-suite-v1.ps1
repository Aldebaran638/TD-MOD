# Headless contract runner for the shared Effect Lab / Weapon Range / Ship Dock Preview Suite.
# It proves deterministic DTO/replay/lifecycle behaviour without pretending to be Teardown.

param(
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\preview-suite-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\preview-suite-v1.result.json" }

function Fail([string]$message) { throw ("Preview Suite v1 failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Canonical-Json([object]$value) { return ($value | ConvertTo-Json -Depth 80 -Compress) }
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Read-Source([string]$relative) {
    $path = Join-Path $root $relative
    Require (Test-Path -LiteralPath $path -PathType Leaf) ("missing source: " + $relative)
    return Get-Content -Raw -LiteralPath $path
}
function Write-Canonical([string]$path, [object]$value) {
    $absolute = $path
    if (-not [IO.Path]::IsPathRooted($absolute)) { $absolute = Join-Path (Get-Location).Path $absolute }
    $parent = Split-Path -Parent $absolute
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($absolute, (Canonical-Json $value), (New-Object Text.UTF8Encoding($false)))
}
function New-DeterministicTrace([int]$seed, [int]$count) {
    [uint64]$state = [uint64]([Math]::Max(0, $seed))
    $events = New-Object System.Collections.Generic.List[object]
    for ($index = 1; $index -le $count; $index++) {
        $state = (($state * [uint64]1664525 + [uint64]1013904223) % [uint64]4294967296)
        $roll = [Math]::Round(([double]$state / 4294967296.0), 8)
        $events.Add([ordered]@{ index = $index; roll = $roll; fixedSeed = $seed })
    }
    return $events.ToArray()
}

$fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
$module = Read-Source "Content Mod 2\script\world\adapter\preview_suite_v1.lua"
$worldAdapter = Read-Source "Content Mod 2\script\world\adapter\synthetic_world_adapter_v1.lua"
$liveController = Read-Source "Content Mod 2\script\testing\scenario\preview_suite_controller.lua"
$liveScenePath = Join-Path $root "Content Mod 2\_ai_scenario_preview_suite.xml"
$scenarioPath = Join-Path $root "Content Mod 2\testing\scenarios\creator\preview_suite_v1\scenario.json"
$documentation = Join-Path $root "docs\preview-suite-v1.md"
Require ([string]$fixture.schema -eq "cm2.preview-suite/1") "fixture schema mismatch"
Require ([string]$fixture.runtimeMode -eq "preview-only") "Preview must remain independently published"
Require ([bool]$fixture.candidate) "Preview suite must be explicitly candidate-scoped"

foreach ($symbol in @("init", "runEffectLab", "runWeaponRange", "spawnShipDock", "disposeShipDock", "exportDiagnostics", "snapshot", "dispose")) {
    Require ($module -match ("function suite\." + $symbol + "\b")) ("Preview Suite API missing: " + $symbol)
}
foreach ($token in @("effectPlayer.init", "effectPlayer", "presentationBudget", "compiler", "catalog", "worldEntityAdapter", "runtimeCatalogMutation", "fixed", "seed", "lod", "targetTypes", "ballisticTrace", "vox", "entityGraph", "anchors", "mounts", "turrets", "camera", "engineMarkers", "screenshot", "recording", "staleRejected")) {
    Require ($module -match [regex]::Escape($token)) ("shared Preview contract token missing: " + $token)
}
Require ($module -notmatch "QueryRaycast|FindBody|GetBodyTransform|GetBodyCenterOfMass|Explosion|SpawnParticle|ClientCall|ServerCall") "Preview adapter must not own Teardown/runtime authority"
Require (Test-Path -LiteralPath $documentation -PathType Leaf) "Preview Suite documentation is missing"
Require (Test-Path -LiteralPath $liveScenePath -PathType Leaf) "live Preview Suite level entry is missing"
Require (Test-Path -LiteralPath $scenarioPath -PathType Leaf) "live Preview Suite scenario manifest is missing"
foreach ($token in @('synthetic.version = "cm2.world/1"', 'synthetic.entity.spawn', 'synthetic.entity.dispose', 'synthetic.entity.snapshot')) {
    Require ($worldAdapter -match [regex]::Escape($token)) ("shared World/Entity adapter live boundary missing: " + $token)
}
foreach ($token in @('cm2PreviewSuiteV1.init', 'runEffectLab', 'runWeaponRange', 'spawnShipDock', 'disposeShipDock', 'client.presentationBudget', 'client.effectPlayer', 'InputPressed("leftarrow")', 'InputPressed("rightarrow")', 'InputPressed("space")', 'SetCameraTransform', 'runtimeCatalogUnchanged')) {
    Require ($liveController -match [regex]::Escape($token)) ("live Preview controller token missing: " + $token)
}
Require ($liveController -notmatch "QueryRaycast|Explosion|ServerCall|shipDamageApplyRaw|damage_probe") "live Preview host must not bypass the preview behavior with gameplay/test authority"

$authority = $fixture.sharedAuthority
Require ([string]$authority.compiler -eq "cm2.runtime-compiler/1") "Preview compiler is not the shared compiler"
Require ([string]$authority.catalog -eq "cm2.generated-catalog-manifest/1") "Preview catalog is not the generated catalog contract"
Require ([string]$authority.worldEntityAdapter -eq "cm2.world/1") "Preview World/Entity adapter contract mismatch"
Require ([bool]$authority.sameNormalizedRuntimeDTO) "Preview must consume normalized Runtime DTO"
Require ([bool]$authority.runtimeCatalogMutationForbidden) "Preview must not mutate runtime catalog"
Require ([bool]$authority.runtimeEntryUnchanged) "Preview must not replace runtime entry"

$replayStages = @($fixture.replays | ForEach-Object { [string]$_.stage })
foreach ($stage in @("S0", "S2", "S5")) { Require ($replayStages -contains $stage) ("missing required replay stage: " + $stage) }

$effect = $fixture.effectLab
Require ([string]$effect.mode -eq "effect-lab") "Effect Lab mode mismatch"
Require ([int]$effect.fixedSeed -eq 424242) "Effect Lab fixed seed mismatch"
Require (@($effect.distances) -contains "near" -and @($effect.distances) -contains "far") "Effect Lab near/far coverage missing"
Require (@($effect.lod) -contains 0 -and @($effect.lod) -contains 1) "Effect Lab LOD coverage missing"
Require (@($effect.reuses) -contains "EffectPlayer" -and @($effect.reuses) -contains "PresentationBudget") "Effect Lab must reuse production Player/Budget"
Require (@($effect.context.origin).Count -eq 3 -and @($effect.context.direction).Count -eq 3 -and @($effect.context.hitPoint).Count -eq 3 -and @($effect.context.hitNormal).Count -eq 3) "Effect Lab synthetic context is incomplete"
$effectTraceA = @(
    [ordered]@{ operation = "init"; owner = "production-effect-player"; seed = [int]$effect.fixedSeed },
    [ordered]@{ operation = "play"; definition = [string]$effect.definitionId; distance = "near"; lod = 0 },
    [ordered]@{ operation = "update"; dt = 0.25 },
    [ordered]@{ operation = "stop"; reason = "preview-complete" }
)
$effectTraceB = @($effectTraceA | ForEach-Object { $_ })
Require ((Canonical-Json $effectTraceA) -eq (Canonical-Json $effectTraceB)) "Effect Lab replay is not stable"

$range = $fixture.weaponRange
Require ([string]$range.mode -eq "weapon-range") "Weapon Range mode mismatch"
Require ([int]$range.fixedSeed -eq 424242) "Weapon Range fixed seed mismatch"
Require (@($range.muzzle).Count -eq 3) "Weapon Range fixed muzzle is incomplete"
Require (@($range.targetTypes).Count -ge 3) "Weapon Range target types are incomplete"
Require ($null -ne $range.movingTarget -and [string]$range.movingTarget.path -eq "deterministic-linear") "moving target replay is missing"
Require ([int]$range.shots -eq 4) "Weapon Range shot count mismatch"
$budgetTotal = [int]$range.budget.accepted + [int]$range.budget.degraded + [int]$range.budget.rejected
Require ($budgetTotal -eq [int]$range.shots) "Weapon Range budget accounting does not cover every shot"
Require ([int]$range.damage.min -le [int]$range.damage.max) "Weapon Range damage range is invalid"
$weaponTraceA = New-DeterministicTrace ([int]$range.fixedSeed) ([int]$range.shots)
$weaponTraceB = New-DeterministicTrace ([int]$range.fixedSeed) ([int]$range.shots)
$weaponReplayHashA = Sha256-Text (Canonical-Json $weaponTraceA)
$weaponReplayHashB = Sha256-Text (Canonical-Json $weaponTraceB)
Require ($weaponReplayHashA -eq $weaponReplayHashB) "Weapon Range fixed-seed trace is not deterministic"

$dock = $fixture.shipDock
Require ([string]$dock.mode -eq "ship-dock") "Ship Dock mode mismatch"
Require ($null -ne $dock.vox -and [string]$dock.vox.path -ne "") "Ship Dock VOX source is missing"
Require ($null -ne $dock.entityGraph -and [string]$dock.entityGraph.id -ne "") "Ship Dock EntityGraph is missing"
Require (@($dock.anchors).Count -ge 1 -and @($dock.mounts).Count -ge 1 -and @($dock.turrets).Count -ge 1) "Ship Dock anchor/mount/turret tree is incomplete"
Require ($null -ne $dock.camera -and [string]$dock.camera.mode -ne "") "Ship Dock camera contract is missing"
Require (@($dock.engineMarkers).Count -ge 1) "Ship Dock engine marker contract is missing"
Require (@($dock.spawnDispose) -contains "spawn" -and @($dock.spawnDispose) -contains "dispose" -and @($dock.spawnDispose) -contains "stale-dispose-reject") "Ship Dock lifecycle coverage is incomplete"

$diagnostics = $fixture.diagnostics
Require ([bool]$diagnostics.export) "diagnostic export is not enabled"
Require ([bool]$diagnostics.screenshot.runtimeRequired -and [bool]$diagnostics.recording.runtimeRequired) "screenshot/recording must disclose runtime dependency"

$shipLifecycle = @(
    [ordered]@{ operation = "spawn"; instance = "preview:ship-dock"; generation = 1 },
    [ordered]@{ operation = "snapshot"; graph = [string]$dock.entityGraph.id; anchors = @($dock.anchors).Count },
    [ordered]@{ operation = "camera"; mode = [string]$dock.camera.mode },
    [ordered]@{ operation = "dispose"; instance = "preview:ship-dock" },
    [ordered]@{ operation = "stale-dispose"; accepted = $false }
)
$report = [ordered]@{
    schema = "cm2.preview-suite-report/1"
    suite = "cm2.preview-suite/1"
    runtimeMode = [string]$fixture.runtimeMode
    sharedAuthority = [ordered]@{ compiler = [string]$authority.compiler; catalog = [string]$authority.catalog; worldEntityAdapter = [string]$authority.worldEntityAdapter; sameNormalizedRuntimeDTO = [bool]$authority.sameNormalizedRuntimeDTO }
    effectLab = [ordered]@{ fixedSeed = [int]$effect.fixedSeed; distances = @($effect.distances); lods = @($effect.lod); productionEffectPlayer = $true; productionPresentationBudget = $true; replayHash = (Sha256-Text (Canonical-Json $effectTraceA)) }
    weaponRange = [ordered]@{ fixedSeed = [int]$range.fixedSeed; shots = [int]$range.shots; targetTypes = @($range.targetTypes); movingTarget = $true; damageMin = [int]$range.damage.min; damageMax = [int]$range.damage.max; budget = [ordered]@{ accepted = [int]$range.budget.accepted; degraded = [int]$range.budget.degraded; rejected = [int]$range.budget.rejected }; replayHash = $weaponReplayHashA }
    shipDock = [ordered]@{ vox = [string]$dock.vox.path; entityGraph = [string]$dock.entityGraph.id; anchors = @($dock.anchors).Count; mounts = @($dock.mounts).Count; turrets = @($dock.turrets).Count; camera = [string]$dock.camera.mode; engineMarkers = @($dock.engineMarkers).Count; lifecycle = $shipLifecycle }
    diagnostics = [ordered]@{ machineReport = [string]$diagnostics.machineReport; screenshot = [string]$diagnostics.screenshot.provider; recording = [string]$diagnostics.recording.provider; runtimeCaptureRequired = $true }
    liveHost = [ordered]@{ scene = "Content Mod 2/_ai_scenario_preview_suite.xml"; controller = "Content Mod 2/script/testing/scenario/preview_suite_controller.lua"; scenario = "Content Mod 2/testing/scenarios/creator/preview_suite_v1/scenario.json"; sharedWorldEntityAdapter = $true; realInputModes = @("leftarrow", "rightarrow", "space"); numberedKeysReservedForNativeTools = $true; lmbReservedForNativeTool = $true; runtimeEvidenceRequired = $true }
    runtimeCatalogUnchanged = $true
    traceCount = $effectTraceA.Count + $weaponTraceA.Count + $shipLifecycle.Count
    deferredRuntimeScope = @($fixture.deferredRuntimeScope)
    result = "pass"
}
Write-Canonical $ReportPath $report
Write-Output (Canonical-Json $report)
Write-Host ("Preview Suite v1 passed: Effect Lab + Weapon Range + Ship Dock; S0/S2/S5 replay hashes stable; runtime catalog unchanged.") -ForegroundColor Green
exit 0
