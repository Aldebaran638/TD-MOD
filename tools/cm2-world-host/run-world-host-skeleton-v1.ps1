# Static/executable contract check for the Gate 4.3 Host skeleton and adapters.

param(
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\world-host-skeleton-v1.fixture.json" }
function Fail([string]$message) { throw ("World Host Skeleton v1 failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Read-Source([string]$relative) { $path = Join-Path $root $relative; Require (Test-Path -LiteralPath $path -PathType Leaf) ("missing source: " + $relative); return Get-Content -Raw -LiteralPath $path }

$fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
$hostSource = Read-Source "Content Mod 2\script\world\host\world_host_v1.lua"
$adapterSource = Read-Source "Content Mod 2\script\world\adapter\ship_instance_adapter_v1.lua"
$vehicleSource = Read-Source "Content Mod 2\script\world\adapter\vehicle_instance_v1.lua"
$syntheticSource = Read-Source "Content Mod 2\script\world\adapter\synthetic_world_adapter_v1.lua"
$rootMain = Read-Source "Content Mod 2\main.lua"
$shipMain = Read-Source "Content Mod 2\script\shipMain.lua"
$strikeMain = Read-Source "Content Mod 2\script\strikeCraftMain.lua"
$escortMain = Read-Source "Content Mod 2\script_riddle_escort\shipMain.lua"
$clientMain = Read-Source "Content Mod 2\script\client.lua"
$escortClient = Read-Source "Content Mod 2\script_riddle_escort\client\client.lua"

Require ([string]$fixture.schema -eq "cm2.world-host-skeleton/1") "fixture schema mismatch"
Require ([int]$fixture.host.maxInstances -eq 12) "fixed Host capacity must be 12"
Require ([double]$fixture.host.heartbeatIntervalSeconds -eq 0.5) "heartbeat interval must be 0.5 seconds"
foreach ($symbol in @("serverInit", "serverTick", "clientInit", "clientTick", "registerInstance", "heartbeatInstance", "unregisterInstance", "observeAnnouncement", "dispose", "snapshot", "getReport")) {
    Require ($hostSource -match ("function host\." + $symbol + "\b")) ("Host API missing: " + $symbol)
}
foreach ($symbol in @("serverInit", "serverTick", "clientInit", "clientTick", "dispose", "getReport")) {
    Require ($adapterSource -match ("function adapter\." + $symbol + "\b")) ("adapter API missing: " + $symbol)
}
foreach ($symbol in @("init", "tick", "dispose", "snapshot", "getReport")) {
    Require ($syntheticSource -match ("function synthetic\." + $symbol + "\b")) ("synthetic/preview adapter API missing: " + $symbol)
}
foreach ($token in @("dense", "byId", "generation", "heartbeatInterval", "queueDepth", "queueDropped", "content-host-unavailable", "local-fallback", "stale generation", "instance capacity exhausted")) {
    Require (($hostSource + $adapterSource) -match [regex]::Escape($token)) ("lifecycle/fallback token missing: " + $token)
}
Require ($rootMain -match '#include "script/world/host/world_host_v1\.lua"' -and $rootMain -match 'cm2WorldHostV1\.serverInit\("content-host"') "root main does not own Content Host init"
Require ($rootMain -match 'cm2WorldHostV1\.serverTick\(dt\)' -and $rootMain -match 'cm2WorldHostV1\.clientTick\(dt\)') "root main Host ticks are missing"
foreach ($entry in @(@{source=$shipMain; name="shipMain"}, @{source=$strikeMain; name="strikeCraftMain"}, @{source=$escortMain; name="escort"})) {
    Require ($entry.source -match '#include "(?:world/host/world_host_v1|(?:\.\./)?script/world/host/world_host_v1)\.lua"') ($entry.name + " Host include missing")
    $directAdapterLifecycle = $entry.source -match 'cm2ShipInstanceAdapterV1\.serverInit\(' -and $entry.source -match 'cm2ShipInstanceAdapterV1\.serverTick\('
    $vehicleInstanceLifecycle = $entry.source -match '#include "(?:\.\./)?(?:script/)?world/adapter/vehicle_instance_v1\.lua"' -and $entry.source -match 'cm2VehicleInstanceV1\.serverInit\(' -and $entry.source -match 'cm2VehicleInstanceV1\.serverTick\('
    Require ($directAdapterLifecycle -or $vehicleInstanceLifecycle) ($entry.name + " adapter lifecycle wiring missing")
}
Require ($vehicleSource -match 'cm2ShipInstanceAdapterV1\.serverInit\(' -and $vehicleSource -match 'cm2ShipInstanceAdapterV1\.serverTick\(') "VehicleInstance does not forward adapter lifecycle"
Require ($clientMain -match 'cm2ShipInstanceAdapterV1\.clientInit\(' -and $clientMain -match 'cm2ShipInstanceAdapterV1\.clientTick\(') "generic client adapter lifecycle missing"
Require ($escortClient -match 'cm2ShipInstanceAdapterV1\.clientInit\(' -and $escortClient -match 'cm2ShipInstanceAdapterV1\.clientTick\(') "escort client adapter lifecycle missing"
Require ([string]$fixture.expected.liveRuntimeProof -like "required-but-unavailable*") "fixture must not claim live runtime proof"
foreach ($deferred in @("movement", "damage", "weapon-fire", "projectile-authority", "presentation-audio")) { Require (@($fixture.deferredScope) -contains $deferred) ("fixture does not defer scope: " + $deferred) }
Require ($adapterSource -notmatch "ClientCall|QueryRaycast|Explosion|SpawnParticle") "adapter contains a direct engine/weapon authority call"
Require ($syntheticSource -notmatch "ClientCall|QueryRaycast|Explosion|SpawnParticle|FindBody") "synthetic adapter contains a runtime engine call"

$report = [ordered]@{
    schema = "cm2.world-host-skeleton-report/1"
    hostMode = [string]$fixture.host.mode
    hostId = [string]$fixture.host.hostId
    hostCapacity = [int]$fixture.host.maxInstances
    adapterCount = @($fixture.adapters).Count
    lifecycleSteps = @($fixture.lifecycle).Count
    migratedScope = @($fixture.migratedScope)
    deferredScope = @($fixture.deferredScope)
    liveRuntimeEvidence = "unavailable-without-Teardown.exe"
    result = "pass"
}
$json = $report | ConvertTo-Json -Depth 10
if ($ReportPath -ne "") {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $reportAbsolute = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $ReportPath))
    [IO.File]::WriteAllText($reportAbsolute, $json, (New-Object Text.UTF8Encoding($false)))
}
Write-Output $json
Write-Host "World Host Skeleton v1 passed: root Host, ship adapters, dense lifecycle, explicit local fallback and deferred authority scope." -ForegroundColor Green
exit 0
