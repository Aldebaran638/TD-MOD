# CM2 weapon catalog, behavior, and battlecruiser frame semantic checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0

function Add-Issue {
    param([string]$Message)
    Write-Host "[WEAPON SEMANTIC ERROR] $Message" -ForegroundColor Red
    $script:issues++
}

function Read-Required {
    param([string]$RelativePath)
    $full = Join-Path $script:modRoot $RelativePath
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Add-Issue "missing file: $RelativePath"
        return ""
    }
    return [IO.File]::ReadAllText($full)
}

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

$modRoot = (Resolve-Path -LiteralPath $Path).Path
$weaponSchema = Read-Required "script\data\weapons\schema.lua"
$weaponDefinitionRoot = Join-Path $modRoot "script\data\weapons"
$weaponDefinitionFiles = @(
    Get-ChildItem -LiteralPath $weaponDefinitionRoot -Recurse -Filter "*.lua" -File |
        Where-Object { $_.Name -notin @("schema.lua", "weapon_catalog.lua") }
)
$standard = $weaponSchema + "`n" + (($weaponDefinitionFiles | ForEach-Object {
    [IO.File]::ReadAllText($_.FullName)
}) -join "`n")
$weaponSourceById = @{}
foreach ($weaponFile in $weaponDefinitionFiles) {
    $sourceText = [IO.File]::ReadAllText($weaponFile.FullName)
    $idMatch = [Regex]::Match($sourceText, 'weaponType\s*=\s*"([^"]+)"')
    if ($idMatch.Success) {
        $weaponSourceById[$idMatch.Groups[1].Value] = $sourceText
    }
}
$catalog = Read-Required "script\data\weapons\weapon_catalog.lua"
$stellaris446Catalog = Read-Required "script\data\weapons\stellaris_4_4_6.lua"
$stellarisGeneratedCatalog = Read-Required "script\data\weapons\stellaris_generated_4_4_6.lua"
$shipDefinition = Read-Required "script\data\ships\battlecruiser.lua"
$strikeCraftDefinition = Read-Required "script\data\ships\advanced_strike_craft.lua"
$interceptorShipDefinitions = Read-Required "script\data\ships\interceptor_projectiles.lua"
$componentCatalog = Read-Required "script\data\components\component_catalog.lua"
$shipMounts = Read-Required "script\data\ships\battlecruiser_mounts.lua"
$titanDefinition = Read-Required "script\data\ships\titan.lua"
$titanMounts = Read-Required "script\data\ships\titan_mounts.lua"
$ship = $shipDefinition + "`n" + $shipMounts
$entry = Read-Required "script\shipMain.lua"
$weaponBootstrap = Read-Required "script\weapon\server\bootstrap.lua"
$clientEntry = Read-Required "script\client.lua"
$clientShipBootstrap = Read-Required "script\ship\common\client\bootstrap.lua"
$clientWeaponBootstrap = Read-Required "script\weapon\client\bootstrap.lua"
$client = $clientEntry + "`n" + $clientShipBootstrap + "`n" + $clientWeaponBootstrap
$mainXmlPath = Join-Path $modRoot "main.xml"
$globalMainPath = Join-Path $modRoot "main.lua"
$mainXml = if (Test-Path -LiteralPath $mainXmlPath -PathType Leaf) {
    [IO.File]::ReadAllText($mainXmlPath)
} else { "" }
$globalMain = if (Test-Path -LiteralPath $globalMainPath -PathType Leaf) {
    [IO.File]::ReadAllText($globalMainPath)
} else { "" }
$clientLoadout = Read-Required "script\weapon\client\common\state\weapon_loadout.lua"
$configUi = Read-Required "script\weapon\client\config_ui\weapon_config_ui.lua"
$localWeaponConfig = Read-Required "script\weapon\client\config_ui\local_weapon_config.lua"
$configurationBinding = Read-Required "script\ship\common\client\config\weapon_configuration_binding.lua"
$mainWeaponHud = Read-Required "script\weapon\client\common\hud\main_weapon_hud.lua"
$radialWeaponWheel = Read-Required "script\weapon\client\common\hud\radial_weapon_wheel.lua"
$crosshair = Read-Required "script\weapon\client\common\hud\ship_crosshair.lua"
$projectileVisual = Read-Required "script\weapon\client\slots\l\kinetic_artillery\effects\projectile_visual.lua"
$shieldHitFx = Read-Required "script\weapon\client\common\effects\shield_hit_fx.lua"
$clientRegistry = Read-Required "script\ship\common\client\registry\ship_registry.lua"
$engineThrusterFx = Read-Required "script\ship\common\client\effects\engine_thruster_fx.lua"
$serverRequests = (Read-Required "script\ship\common\server\network\request_authorizer.lua") +
    "`n" + (Read-Required "script\ship\common\server\network\control_snapshot_endpoint.lua") +
    "`n" + (Read-Required "script\weapon\server\network\weapon_command_endpoint.lua")
$groupRuntime = Read-Required "script\weapon\server\common\runtime\weapon_group.lua"
$targetingPolicy = Read-Required "script\weapon\common\targeting_policy.lua"
$weaponDamageRuntime = Read-Required "script\weapon\server\common\runtime\damage.lua"
$weaponRuntime = Read-Required "script\weapon\server\common\runtime\weapon_runtime.lua"
$controllerRegistry = Read-Required "script\weapon\server\common\runtime\controller_registry.lua"
$specializedControllerAdapters = Read-Required "script\weapon\server\common\runtime\specialized_controller_adapters.lua"
$loadoutRuntime = Read-Required "script\weapon\server\common\loadout\slot_loadout.lua"
$loadoutApi = Read-Required "script\weapon\server\common\loadout\slot_loadout_api.lua"
$mainWeaponInput = Read-Required "script\weapon\client\common\input\main_weapon_input.lua"
$behaviorCommon = Read-Required "script\weapon\server\behaviors\common.lua"
$raycastBehavior = Read-Required "script\weapon\server\behaviors\raycast.lua"
$raycastCommon = Read-Required "script\weapon\server\behaviors\raycast_common.lua"
$infernoRaycastBehavior = Read-Required "script\weapon\server\behaviors\inferno_raycast.lua"
$genericRaycastFx = Read-Required "script\weapon\client\common\effects\generic_raycast_fx.lua"
$gammaLaserFx = Read-Required "script\weapon\client\common\effects\gamma_laser_fx.lua"
$weaponMuzzleFx = Read-Required "script\weapon\client\common\effects\weapon_muzzle_fx.lua"
$weaponImpactFx = Read-Required "script\weapon\client\common\effects\weapon_impact_fx.lua"
$weaponFxResources = Read-Required "script\weapon\client\common\effects\weapon_fx_resources.lua"
$chargedRayBeamRenderer = Read-Required "script\weapon\client\common\effects\charged_ray_beam_renderer.lua"
$perditionBeamFx = Read-Required "script\weapon\client\slots\t\perdition_beam\effects\beam_fx.lua"
$perditionImpactFx = Read-Required "script\weapon\client\slots\t\perdition_beam\effects\impact_fx.lua"
$tSlotRenderState = Read-Required "script\weapon\client\slots\t\perdition_beam\effects\render_state.lua"
$chargedRayVisual = Read-Required "script\weapon\server\common\runtime\charged_ray_visual.lua"
$guidedRuntime = Read-Required "script\weapon\server\guided\runtime.lua"
$guidedMovement = Read-Required "script\weapon\server\guided\movement.lua"
$guidedCollider = Read-Required "script\weapon\server\guided\collider.lua"
$guidedTargeting = Read-Required "script\weapon\client\guided\targeting\guided_targeting.lua"
$clientMain = $client
$xSlotControl = Read-Required "script\weapon\server\slots\x\tachyon_lance\control.lua"
$xSlotState = Read-Required "script\weapon\server\slots\x\tachyon_lance\state.lua"
$xSlotMuzzleLight = Read-Required "script\weapon\server\slots\x\tachyon_lance\muzzle_light.lua"
$xSlotChargingFx = Read-Required "script\weapon\client\slots\x\tachyon_lance\effects\charging_fx.lua"
$arcChargingFx = Read-Required "script\weapon\client\slots\x\focused_arc_emitter\effects\charging_fx.lua"
$weaponSoundCatalog = Read-Required "script\weapon\client\common\sound\weapon_sound_catalog.lua"
$soundService = Read-Required "script\weapon\client\common\sound\sound_service.lua"
$missileVisual = Read-Required "script\weapon\client\guided\effects\missile_visual.lua"
$projectileManager = Read-Required "script\weapon\server\slots\l\kinetic_artillery\projectile_manager.lua"
$hSlotControl = Read-Required "script\weapon\server\slots\h\gamma_strike_craft\control.lua"
$hSlotFlight = Read-Required "script\weapon\server\slots\h\gamma_strike_craft\flight_controller.lua"
$flakWeapon = Read-Required "script\data\weapons\p\flak_artillery.lua"
$pointDefenseWeapon = Read-Required "script\data\weapons\p\guardian_point_defense.lua"
$pointDefenseControl = Read-Required "script\weapon\server\slots\p\point_defense\control.lua"
$pointDefenseFx = Read-Required "script\weapon\client\slots\p\point_defense\effects.lua"
$networkDebug = Read-Required "script\net\network_debug.lua"
$syncLimiter = Read-Required "script\net\server_sync_limiter.lua"
$inputSnapshot = Read-Required "script\net\client_input_snapshot.lua"
$guidedGroup = Read-Required "script\weapon\server\guided\slot_group.lua"
$runtimeState = Read-Required "script\ship\common\server\state\runtime_state.lua"
$lSlotState = Read-Required "script\weapon\server\slots\l\kinetic_artillery\state.lua"
$shipCamera = Read-Required "script\ship\common\client\camera\ship_camera.lua"
$shipRoll = Read-Required "script\ship\common\client\hud\ship_roll_error.lua"
$bodyMove = Read-Required "script\ship\common\client\input\body_move_input.lua"
$shipRegistryServer = Read-Required "script\ship\common\server\registry\ship_registry.lua"
$shipComponents = Read-Required "script\ship\common\server\components\ship_components.lua"
$shipHealthBar = Read-Required "script\ship\common\client\hud\ship_health_bar.lua"
$shipCloak = Read-Required "script\ship\common\server\lifecycle\ship_cloak.lua"
$speedLimit = Read-Required "script\ship\common\server\movement\body_combat_speed_limit.lua"
$shipDamage = Read-Required "script\ship\common\server\damage\ship_damage.lua"
$sensorHud = Read-Required "script\ship\common\client\hud\ship_sensor_hud.lua"
$strikeCraftEntry = Read-Required "script\strikeCraftMain.lua"
$strikeCraftPrefab = Read-Required "prefabs\gammaStrikeCraft.xml"
$shipServerBootstrap = Read-Required "script\ship\common\server\bootstrap.lua"
$shipClientBootstrap = Read-Required "script\ship\common\client\bootstrap.lua"
$serverShipContext = Read-Required "script\ship\common\server\runtime_context.lua"
$clientShipContext = Read-Required "script\ship\common\client\runtime_context.lua"
$shipCatalog = Read-Required "script\data\ships\ship_catalog.lua"
$shipSchema = Read-Required "script\data\ships\schema.lua"
$frameworkSource = (($weaponDefinitionFiles | ForEach-Object {
    [IO.File]::ReadAllText($_.FullName)
}) + (Get-ChildItem -LiteralPath (Join-Path $modRoot "script\weapon") -Recurse -Filter "*.lua" -File |
    ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) +
    (Get-ChildItem -LiteralPath (Join-Path $modRoot "script\ship\common") -Recurse -Filter "*.lua" -File |
    ForEach-Object { [IO.File]::ReadAllText($_.FullName) })) -join "`n"

$expected = [ordered]@{
    tachyonLance = "X"
    focusedArcEmitter = "X"
    gigaCannon = "X"
    largeGammaLaser = "L"
    largePlasmaCannon = "L"
    largeGaussCannon = "L"
    kineticArtillery = "L"
    largeStormfireAutocannon = "L"
    mediumGammaLaser = "M"
    mediumPlasmaCannon = "M"
    phaseDisruptor = "M"
    mediumGaussCannon = "M"
    mediumStormfireAutocannon = "M"
    swarmerMissile = "M"
    devastatorTorpedoes = "G"
    neutronLauncher = "G"
    gammaStrikeCraft = "H"
}

$expectedEnglishNames = [ordered]@{
    tachyonLance = "Tachyon Lance"
    focusedArcEmitter = "Focused Arc Emitter"
    gigaCannon = "Giga Cannon"
    largeGammaLaser = "Large Gamma Laser"
    largePlasmaCannon = "Large Plasma Cannon"
    largeGaussCannon = "Large Gauss Cannon"
    kineticArtillery = "Kinetic Artillery"
    largeStormfireAutocannon = "Large Stormfire Autocannon"
    mediumGammaLaser = "Medium Gamma Laser"
    mediumPlasmaCannon = "Medium Plasma Cannon"
    phaseDisruptor = "Phase Disruptor"
    mediumGaussCannon = "Medium Gauss Cannon"
    mediumStormfireAutocannon = "Medium Stormfire Autocannon"
    swarmerMissile = "Whirlwind Missiles"
    devastatorTorpedoes = "Devastator Torpedoes"
    neutronLauncher = "Neutron Launchers"
    gammaStrikeCraft = "Advanced Strike Craft"
}

foreach ($item in $expected.GetEnumerator()) {
    $id = [Regex]::Escape($item.Key)
    $weaponSource = [string]$weaponSourceById[$item.Key]
    if ($weaponSource -notmatch "(?s)weaponType\s*=\s*`"$id`".*?slotTypes\s*=\s*\{\s*`"$($item.Value)`"\s*\}") {
        Add-Issue "weapon $($item.Key) is missing or is not assigned to slot $($item.Value)"
    }
    if ($ship -notmatch "`"$id`"") {
        Add-Issue "weapon $($item.Key) is absent from battlecruiser weapon pools"
    }
    if ($weaponSource -notmatch "(?s)officialComponentId\s*=\s*`"[A-Z0-9_]+`".*?family\s*=\s*`"[a-z0-9_]+`"") {
        Add-Issue "weapon $($item.Key) has no official component/family metadata"
    }
    $iconRelative = "gfx\ui\weapon_icons\$($item.Key).png"
    if (-not (Test-Path -LiteralPath (Join-Path $modRoot $iconRelative) -PathType Leaf)) {
        Add-Issue "weapon $($item.Key) is missing UI icon: $iconRelative"
    }
    if ($weaponSource -notmatch "(?s)mountProfile\s*=\s*`"[xlmgh][A-Za-z]+`".*?salvoProfile\s*=\s*\{.*?groupSize\s*=\s*[124].*?sequence\s*=\s*`"(?:sequential|grouped)`"") {
        Add-Issue "weapon $($item.Key) has no mount/salvo runtime profile"
    }
    if ($weaponSoundCatalog -notmatch "(?m)^\s*$id\s*=") {
        Add-Issue "weapon $($item.Key) has no dedicated sound profile"
    }
    $soundRelative = "sound\weapons\$($item.Key)"
    $soundDirectory = Join-Path $modRoot $soundRelative
    if (-not (Test-Path -LiteralPath $soundDirectory -PathType Container) -or
        @(Get-ChildItem -LiteralPath $soundDirectory -Filter "*.ogg" -File -ErrorAction SilentlyContinue).Count -eq 0) {
        Add-Issue "weapon $($item.Key) has no dedicated OGG assets: $soundRelative"
    }
}

foreach ($item in $expectedEnglishNames.GetEnumerator()) {
    $id = [Regex]::Escape($item.Key)
    $name = [Regex]::Escape($item.Value)
    $weaponSource = [string]$weaponSourceById[$item.Key]
    if ($weaponSource -notmatch "(?s)weaponType\s*=\s*`"$id`".*?englishName\s*=\s*`"$name`"") {
        Add-Issue "weapon $($item.Key) does not use official English name '$($item.Value)'"
    }
}

$officialCombatFields = @(
    "damageMin", "damageMax", "shieldFix", "armorFix", "bodyFix",
    "shieldPenetration", "armorPenetration"
)
$officialCombatStats = [ordered]@{
    tachyonLance = @(780, 1950, 0.5, 2.0, 1.5, 0.0, 0.0)
    focusedArcEmitter = @(2, 1690, 1.0, 1.0, 1.0, 1.0, 1.0)
    gigaCannon = @(910, 2600, 1.5, 0.75, 1.0, 0.0, 0.0)
    largeGammaLaser = @(102, 276, 0.5, 1.5, 1.25, 0.0, 0.0)
    largePlasmaCannon = @(126, 336, 0.25, 2.0, 1.5, 0.0, 0.0)
    largeGaussCannon = @(96, 276, 1.5, 0.5, 1.0, 0.0, 0.0)
    kineticArtillery = @(195, 585, 2.0, 0.5, 1.0, 0.0, 0.0)
    largeStormfireAutocannon = @(78, 162, 1.5, 0.25, 1.25, 0.0, 0.0)
    mediumGammaLaser = @(43, 115, 0.5, 1.5, 1.25, 0.0, 0.0)
    mediumPlasmaCannon = @(53, 140, 0.25, 2.0, 1.5, 0.0, 0.0)
    phaseDisruptor = @(1, 48, 1.25, 1.0, 1.0, 0.70, 0.70)
    mediumGaussCannon = @(40, 115, 1.5, 0.5, 1.0, 0.0, 0.0)
    mediumStormfireAutocannon = @(33, 68, 1.5, 0.25, 1.25, 0.0, 0.0)
    swarmerMissile = @(61, 85, 1.0, 1.0, 1.0, 1.0, 0.0)
    devastatorTorpedoes = @(169, 254, 1.0, 1.5, 1.0, 1.0, 0.0)
    neutronLauncher = @(61, 131, 0.5, 1.5, 1.75, 0.0, 0.0)
    gammaStrikeCraft = @(6, 17, 1.0, 1.5, 1.0, 1.0, 0.0)
    flakArtillery = @(4, 8, 2.0, 0.25, 1.0, 0.25, 0.0)
    guardianPointDefense = @(4, 8, 0.25, 2.0, 1.0, 0.0, 0.25)
}

foreach ($weaponEntry in $officialCombatStats.GetEnumerator()) {
    $source = [string]$weaponSourceById[$weaponEntry.Key]
    for ($fieldIndex = 0; $fieldIndex -lt $officialCombatFields.Count; $fieldIndex++) {
        $field = $officialCombatFields[$fieldIndex]
        $expectedValue = [double]$weaponEntry.Value[$fieldIndex]
        $fieldMatch = [Regex]::Match(
            $source,
            "(?m)^\s*$([Regex]::Escape($field))\s*=\s*(-?(?:\d+(?:\.\d*)?|\.\d+))\s*,"
        )
        if (-not $fieldMatch.Success) {
            if ($expectedValue -eq 0.0 -and $field -in @("shieldPenetration", "armorPenetration")) {
                continue
            }
            Add-Issue "weapon $($weaponEntry.Key) is missing official Stellaris combat stat $field"
            continue
        }
        $actualValue = [double]::Parse(
            $fieldMatch.Groups[1].Value,
            [Globalization.CultureInfo]::InvariantCulture
        )
        if ([Math]::Abs($actualValue - $expectedValue) -gt 0.0001) {
            Add-Issue "weapon $($weaponEntry.Key) has non-official $field=$actualValue (expected $expectedValue)"
        }
    }
}

$officialPowerUse = [ordered]@{
    tachyonLance = 260; focusedArcEmitter = 260; gigaCannon = 260
    largeGammaLaser = 88; largePlasmaCannon = 107; largeGaussCannon = 88
    kineticArtillery = 91; largeStormfireAutocannon = 112
    mediumGammaLaser = 39; mediumPlasmaCannon = 47; phaseDisruptor = 39
    mediumGaussCannon = 39; mediumStormfireAutocannon = 49; swarmerMissile = 17
    devastatorTorpedoes = 64; neutronLauncher = 154; gammaStrikeCraft = 59
    flakArtillery = 10; guardianPointDefense = 10
}
foreach ($powerEntry in $officialPowerUse.GetEnumerator()) {
    $source = [string]$weaponSourceById[$powerEntry.Key]
    $powerMatch = [Regex]::Match($source, '(?m)^\s*powerUse\s*=\s*(\d+(?:\.\d*)?)\s*,')
    if (-not $powerMatch.Success -or
        [Math]::Abs([double]$powerMatch.Groups[1].Value - [double]$powerEntry.Value) -gt 0.0001) {
        Add-Issue "weapon $($powerEntry.Key) does not use official Stellaris 4.4.6 power=$($powerEntry.Value)"
    }
}

$requiredCatalogTokens = @(
    'RED_LASER', 'GAMMA_LASER', 'MASS_DRIVER_1', 'MASS_DRIVER_5',
    'PLASMA_1', 'PLASMA_3', 'DISRUPTOR_1', 'DISRUPTOR_3', 'AUTOCANNON_4',
    'KINETIC_ARTILLERY_1', 'ENERGY_LANCE_1', 'ARC_EMITTER_1', 'MASS_ACCELERATOR_1',
    'MISSILE_1', 'MISSILE_5', 'SWARMER_MISSILE_1', 'TORPEDO_1', 'TORPEDO_2',
    'ENERGY_TORPEDO_1', 'PSIONIC_TORPEDO', 'PSIONIC_LIGHTNING',
    'SMALL_PSIONIC_DISRUPTOR', 'MEDIUM_PSIONIC_DISRUPTOR',
    'LARGE_SCOUT_HANGAR_1', 'STRIKE_CRAFT_HANGAR_1', 'STRIKE_CRAFT_HANGAR_2',
    'STRIKE_CRAFT_SKRAND', 'PSIONIC_STRIKE_CRAFT'
)
foreach ($token in $requiredCatalogTokens) {
    if ($stellaris446Catalog -notmatch [Regex]::Escape($token)) {
        Add-Issue "Stellaris 4.4.6 mechanical catalog is missing official component token: $token"
    }
}
if ($catalog -notmatch '#include\s+"stellaris_4_4_6\.lua"' -or
    $stellaris446Catalog -notmatch 'stellarisWeaponPoolData\s*=\s*\{\}' -or
    $stellaris446Catalog -notmatch '#include\s+"stellaris_generated_4_4_6\.lua"' -or
    $stellarisGeneratedCatalog -notmatch 'stellarisGeneratedWeaponCount\s*=\s*(?:[8-9]\d|1\d\d)' -or
    $stellarisGeneratedCatalog -match '(?:component|id)\s*=\s*"[^"]*(?:BIO|HIVE|TOXIC|AMOEBA|METEOROID|GG_STRIKE|AI_STRIKE|DRONE_STRIKE|CARAVANEER|LENS_FLARE|SOLARFLARE)' -or
    $shipDefinition -notmatch 'pairs\(stellarisWeaponPoolData\s+or\s+\{\}\)') {
    Add-Issue "complete Stellaris X/L/M/S/G/H catalog is not loaded into the battlecruiser weapon pools"
}
if ($stellarisGeneratedCatalog -notmatch '(?m)^\s*local\s+_generatedSizes\s*=\s*\{' -or
    $stellarisGeneratedCatalog -notmatch '(?m)^\s*local\s+function\s+_generatedIcon\s*\(' -or
    $stellarisGeneratedCatalog -notmatch '(?m)^\s*local\s+function\s+_generatedDefineRay\s*\(' -or
    $stellarisGeneratedCatalog -notmatch '(?m)^\s*local\s+function\s+_generatedDefineProjectile\s*\(' -or
    $stellarisGeneratedCatalog -notmatch '(?m)^\s*local\s+function\s+_generatedDefineGuided\s*\(' -or
    $stellarisGeneratedCatalog -notmatch '(?m)^\s*local\s+function\s+_generatedDefineCraft\s*\(' -or
    $stellarisGeneratedCatalog -match '_sizes\[item\.slot\]|_icon\(item\.icon\)|_define(?:Ray|Projectile|Guided|Craft)\(common\)') {
    Add-Issue "generated Stellaris catalog is not self-contained across Teardown include scopes"
}

$stellarisIconRoot = Join-Path $modRoot "gfx\ui\weapon_icons\stellaris"
$requiredIconNames = @(
    'laser_1', 'laser_2', 'laser_3', 'laser_4', 'laser_5',
    'mass_driver_1', 'mass_driver_2', 'mass_driver_3', 'mass_driver_4', 'mass_driver_5',
    'plasma_1', 'plasma_2', 'plasma_3', 'disruptor_1', 'disruptor_2', 'disruptor_3',
    'autocannon_1', 'autocannon_2', 'autocannon_3', 'autocannon_4', 'kinetic_artillery_1',
    'energy_lance_1', 'arc_emitter_1', 'mass_accelerator_1', 'missile_1', 'missile_2',
    'missile_3', 'missile_4', 'missile_5', 'swarmer_missile_1', 'torpedo_1', 'torpedo_2',
    'energy_torpedo_1', 'zro_launchers', 'psionic_lightning', 'psionic_disruptor',
    'strike_craft_scout_1', 'strike_craft_fighter_1', 'strike_craft_fighter_2',
    'skrand_strike_craft', 'psionic_bombers'
)
foreach ($iconName in $requiredIconNames) {
    if (-not (Test-Path -LiteralPath (Join-Path $stellarisIconRoot ($iconName + '.png')) -PathType Leaf)) {
        Add-Issue "Stellaris weapon icon is missing: $iconName.png"
    }
}
$generatedIconMatches = [Regex]::Matches($stellarisGeneratedCatalog, '(?m)^\s*\{.*?\bicon\s*=\s*"([^"]+)"')
foreach ($iconMatch in $generatedIconMatches) {
    $generatedIconName = $iconMatch.Groups[1].Value
    if (-not (Test-Path -LiteralPath (Join-Path $stellarisIconRoot ($generatedIconName + '.png')) -PathType Leaf)) {
        Add-Issue "generated Stellaris weapon icon is missing: $generatedIconName.png"
    }
}
$staticIconPattern = 'iconPath\s*=\s*"(MOD/gfx/ui/weapon_icons/[^"%]+\.png)"'
foreach ($weaponFile in $weaponDefinitionFiles) {
    $sourceText = [IO.File]::ReadAllText($weaponFile.FullName)
    foreach ($iconMatch in [Regex]::Matches($sourceText, $staticIconPattern)) {
        $reference = $iconMatch.Groups[1].Value
        $relative = $reference.Substring(4).Replace("/", [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath (Join-Path $modRoot $relative) -PathType Leaf)) {
            Add-Issue "$($weaponFile.FullName) references missing weapon icon: $reference"
        }
    }
}

if ($weaponDamageRuntime -notmatch 'function\s+server\.weaponDamageRoll\s*\(' -or
    $weaponDamageRuntime -notmatch 'minimum\s*\+\s*\(maximum\s*-\s*minimum\)\s*\*\s*math\.random\(\)' -or
    $guidedGroup -notmatch 'damageMin\s*=\s*tonumber\(weaponDef\.damageMin\)' -or
    $guidedRuntime -notmatch 'damageMin\s*=\s*tonumber\(cfg\.damageMin\)' -or
    $guidedCollider -notmatch 'server\.weaponDamageRoll\(projectile\)' -or
    $projectileManager -notmatch 'server\.weaponDamageRoll\(settings\)') {
    Add-Issue "weapon hit paths do not roll the configured Stellaris damage interval"
}

foreach ($behavior in @("raycast", "infernoRaycast", "projectile", "rocketProjectile", "guidedProjectile", "strikeCraft")) {
    if ($standard -notmatch [Regex]::Escape("$behavior = true")) {
        Add-Issue "catalog does not declare behavior $behavior"
    }
    $behaviorFile = $behavior.Replace('infernoRaycast', 'inferno_raycast').Replace('rocketProjectile','rocket_projectile').Replace('guidedProjectile','guided_projectile').Replace('strikeCraft','strike_craft')
    if ($weaponBootstrap -notmatch [Regex]::Escape("behaviors/$behaviorFile.lua")) {
        Add-Issue "weapon bootstrap does not include controller for $behavior"
    }
}

foreach ($profile in @(
    "tachyonLance", "gammaBeam", "redBeam", "blueBeam", "uvBeam", "xrayBeam",
    "energyBeam", "focusedArcBeam", "arcBeam", "psionicArcBeam", "kineticProjectile",
    "plasmaProjectile", "autocannonProjectile", "gigaCannonProjectile",
    "neutronProjectile", "guidedMissile",
    "energyTorpedo", "strikeCraft"
)) {
    if ($standard -notmatch [Regex]::Escape("$profile = true")) {
        Add-Issue "FX profile is not registered: $profile"
    }
}

if ($stellaris446Catalog -notmatch 'fxPalette\s*=\s*"particleLance"' -or
    $stellaris446Catalog -notmatch 'zroLauncher' -or
    $stellaris446Catalog -notmatch 'fxColor\s*=\s*color' -or
    $stellarisGeneratedCatalog -notmatch 'common\.fxColor\s*=\s*item\.color' -or
    $xSlotChargingFx -notmatch 'definition\.fxPalette\s*==\s*"particleLance"' -or
    $projectileVisual -notmatch 'fxColor\s*=\s*definition\.fxColor' -or
    $genericRaycastFx -notmatch 'psionicArcBeam' -or
    $genericRaycastFx -notmatch 'beam\.fxColor\s+or\s+profile\.color' -or
    $genericRaycastFx -notmatch '_spawnImpactParticles\(profile,\s*endPos,\s*hitNormal,\s*fxColor\)') {
    Add-Issue "Stellaris weapon variants do not reuse their family FX with data-driven color palettes"
}

if ($catalog -notmatch '#include\s+"schema\.lua"' -or
    $catalog -match '#include\s+"standard_weapons\.lua"') {
    Add-Issue "weapon catalog does not use the single-source weapon schema"
}
if ($groupRuntime -notmatch 'function\s+server\.weaponGroupRequestFire\s*\(') {
    Add-Issue "weaponGroupRequestFire API is missing"
}
if ($groupRuntime -notmatch 'function\s+server\.weaponGroupTick\s*\(') {
    Add-Issue "weaponGroupTick API is missing"
}
if ($weaponRuntime -notmatch 'function\s+server\.weaponRuntimeRegister\s*\(' -or
    $weaponRuntime -notmatch 'function\s+server\.weaponRuntimeInit\s*\(' -or
    $weaponRuntime -notmatch 'function\s+server\.weaponRuntimeRebuild\s*\(' -or
    $weaponRuntime -notmatch 'function\s+server\.weaponRuntimeCommandTick\s*\(' -or
    $weaponRuntime -notmatch 'function\s+server\.weaponRuntimeSimulationTick\s*\(' -or
    $weaponRuntime -notmatch 'function\s+server\.weaponRuntimeUpdate\s*\(' -or
    $weaponRuntime -notmatch 'function\s+server\.weaponRuntimePostUpdate\s*\(') {
    Add-Issue "unified weapon runtime lifecycle API is incomplete"
}
if ($entry -notmatch 'weapon/server/bootstrap\.lua' -or
    $entry -match '#include\s+"weapon/server/(?:common|behaviors|guided|slots)/' -or
    $weaponBootstrap -notmatch 'common/runtime/weapon_runtime\.lua' -or
    $weaponBootstrap -notmatch 'common/runtime/controller_registry\.lua' -or
    $weaponBootstrap -notmatch 'common/runtime/specialized_controller_adapters\.lua' -or
    $entry -notmatch 'server\.weaponRuntimeInit\(' -or
    $entry -notmatch 'server\.weaponRuntimeCommandTick\(' -or
    $entry -notmatch 'server\.weaponRuntimeSimulationTick\(' -or
    $entry -notmatch 'server\.weaponRuntimeUpdate\(' -or
    $entry -notmatch 'server\.weaponRuntimePostUpdate\(') {
    Add-Issue "battlecruiser entry does not delegate weapon lifecycle to the unified runtime"
}
$shipSchemaInclude = $shipCatalog.IndexOf('#include "schema.lua"')
$shipDefinitionInclude = $shipCatalog.IndexOf('#include "battlecruiser.lua"')
if ($shipSchemaInclude -lt 0 -or
    $shipDefinitionInclude -lt 0 -or
    $shipSchemaInclude -gt $shipDefinitionInclude -or
    $shipSchema -notmatch 'function\s+shipDefinitionRegister\s*\(' -or
    $shipDefinition -notmatch 'shipDefinitionRegister\s*\(\s*battlecruiserDefinition\s*\)') {
    Add-Issue "ship schema must be included before ship definitions so Teardown can execute registration"
}
if ($entry -notmatch 'ship/common/server/bootstrap\.lua' -or
    $entry -match '#include\s+"ship/common/server/(?!bootstrap\.lua)' -or
    $shipServerBootstrap -notmatch 'function\s+server\.shipServerInit\s*\(' -or
    $shipServerBootstrap -notmatch 'function\s+server\.shipServerTick\s*\(' -or
    $shipServerBootstrap -notmatch 'function\s+server\.shipServerUpdate\s*\(') {
    Add-Issue "ship entry does not delegate to the common ship runtime"
}
if ($clientEntry -notmatch 'ship/common/client/bootstrap\.lua' -or
    $clientEntry -notmatch 'weapon/client/bootstrap\.lua' -or
    $clientEntry -match '#include\s+"(?:ship|weapon)/client/(?!bootstrap\.lua)') {
    Add-Issue "client entry must compose only the ship and weapon client runtimes"
}
if ($serverShipContext -notmatch 'function\s+server\.shipContextGetBody\s*\(' -or
    $clientShipContext -notmatch 'function\s+client\.shipContextGetBody\s*\(' -or
    $frameworkSource -match '(?:server|client)\.(?:shipBody|defaultShipType)') {
    Add-Issue "framework modules still depend on implicit battlecruiser body/type globals"
}
if ($shipDefinition -notmatch 'flightProfile\s*=\s*\{' -or
    $shipDefinition -notmatch 'cameraProfile\s*=\s*\{' -or
    $shipDefinition -notmatch 'engineFx\s*=\s*\{' -or
    $shipSchema -notmatch 'function\s+shipDefinitionResolveMounts\s*\(') {
    Add-Issue "ship-specific flight, camera, engine, or mount data leaked out of the ship definition"
}
if ($serverRequests -notmatch 'function\s+server\.shipRequestAuthorize\s*\(' -or
    $serverRequests -notmatch 'function\s+server\.shipReceiveControlSnapshot\s*\(' -or
    $serverRequests -notmatch 'function\s+server\.shipRequestWeaponHold\s*\(' -or
    (Test-Path -LiteralPath (Join-Path $modRoot "script\ship\battlecruiser\server\registry\ship_registry_request.lua"))) {
    Add-Issue "network endpoints are not split across authorization, control, and weapon ownership"
}
if ($weaponRuntime -notmatch 'function\s+server\.weaponRuntimeClearCommands\s*\(' -or
    $weaponRuntime -notmatch 'component\.isActive' -or
    $specializedControllerAdapters -notmatch 'clearCommands\s*=\s*function') {
    Add-Issue "weapon runtime lacks atomic command reset or activity scheduling"
}
if ($configUi -match 'function\s+client\.weaponConfigUiIsOpen\s*\(' -or
    $localWeaponConfig -notmatch 'function\s+client\.weaponConfigRegistryIsOpen\s*\(' -or
    $configUi -notmatch 'function\s+client\.weaponConfigPanelIsOpen\s*\(') {
    Add-Issue "configuration UI open-state APIs still depend on include-order overrides"
}
$forbiddenEntryLifecycleCalls = @(
    "mainWeaponControlInit", "mainWeaponControlTick",
    "xSlotStateInit", "xSlotControlTick", "tachyonMuzzleLightInit", "tachyonMuzzleLightTick",
    "lSlotStateInit", "lSlotControlTick", "mSlotControlInit", "mSlotControlTick",
    "gSlotControlInit", "gSlotControlTick", "guidedProjectileRuntimeInit",
    "guidedProjectileRuntimeTick", "guidedProjectileMovementUpdate",
    "guidedProjectileColliderPostUpdate", "hSlotStateInit", "hSlotControlTick",
    "projectileManagerTick", "weaponGroupInit", "weaponGroupTick"
)
foreach ($apiName in $forbiddenEntryLifecycleCalls) {
    if ($entry -match [Regex]::Escape("server.$apiName(")) {
        Add-Issue "battlecruiser entry directly calls concrete weapon lifecycle API: $apiName"
    }
}
foreach ($componentId in @(
    "specialized.mainWeaponControl", "specialized.chargedRayVisual",
    "specialized.kineticArtillery", "specialized.guidedProjectile",
    "specialized.guidedSalvo", "specialized.torpedoSalvo",
    "specialized.strikeCraft", "weapon.group",
    "weapon.projectileManager"
)) {
    if ($specializedControllerAdapters -notmatch [Regex]::Escape('"' + $componentId + '"')) {
        Add-Issue "specialized weapon runtime adapter is missing component: $componentId"
    }
}
if ($controllerRegistry -notmatch 'function\s+server\.weaponControllerRegister\s*\(' -or
    $controllerRegistry -notmatch 'function\s+server\.weaponControllerResolve\s*\(' -or
    $groupRuntime -match 'function\s+_legacyFire\s*\(' -or
    $groupRuntime -notmatch 'server\.weaponControllerResolve\(weaponDef\)') {
    Add-Issue "specialized weapons are not routed through the controller registry"
}
if ($groupRuntime -notmatch 'function\s+server\.weaponGroupSetFireHeld\s*\(' -or
    $groupRuntime -notmatch '_pickReadyMounts\s*\(' -or
    $groupRuntime -notmatch 'salvoProfile' -or
    $groupRuntime -notmatch 'return\s+server\.weaponGroupRequestFire\(state\.groupId,\s*state\.heldRequest\)') {
    Add-Issue "weapon runtime does not support held fire and grouped salvos"
}
if ($loadoutApi -notmatch 'function\s+server\.shipWeaponApplyConfiguration\s*\(') {
    Add-Issue "shipWeaponApplyConfiguration API is missing"
}
if ($groupRuntime -match 'fallbackWeapon' -or
    $groupRuntime -notmatch 'resolved ship loadout is unavailable' -or
    $groupRuntime -notmatch 'resolved mount collection') {
    Add-Issue "weapon group runtime must consume resolved loadout mounts without default fallback"
}
if ($loadoutApi -notmatch 'server\.weaponRuntimeRebuild\(shipType\)' -or
    $loadoutApi -match 'server\.(?:xSlotState|lSlotState|mSlotControl|gSlotControl|hSlotState|guidedProjectileRuntime|projectileManager|tachyonMuzzleLight)(?:Init|ResetRuntime|Reset|Stop)\(') {
    Add-Issue "loadout rebuild bypasses the unified weapon runtime lifecycle"
}
if ($localWeaponConfig -notmatch 'level\.stellarisships\.weaponconfig' -or
    $localWeaponConfig -notmatch 'function\s+client\.weaponLocalConfigRead\s*\(' -or
    $localWeaponConfig -notmatch 'function\s+client\.weaponLocalConfigWrite\s*\(') {
    Add-Issue "client-local session weapon configuration source is incomplete"
}
if ($localWeaponConfig -match 'savegame\.mod|ServerCall|ClientCall') {
    Add-Issue "local UI configuration source must remain session-only and client-only"
}
if ($configurationBinding -notmatch 'function\s+client\.weaponConfigurationBindingInit\s*\(' -or
    $configurationBinding -notmatch 'state\.snapshot\s*=\s*client\.weaponLocalConfigRead' -or
    $configurationBinding -notmatch 'ServerCall\(\s*"server\.shipWeaponBindLocalConfiguration"') {
    Add-Issue "new ships do not snapshot and submit the local configuration on first drive"
}
if ($loadoutApi -notmatch 'function\s+server\.shipWeaponBindLocalConfiguration\s*\(' -or
    $loadoutApi -notmatch 'server\.weaponLocalConfigurationBound' -or
    $loadoutApi -notmatch 'IsPlayerVehicleDriver') {
    Add-Issue "server does not validate and lock the first-driver configuration binding"
}
if ($loadoutRuntime -match '_spawnTemplates|_readSpawnTemplate' -or
    $loadoutApi -match 'shipWeaponSetSpawnTemplate|shipWeaponSyncSpawnTemplate') {
    Add-Issue "server-side UI spawn-template storage was not removed"
}
if ($loadoutApi -notmatch 'function\s+server\.shipWeaponSyncConfiguration\s*\(') {
    Add-Issue "server-to-client loadout synchronization is missing"
}
if ($client -notmatch 'common/state/weapon_loadout\.lua') {
    Add-Issue "client weapon loadout state is not included"
}
if ($clientLoadout -notmatch 'shipDefinitionFindConfiguration' -or
    $clientLoadout -notmatch 'defaultLoadout') {
    Add-Issue "client weapon defaults must derive from the selected ship definition"
}
if ($clientRegistry -notmatch 'ServerCall\("server\.shipRequestWeaponConfiguration"') {
    Add-Issue "client cannot request a missed loadout synchronization"
}
if ($serverRequests -notmatch 'function\s+server\.shipRequestWeaponConfiguration\s*\(') {
    Add-Issue "server loadout resynchronization request is missing"
}
if ($clientRegistry -notmatch 'function\s+client\.shipRequestWeaponHold\s*\(' -or
    $serverRequests -notmatch 'function\s+server\.shipRequestWeaponHold\s*\(' -or
    $mainWeaponInput -notmatch 'InputDown\("lmb"\)' -or
    $mainWeaponInput -notmatch '_releaseHeldWeapon') {
    Add-Issue "all weapon groups must use server-owned hold-to-refire input"
}
if ($guidedTargeting -notmatch 'shipCamera\.viewMode\s*==\s*"front"' -or
    $clientMain -notmatch '(?s)guidedTargetingTick\(dt\).*?mainWeaponInputTick\(dt\)') {
    Add-Issue "guided and strike-craft target locks do not follow the front camera before fire input"
}
if ($client -notmatch 'generic_raycast_fx\.lua') {
    Add-Issue "generic raycast client FX is not included"
}
if ($client -notmatch 'effects/engine_thruster_fx\.lua' -or
    $client -notmatch 'engineThrusterFxInit\(\)' -or
    $client -notmatch 'engineThrusterFxTick\(dt\)' -or
    $client -notmatch 'engineThrusterFxRender\(\)' -or
    $engineThrusterFx -notmatch 'FindShapes\(tag,\s*false\)' -or
    $engineThrusterFx -notmatch 'GetBodyVelocity\(body\)' -or
    $engineThrusterFx -notmatch 'math\.exp\(-response\s*\*\s*frameDt\)' -or
    $engineThrusterFx -notmatch 'SpawnParticle\(' -or
    $engineThrusterFx -notmatch 'DrawSprite\(') {
    Add-Issue "battlecruiser engine combustion and smooth velocity-driven exhaust are incomplete"
}
if ($arcChargingFx -notmatch 'focusedArcChargingFxRender' -or
    $arcChargingFx -notmatch '_focusedArcDrawBridge' -or
    $xSlotChargingFx -notmatch '(?s)definition\.family\s*~=\s*"energy_lance".*emittersByShip' -or
    $xSlotMuzzleLight -notmatch 'arcMuzzleLightLeft' -or
    $xSlotMuzzleLight -notmatch 'arcMuzzleLightRight' -or
    $xSlotMuzzleLight -notmatch '_tachyonLightOverloadWave') {
    Add-Issue "Focused Arc Emitter charging FX is not isolated into three unstable light nodes"
}
if (Test-Path -LiteralPath (Join-Path $modRoot "script\weapon_configurator.lua") -PathType Leaf) {
    Add-Issue "standalone weapon_configurator.lua must be deleted; config UI is now in main.lua"
}
if ($client -match 'config_ui/weapon_config_ui\.lua') {
    Add-Issue "client.lua must not include the config UI; it is hosted by main.lua"
}
if ($globalMain -notmatch '(?m)^#version\s+2\s*$' -or
    $globalMain -notmatch '#include\s+"script/weapon/client/config_ui/weapon_config_ui\.lua"') {
    Add-Issue "main.lua does not host the weapon configuration UI"
}
if ($globalMain -notmatch 'function\s+client\.init\(\)[\s\S]*weaponConfigUiSetOpen\(false\)') {
    Add-Issue "main.lua must call weaponConfigUiSetOpen(false) during init"
}
if ($globalMain -notmatch 'function\s+client\.tick\s*\(dt\)[\s\S]*weaponConfigUiTick\(dt\)') {
    Add-Issue "main.lua must call weaponConfigUiTick(dt) on each frame"
}
if ($globalMain -notmatch 'function\s+client\.draw\s*\(\)[\s\S]*weaponConfigUiDraw\(\)') {
    Add-Issue "main.lua must call weaponConfigUiDraw() on each frame"
}
if ($mainXml -match 'weapon_configurator\.lua') {
    Add-Issue "main.xml must not reference the deleted weapon_configurator.lua"
}
if ($configUi -notmatch 'InputPressed\("t"\)' -or
    $configUi -notmatch 'weaponConfiguratorSaveTemplate') {
    Add-Issue "weapon configuration UI toggle/apply flow is incomplete"
}
if ($configUi -match 'GetPlayerVehicle|client\.shipBody') {
    Add-Issue "weapon configuration UI is still coupled to a spawned ship"
}
if ($configUi -notmatch 'function\s+client\.weaponConfiguratorSaveTemplate\s*\(') {
    Add-Issue "weapon configuration UI does not define the local save template function"
}
if ($configUi -notmatch 'client\.weaponLocalConfigRead' -or
    $configUi -notmatch 'client\.weaponLocalConfigWrite') {
    Add-Issue "weapon configuration UI does not use the single local registry source"
}
if ($configUi -notmatch 'local function _drawFooter\s*\(' -or
    $configUi -notmatch 'configuration\s*=\s*_drawFooter\s*\(' -or
    $configUi -notmatch 'local function _canonicalLoadout\s*\(' -or
    $configUi -notmatch 'local canonicalLoadout\s*=\s*_canonicalLoadout' -or
    $configUi -match 'pendingHeaderFooterAction') {
    Add-Issue "weapon configuration UI must use the shared footer actions and canonical loadout mapping"
}
if ($groupRuntime -notmatch 'client\.updateWeaponGroupHudState' -or
    $mainWeaponHud -notmatch 'function\s+client\.updateWeaponGroupHudState\s*\(') {
    Add-Issue "generic weapon charge/cooldown HUD synchronization is missing"
}
if ($configUi -match 'shipWeaponApplyConfiguration') {
    Add-Issue "config UI must not directly apply configuration to a spawned ship"
}
if ($configUi -match 'ServerCall|ClientCall') {
    Add-Issue "config UI must not communicate with the server"
}
if ($client -notmatch 'config/weapon_configuration_binding\.lua' -or
    $client -notmatch 'weaponConfigurationBindingInit\(context\.shipType,\s*context\.bodyId\)' -or
    $client -notmatch 'weaponConfigurationBindingTick\(dt\)') {
    Add-Issue "battlecruiser client does not run the local configuration binding"
}
if ($configUi -notmatch 'definition\.englishName\s+or\s+weaponType') {
    Add-Issue "weapon configuration UI has no English-name fallback"
}
if ([string]$weaponSourceById.devastatorTorpedoes -notmatch '(?s)weaponDefineRocket\(\{.*?weaponType\s*=\s*"devastatorTorpedoes"' -or
    $weaponSchema -notmatch 'behaviorType\s*=\s*"rocketProjectile"') {
    Add-Issue "Devastator Torpedoes must use the unguided rocket behavior"
}
if ([string]$weaponSourceById.devastatorTorpedoes -match 'controllerType\s*=') {
    Add-Issue "Devastator Torpedoes must use the generic rocket controller"
}
if ([string]$weaponSourceById.devastatorTorpedoes -notmatch '(?s)weaponType\s*=\s*"devastatorTorpedoes".*?ignoreGravity\s*=\s*true.*?projectileProfile\s*=\s*\{.*?ignoreGravity\s*=\s*true' -or
    $guidedRuntime -notmatch 'SetBodyDynamic\(bodyId,\s*not ignoreGravity\)' -or
    $guidedMovement -notmatch 'projectile\.ignoreGravity' -or
    $guidedMovement -notmatch 'SetBodyTransform\(' -or
    $guidedCollider -notmatch 'projectile\.kinematicVelocity') {
    Add-Issue "Devastator Torpedoes do not have a complete gravity-free flight path"
}
if ($weaponSchema -notmatch '(?s)function weaponDefineRocket.*?targetingMode\s*=\s*"forward"') {
    Add-Issue "unguided rockets must use forward targeting"
}
if ([string]$weaponSourceById.neutronLauncher -notmatch '(?s)weaponDefineProjectile\(\{.*?weaponType\s*=\s*"neutronLauncher".*?fxProfile\s*=\s*"neutronProjectile".*?targetingMode\s*=\s*"forward"') {
    Add-Issue "Neutron Launcher must be a single forward, non-guided projectile"
}
if ($projectileVisual -notmatch '(?s)local function _updatePlasmaProjectile.*?projectile\.fxColor.*?_drawBillboard' -or
    $projectileVisual -notmatch '(?s)local function _updateGigaCannonProjectile.*?_pointLight.*?0\.50,\s*0\.08,\s*1\.0' -or
    $projectileVisual -notmatch '(?s)local function _updateNeutronProjectile.*?local tint = projectile\.fxColor.*?_drawDirectionalSprite') {
    Add-Issue "plasma/giga-cannon/neutron projectile visuals are missing their dedicated color paths"
}
if ([string]$weaponSourceById.largeStormfireAutocannon -notmatch '(?s)cooldown\s*=\s*0\.0.*?maxRange\s*=\s*220\.0' -or
    [string]$weaponSourceById.mediumStormfireAutocannon -notmatch '(?s)cooldown\s*=\s*0\.0.*?maxRange\s*=\s*180\.0') {
    Add-Issue "Stormfire Autocannons must remain short-range rapid-fire weapons"
}
if ([string]$weaponSourceById.largeStormfireAutocannon -notmatch '(?s)heatPerShot\s*=\s*4\.0.*?heatDissipationPerSecond\s*=\s*32\.0.*?overheatThreshold\s*=\s*100\.0.*?recoverThreshold\s*=\s*45\.0.*?interval\s*=\s*0\.06' -or
    [string]$weaponSourceById.mediumStormfireAutocannon -notmatch '(?s)heatPerShot\s*=\s*4\.0.*?heatDissipationPerSecond\s*=\s*32\.0.*?overheatThreshold\s*=\s*100\.0.*?recoverThreshold\s*=\s*45\.0.*?interval\s*=\s*0\.06') {
    Add-Issue "Stormfire Autocannons do not match the escort P-slot heat and fire-rate profile"
}
if ($groupRuntime -notmatch 'mount\.overheated' -or
    $groupRuntime -notmatch 'heatDissipationPerSecond' -or
    $groupRuntime -notmatch 'recoverThreshold' -or
    $mainWeaponHud -notmatch 'phase\s*==\s*"heat"' -or
    $mainWeaponHud -notmatch 'phase\s*==\s*"overheated"') {
    Add-Issue "generic weapon runtime/HUD does not implement heat and overheat recovery"
}
if ($crosshair -notmatch 'weaponConfigUiIsOpen') {
    Add-Issue "crosshair is not hidden while the independent UI is open"
}
if ([string]$weaponSourceById.focusedArcEmitter -notmatch '(?s)bodyFix\s*=\s*1\.0.*?chargeDuration\s*=\s*0\.50.*?controllerType\s*=\s*"chargedRay"' -or
    [string]$weaponSourceById.tachyonLance -notmatch 'weaponClass\s*=\s*"chargedRay"' -or
    [string]$weaponSourceById.perditionBeam -notmatch 'weaponClass\s*=\s*"chargedRay"' -or
    $groupRuntime -notmatch 'mode\s*==\s*"charged_release"' -or
    $groupRuntime -notmatch 'weaponClass\s*or\s+""\)\s*==\s*"chargedRay"') {
    Add-Issue "Focused Arc Emitter does not share the Tachyon Lance charge/fire lifecycle"
}
if ($targetingPolicy -notmatch 'function\s+weaponTargetingPolicy\.requiresTargetLock\s*\(' -or
    $targetingPolicy -notmatch 'requiresTargetLock\s*~=\s*nil' -or
    $weaponSchema -notmatch 'requiresTargetLock\s*=\s*tostring\(definition\.targetingMode' -or
    $weaponSchema -match 'function\s+weaponDefinitionRequiresTargetLock\s*\(' -or
    $weaponBootstrap -notmatch '#include\s+"\.\./common/targeting_policy\.lua"' -or
    $clientWeaponBootstrap -notmatch '#include\s+"\.\./common/targeting_policy\.lua"' -or
    $mainWeaponInput -notmatch '_requiresTargetLock\s*\(' -or
    $mainWeaponInput -match 'isChargedRay\s+and\s+fireMode\s*==\s*"lock"' -or
    $groupRuntime -notmatch '_weaponGroupRequiresTargetLock\s*\(weaponDefinition\)' -or
    $groupRuntime -match 'weaponDefinitionRequiresTargetLock') {
    Add-Issue "charged-ray lock policy must be data-driven and shared by client/server"
}
if ($groupRuntime -notmatch 'local\s+function\s+_weaponGroupValidateRequest\s*\(' -or
    $groupRuntime -notmatch '(?s)function\s+server\.weaponGroupSetFireHeld.*?_weaponGroupValidateRequest' -or
    $groupRuntime -notmatch '(?s)function\s+server\.weaponGroupRequestFire.*?_weaponGroupValidateRequest') {
    Add-Issue "all weapon hold and fire requests must use the shared server validation boundary"
}
if ($weaponBootstrap -notmatch 'common/runtime/charged_ray_visual\.lua' -or
    $chargedRayVisual -notmatch 'function\s+server\.chargedRayVisualRegister\s*\(' -or
    $chargedRayVisual -notmatch 'function\s+server\.chargedRayVisualBeginCharge\s*\(' -or
    $chargedRayVisual -notmatch 'function\s+server\.chargedRayVisualTrigger\s*\(' -or
    $chargedRayVisual -notmatch 'function\s+server\.chargedRayVisualStopAll\s*\(' -or
    $groupRuntime -match 'tachyonMuzzleLight(?:BeginCharge|Stop)' -or
    $raycastBehavior -match 'tachyonMuzzleLightTrigger' -or
    $specializedControllerAdapters -match 'tachyonMuzzleLight(?:Init|Tick|Stop)') {
    Add-Issue "charged-ray runtime must select visual profiles through the shared visual service"
}
if ($xSlotMuzzleLight -notmatch 'weaponTypes\.tachyonLance\s*=\s*true' -or
    $xSlotMuzzleLight -notmatch 'weaponTypes\.focusedArcEmitter\s*=\s*true' -or
    $xSlotMuzzleLight -notmatch 'function\s+_tachyonLightResolveHandle\s*\(' -or
    $xSlotMuzzleLight -notmatch 'FindLight\(tag,\s*false\)') {
    Add-Issue "charged X weapons do not preserve and reacquire the XML muzzle light"
}
if ($client -notmatch '(?s)weapon_sound_catalog\.lua.*?sound_service\.lua' -or
    $soundService -notmatch 'function\s+client\.playWeaponSound\s*\(' -or
    $soundService -notmatch 'client\.weaponSoundCatalog') {
    Add-Issue "per-weapon sound catalog is not loaded before the generic sound service"
}
if ($soundService -notmatch 'LoadLoop\("MOD/sound/missile_loop\.ogg"\)' -or
    $missileVisual -notmatch 'playMissileLoopSound') {
    Add-Issue "guided weapon flight loop is not connected"
}
if ($projectileManager -notmatch 'playKineticArtilleryFireSound",\s*weaponType' -or
    $projectileManager -notmatch 'playKineticArtilleryHitSound",\s*weaponType' -or
    $guidedRuntime -notmatch '(?s)playMissileFireSound".*?cfg\.weaponType' -or
    $guidedCollider -notmatch 'guidedProjectilePlayImpactSound\(projectile\.weaponType' -or
    $raycastBehavior -notmatch 'client\.playWeaponSound",\s*context\.weaponType' -or
    $hSlotControl -notmatch '(?s)client\.playWeaponSound".*?craft\.weaponType') {
    Add-Issue "one or more weapon controllers do not propagate weaponType to the sound service"
}
if ([string]$weaponSourceById.gigaCannon -notmatch '(?s)mountProfile\s*=\s*"xSpinal".*?salvoProfile\s*=\s*\{\s*groupSize\s*=\s*1,\s*sequence\s*=\s*"sequential"') {
    Add-Issue "Giga Cannon must use Tachyon hardpoints and fire one barrel at a time"
}
if ([string]$weaponSourceById.gigaCannon -notmatch '(?s)cooldown\s*=\s*3\.5.*?maxRange\s*=\s*750\.0.*?projectileSpeed\s*=\s*560\.0' -or
    $projectileVisual -notmatch '(?s)local function _updateGigaCannonProjectile.*?_emitDistanceEvents.*?"nextTrailDistance".*?function\(p, eventPos\)') {
    Add-Issue "Giga Cannon speed, cooldown, or dedicated trail rendering is missing"
}
if ([string]$weaponSourceById.neutronLauncher -notmatch '(?s)cooldown\s*=\s*4\.5.*?maxRange\s*=\s*1150\.0.*?targetingMode\s*=\s*"forward".*?mountProfile\s*=\s*"gNeutron".*?groupSize\s*=\s*1.*?aimControlMode\s*=\s*"camera_limited"') {
    Add-Issue "Neutron Launcher must rotate through four X-aligned mounts, support tilt fire, and use a 4.5s cooldown"
}
$gRocketBlock = [Regex]::Match($ship, '(?s)gRocket\s*=\s*\{(.*?)\n\s*\},\s*\n\s*gNeutron\s*=').Groups[1].Value
$gNeutronBlock = [Regex]::Match($ship, '(?s)gNeutron\s*=\s*\{(.*?)\n\s*\},\s*\n\s*hHangar\s*=').Groups[1].Value
$rocketFrontMountPattern = 'firePosOffset\s*=\s*\{\s*x\s*=\s*0,\s*y\s*=\s*0,\s*z\s*=\s*-4\.8\s*\}.*?fireDirRelative\s*=\s*\{\s*x\s*=\s*0,\s*y\s*=\s*0,\s*z\s*=\s*-1\s*\}'
$neutronFrontMountPattern = 'firePosOffset\s*=\s*\{\s*x\s*=\s*0,\s*y\s*=\s*0,\s*z\s*=\s*-4\s*\}.*?fireDirRelative\s*=\s*\{\s*x\s*=\s*0,\s*y\s*=\s*0,\s*z\s*=\s*-1\s*\}'
if ([Regex]::Matches($gRocketBlock, $rocketFrontMountPattern).Count -ne 4 -or
    [string]$weaponSourceById.devastatorTorpedoes -notmatch '(?s)maxRange\s*=\s*1200\.0.*?cruiseSpeed\s*=\s*28\.0') {
    Add-Issue "Devastator Torpedoes must use four X-aligned forward mounts"
}
if ([Regex]::Matches($gNeutronBlock, $neutronFrontMountPattern).Count -ne 4) {
    Add-Issue "Neutron Launcher must expose four X-aligned forward mounts"
}
if ([string]$weaponSourceById.phaseDisruptor -notmatch 'suppressShipExplosion\s*=\s*true' -or
    $raycastBehavior -notmatch 'suppressPhysicalExplosion\s*=\s*definition\.suppressShipExplosion\s*==\s*true' -or
    $raycastBehavior -notmatch 'not\s+suppressPhysicalExplosion') {
    Add-Issue "Phase Disruptor must not create physical explosions on registered ships"
}
if ([string]$weaponSourceById.perditionBeam -notmatch 'behaviorType\s*=\s*"infernoRaycast"' -or
    [string]$weaponSourceById.perditionBeam -match 'environmentExplosionSize\s*=' -or
    $infernoRaycastBehavior -notmatch 'weaponBehaviorRegister\("infernoRaycast"' -or
    $infernoRaycastBehavior -notmatch 'weaponDamageApplyRolledToShip' -or
    $infernoRaycastBehavior -notmatch '_applyShipPulse' -or
    $infernoRaycastBehavior -notmatch 'QueryAabbBodies' -or
    $infernoRaycastBehavior -notmatch 'Explosion\(endpoint, 4\.0\)' -or
    $infernoRaycastBehavior -match '(?s)if ray\.hitRegisteredShip then.*?(?:Explosion|MakeHole|AddHeat|PaintRGBA|SpawnFire|ApplyBodyImpulse).*?elseif ray\.hit' -or
    $raycastCommon -notmatch 'function\s+server\.weaponRaycastResolve\s*\(' -or
    $raycastBehavior -notmatch 'server\.weaponRaycastResolve\(context\)') {
    Add-Issue "Perdition Beam must use isolated inferno raycasting with safe ship damage and capped world destruction"
}
if ([string]$weaponSourceById.perditionBeam -notmatch 'infernoWorldProfile\s*=\s*\{' -or
    [string]$weaponSourceById.perditionBeam -notmatch 'muzzleLightProfile\s*=\s*""' -or
    [string]$weaponSourceById.perditionBeam -notmatch 'hudOwner\s*=\s*"weaponGroup"' -or
    $infernoRaycastBehavior -notmatch 'infernoWorldProfile' -or
    $infernoRaycastBehavior -notmatch 'event\.profile' -or
    $infernoRaycastBehavior -notmatch 'infernoPulseMaxRadius') {
    Add-Issue "Perdition Beam world effects, HUD ownership, and aftershock radius must be profile-driven"
}
if ([string]$weaponSourceById.perditionBeam -notmatch 'iconPath\s*=\s*"MOD/gfx/ui/weapon_icons/stellaris/perdition_beam\.png"') {
    Add-Issue "Perdition Beam must use the official Stellaris Perdition icon"
}
if ($weaponSoundCatalog -notmatch 'perdition_beam_windup_01\.ogg' -or
    $weaponSoundCatalog -notmatch 'perdition_beam_windup_02\.ogg' -or
    $weaponSoundCatalog -notmatch 'perdition_beam_fire_01\.ogg' -or
    $weaponSoundCatalog -notmatch 'perdition_beam_fire_02\.ogg' -or
    $weaponSoundCatalog -notmatch 'perdition_beam_fire_03\.ogg' -or
    $weaponSoundCatalog -notmatch 'distance_perdition_beam_fire_01\.ogg' -or
    $weaponSoundCatalog -notmatch 'distance_perdition_beam_fire_02\.ogg' -or
    $weaponSoundCatalog -notmatch 'distance_perdition_beam_fire_03\.ogg' -or
    $weaponSoundCatalog -match 'titan_laser_(?:windup|fire)' -or
    $soundService -notmatch '_randomPick\(handles\)') {
    Add-Issue "Perdition Beam must use its official layered Stellaris sound catalog"
}
$perditionSoundNames = @(
    "perdition_beam_windup_01.ogg", "perdition_beam_windup_02.ogg",
    "perdition_beam_fire_01.ogg", "perdition_beam_fire_02.ogg",
    "perdition_beam_fire_03.ogg", "perdition_beam_hit_01.ogg",
    "distance_perdition_beam_fire_01.ogg",
    "distance_perdition_beam_fire_02.ogg",
    "distance_perdition_beam_fire_03.ogg",
    "distance_perdition_beam_hit_01.ogg"
)
foreach ($soundName in $perditionSoundNames) {
    if (-not (Test-Path -LiteralPath (Join-Path $modRoot ("sound\" + $soundName)) -PathType Leaf)) {
        Add-Issue "official Perdition Beam sound is missing: $soundName"
    }
}
if ($weaponDamageRuntime -notmatch 'function\s+server\.weaponDamageApplyRolledToShip\s*\(' -or
    $chargedRayBeamRenderer -notmatch 'QuatAlignXZ\(' -or
    $perditionBeamFx -notmatch 'width = 96\.0' -or
    $perditionBeamFx -notmatch 'width = 11\.0' -or
    $perditionImpactFx -notmatch 'TransformToLocalPoint' -or
    $perditionImpactFx -notmatch 'ShakeCamera' -or
    $perditionImpactFx -notmatch 'while #impacts > 6' -or
    $client -notmatch 'perdition_beam/effects/beam_fx\.lua' -or
    $client -notmatch 'perdition_beam/effects/impact_fx\.lua') {
    Add-Issue "Perdition Beam needs bounded layered beam and moving-ship impact FX"
}
if ($mainWeaponHud -notmatch 'weaponDefinition\.hudOwner' -or
    $mainWeaponHud -match 'local usesGenericRuntime\s*=\s*currentMode\s*==\s*"tSlot"' -or
    $tSlotRenderState -notmatch 'tSlotRenderEventQueueByShip' -or
    $tSlotRenderState -notmatch 'function\s+client\.tSlotRenderGetEvents\s*\(' -or
    $tSlotRenderState -notmatch 'maxTSlotRenderEvents') {
    Add-Issue "HUD ownership and T-slot render events must be capability-based and queue-bounded"
}
if ($clientWeaponBootstrap -notmatch '#include\s+"common/hud/radial_weapon_wheel\.lua"' -or
    $mainWeaponHud -notmatch 'client\.radialWeaponWheelDraw\s*\(' -or
    $mainWeaponHud -notmatch 'client\.getShipWeaponType\s*\(' -or
    $mainWeaponHud -notmatch 'candidate\s*~=\s*nil' -or
    $radialWeaponWheel -notmatch 'function\s+client\.radialWeaponWheelCreateState\s*\(' -or
    $radialWeaponWheel -notmatch 'function\s+client\.radialWeaponWheelUpdate\s*\(' -or
    $radialWeaponWheel -notmatch 'function\s+client\.radialWeaponWheelDraw\s*\(' -or
    $radialWeaponWheel -notmatch 'UiImageBox\(' -or
    $radialWeaponWheel -notmatch 'UiColor\(1\.0,\s*1\.0,\s*1\.0,\s*alpha\)' -or
    $radialWeaponWheel -notmatch 'math\.exp\(') {
    Add-Issue "main weapon HUD must use the shared smooth radial weapon wheel"
}
if ([string]$weaponSourceById.phaseDisruptor -notmatch 'fxProfile\s*=\s*"arcBeam"' -or
    $genericRaycastFx -notmatch 'arcBeam\s*=\s*\{\s*color\s*=\s*\{\s*0\.18,\s*1\.0,\s*0\.32\s*\}') {
    Add-Issue "Phase Disruptor arc beam must use the green FX profile"
}
if ([string]$weaponSourceById.focusedArcEmitter -notmatch '(?s)fxProfile\s*=\s*"focusedArcBeam".*?chargeDuration\s*=\s*0\.50' -or
    $genericRaycastFx -notmatch 'focusedArcBeam\s*=\s*\{\s*color\s*=\s*\{\s*0\.72,\s*0\.22,\s*1\.0\s*\}' -or
    $xSlotControl -notmatch '(?s)tostring\(weaponType or ""\) == "focusedArcEmitter".*focusedArcBeam' -or
    $client -notmatch 'focused_arc_emitter/effects/charging_fx\.lua' -or
    $arcChargingFx -notmatch 'focusedArcChargingFxRender' -or
    $xSlotChargingFx -notmatch '(?s)definition\.family\s*~=\s*"energy_lance".*?_clearEffectsByShip' -or
    $xSlotChargingFx -match 'ParticleColor\(0\.82,\s*0\.24,\s*1\.0' -or
    $xSlotMuzzleLight -notmatch 'SetLightColor\(center,\s*0\.72,\s*0\.22,\s*1\.0\)') {
    Add-Issue "Focused Arc Emitter must use independent purple charge/beam/light FX"
}
if ([string]$weaponSourceById.largeGammaLaser -notmatch 'fxProfile\s*=\s*"gammaBeam"' -or
    [string]$weaponSourceById.mediumGammaLaser -notmatch 'fxProfile\s*=\s*"gammaBeam"' -or
    $genericRaycastFx -notmatch 'gammaBeam\s*=\s*\{(?s:.*?)color\s*=\s*\{\s*1\.0,\s*0\.38,\s*0\.05\s*\}' -or
    $gammaLaserFx -notmatch 'gammaLarge\s*=\s*\{' -or
    $gammaLaserFx -notmatch 'gammaMedium\s*=\s*\{' -or
    $gammaLaserFx -notmatch 'client\.gammaLaserDrawBeam' -or
    $gammaLaserFx -match 'helix|spiral') {
    Add-Issue "Gamma Lasers must use the dedicated straight three-layer orange beam renderer"
}
if ($raycastBehavior -notmatch 'client\.playProjectileShieldImpactFx' -or
    $raycastBehavior -notmatch '_resolveShieldEndpoint' -or
    $genericRaycastFx -notmatch '_spawnImpactParticles\s*\(' -or
    $genericRaycastFx -notmatch 'didHit\s*=\s*math\.floor') {
    Add-Issue "generic raycast weapons do not provide body/shield impact feedback"
}
$shieldHexAsset = Join-Path $modRoot "gfx\weapons\common\hex_soft.png"
$hexBuilder = [Regex]::Match($shieldHitFx, '(?s)local function _buildHexCells.*?(?=local function _hexEnvelope)').Value
$hexRenderer = [Regex]::Match($shieldHitFx, '(?s)local function _drawShieldBurst.*?(?=function client\.shieldHitFxInit)').Value
if (-not (Test-Path -LiteralPath $shieldHexAsset -PathType Leaf) -or
    $shieldHitFx -notmatch 'maxRing\s*=\s*4' -or
    $hexBuilder -notmatch 'for\s+ring\s*=\s*0,\s*ShieldConfig\.maxRing' -or
    $hexBuilder -match 'random|noise|probability' -or
    $hexRenderer -notmatch 'DrawSprite\s*\(' -or
    $hexRenderer -match 'SpawnParticle\s*\(' -or
    $shieldHitFx -notmatch 'LoadSprite\("MOD/gfx/weapons/common/hex_soft\.png"\)' -or
    $shieldHitFx -notmatch 'sparkCount\s*=\s*6' -or
    $shieldHitFx -notmatch 'maxActiveBursts\s*=\s*3' -or
    $client -notmatch 'client\.shieldHitFxInit\(\)') {
    Add-Issue "shield impacts must use a fixed five-layer hex sprite with bounded sparks and burst state"
}
if ($ship -notmatch '(?s)lLaser\s*=\s*\{.*?x\s*=\s*3\.3.*?z\s*=\s*-2\.6.*?x\s*=\s*-3\.3' -or
    $ship -notmatch '(?s)lEnergy\s*=\s*\{.*?x\s*=\s*3\.5.*?z\s*=\s*-3\.2.*?x\s*=\s*-3\.5' -or
    $ship -notmatch '(?s)lKinetic\s*=\s*\{.*?x\s*=\s*3\.8.*?z\s*=\s*-3\.4.*?x\s*=\s*-3\.8' -or
    $ship -notmatch '(?s)lAutocannon\s*=\s*\{.*?x\s*=\s*3\.3.*?z\s*=\s*-2\.4.*?x\s*=\s*-3\.3') {
    Add-Issue "battlecruiser L-slot hardpoints are not centered and retracted consistently"
}
if ($ship -notmatch '(?s)mLaser\s*=\s*\{.*?x\s*=\s*2\.8.*?x\s*=\s*-2\.8' -or
    $ship -notmatch '(?s)mEnergy\s*=\s*\{.*?x\s*=\s*3\.2.*?x\s*=\s*-3\.2' -or
    $ship -notmatch '(?s)mKinetic\s*=\s*\{.*?x\s*=\s*3\.8.*?x\s*=\s*-3\.8' -or
    $ship -notmatch '(?s)mAutocannon\s*=\s*\{.*?x\s*=\s*3\.5.*?x\s*=\s*-3\.5' -or
    $ship -notmatch '(?s)mSwarmer\s*=\s*\{.*?x\s*=\s*0\.3.*?x\s*=\s*-0\.3') {
    Add-Issue "non-Swarmer M-slot hardpoints are not tightened or Swarmer mounts moved unexpectedly"
}
if ([string]$weaponSourceById.mediumStormfireAutocannon -notmatch '(?s)mountProfile\s*=\s*"mAutocannon".*?groupSize\s*=\s*4.*?sequence\s*=\s*"grouped"' -or
    [string]$weaponSourceById.mediumGaussCannon -notmatch '(?s)mountProfile\s*=\s*"mKinetic".*?groupSize\s*=\s*2.*?sequence\s*=\s*"grouped"') {
    Add-Issue "M Stormfire must fire all four mounts while M Gauss remains two grouped pairs"
}
foreach ($heatWeapon in @("largePlasmaCannon", "mediumPlasmaCannon", "largeGaussCannon", "mediumGaussCannon")) {
    if ([string]$weaponSourceById[$heatWeapon] -notmatch "(?s)cooldown\s*=\s*0\.0.*?heatPerShot\s*=\s*12\.0.*?heatDissipationPerSecond\s*=\s*10\.0.*?overheatThreshold\s*=\s*100\.0.*?recoverThreshold\s*=\s*60\.0.*?interval\s*=\s*0\.10") {
        Add-Issue "Plasma/Gauss weapon $heatWeapon does not use the shared heat cycle"
    }
}
foreach ($profile in @(
    "xSpinal", "lLaser", "lEnergy", "lKinetic", "lAutocannon",
    "mLaser", "mEnergy", "mKinetic", "mAutocannon", "mSwarmer",
    "gRocket", "gNeutron", "hHangar"
)) {
    if ($ship -notmatch "(?m)^\s*$profile\s*=\s*\{") {
        Add-Issue "battlecruiser mount profile is missing: $profile"
    }
}
if ($loadoutRuntime -notmatch 'weaponMountProfiles' -or
    $loadoutRuntime -notmatch 'weaponDefinition\.mountProfile') {
    Add-Issue "loadout resolver does not select mounts by weapon profile"
}
if ($titanDefinition -notmatch '(?s)groupId\s*=\s*"lSlot"\s*,\s*slotType\s*=\s*"L"\s*,\s*count\s*=\s*4\s*,\s*salvoGroupSize\s*=\s*4' -or
    $titanDefinition -notmatch '(?s)groupId\s*=\s*"lSlot2"\s*,\s*slotType\s*=\s*"L"\s*,\s*count\s*=\s*4\s*,\s*salvoGroupSize\s*=\s*4' -or
    $titanMounts -notmatch '(?s)lTitanic\s*=\s*\{.*?x\s*=\s*6\s*,\s*y\s*=\s*0\s*,\s*z\s*=\s*-4.*?x\s*=\s*-6\s*,\s*y\s*=\s*0\s*,\s*z\s*=\s*-4.*?x\s*=\s*0\s*,\s*y\s*=\s*6\s*,\s*z\s*=\s*-4.*?x\s*=\s*0\s*,\s*y\s*=\s*-6\s*,\s*z\s*=\s*-4' -or
    $titanMounts -notmatch '(?s)lTitanic2\s*=\s*\{.*?x\s*=\s*6\s*,\s*y\s*=\s*0\s*,\s*z\s*=\s*-1.*?x\s*=\s*-6\s*,\s*y\s*=\s*0\s*,\s*z\s*=\s*-1.*?x\s*=\s*0\s*,\s*y\s*=\s*6\s*,\s*z\s*=\s*-1.*?x\s*=\s*0\s*,\s*y\s*=\s*-6\s*,\s*z\s*=\s*-1' -or
    $shipSchema -notmatch 'function\s+shipDefinitionNormalizeSalvoGroupSize\s*\(' -or
    $loadoutRuntime -notmatch 'shipDefinitionNormalizeSalvoGroupSize' -or
    $groupRuntime -notmatch 'salvoGroupSize\s*=\s*\(group\s+or\s+\{\}\)\.salvoGroupSize' -or
    $groupRuntime -match 'tonumber\(state\.salvoGroupSize\)') {
    Add-Issue "Titan L batteries must preserve the original four-mount layout and fire each group as one salvo"
}
if ($shipDefinition -match '(?m)^\s*mounts\s*=' -or
    $shipDefinition -match '(?m)^\s*[xlmgh]Slots\s*=' -or
    $shipDefinition -notmatch 'weaponMountProfiles\s*=\s*shipMountProfileData\.enigmaticCruiser' -or
    $loadoutRuntime -match 'configuration\.mounts') {
    Add-Issue "battlecruiser mount coordinates must have one canonical profile source"
}
if ($behaviorCommon -notmatch 'aimControlMode.*forward_converge' -or
    $behaviorCommon -notmatch 'QueryRaycast\(rayOrigin,\s*forward,\s*range\)') {
    Add-Issue "forward weapons do not converge on nearby crosshair obstacles"
}

if ($entry -notmatch 'net/server_sync_limiter\.lua' -or
    $entry -notmatch 'net/network_debug\.lua' -or
    $clientMain -notmatch 'net/client_input_snapshot\.lua' -or
    $networkDebug -notmatch 'function\s+server\.netClientCall\s*\(' -or
    $syncLimiter -notmatch 'function\s+server\.netSyncShouldSend\s*\(') {
    Add-Issue "CM2 unified network synchronization layer is missing"
}
if ($guidedGroup -notmatch 'hudSync\s*=\s*\{' -or
    $guidedGroup -notmatch 'sync\.age\s*>=\s*0\.2' -or
    $guidedGroup -notmatch '_guidedGroupResolveHudPlayer' -or
    $guidedGroup -match '(?s)netClientCall\(\s*"hud\.guided",\s*0') {
    Add-Issue "M/G HUD must be driver-only and throttled to 5 Hz"
}
if ($hSlotControl -notmatch 'debugEnabled\s*=\s*false' -or
    $hSlotControl -notmatch 'hudInterval\s*=\s*0\.2' -or
    $hSlotControl -notmatch 'debugInterval\s*=\s*1\.0' -or
    $hSlotControl -match '(?s)netClientCall\(\s*"debug\.hslot",\s*0') {
    Add-Issue "H-slot HUD/debug synchronization is not safely throttled"
}
if ($titanDefinition -notmatch 'maxBodyHP\s*=\s*40000' -or
    $titanDefinition -match 'baseHullHP\s*=' -or
    $titanDefinition -notmatch 'groupId\s*=\s*"hSlot",\s*slotType\s*=\s*"H",\s*count\s*=\s*4' -or
    $titanDefinition -notmatch 'slotType\s*=\s*"largeUtility",\s*count\s*=\s*20' -or
    $titanDefinition -notmatch 'slotType\s*=\s*"auxiliary",\s*count\s*=\s*4' -or
    $titanMounts -notmatch '(?s)hHangar\s*=\s*\{.*?x\s*=\s*6.*?x\s*=\s*-6.*?y\s*=\s*6.*?y\s*=\s*-6' -or
    $componentCatalog -notmatch 'maxBodyHP\s*=\s*tonumber\(\(definition\s+or\s+\{\}\)\.maxBodyHP\)' -or
    $shipHealthBar -notmatch '_paradoxTitanTheoreticalMaxHP\s*=\s*102595') {
    Add-Issue "Titan hull, 4H mounts, 20L/4A protection slots, or health-bar scale contract is incomplete"
}
if ($mainWeaponHud -notmatch 'hSlotFill4\s*=\s*1\.0' -or
    $mainWeaponHud -notmatch 'state\.hSlotCount\s*=\s*math\.min\(4,\s*#hMounts\)' -or
    $hSlotControl -notmatch 'for\s+i\s*=\s*1,\s*4\s+do' -or
    $hSlotControl -notmatch '(?s)cooldowns\[4\].*maximums\[4\].*activeFlags\[4\]') {
    Add-Issue "H-slot HUD synchronization must support up to four configured hangars"
}
if ($mainWeaponHud -match 'local\s+candidates\s*=\s*\{' -or
    $mainWeaponHud -notmatch 'local\s+function\s+appendItem\(' -or
    $mainWeaponHud -notmatch '(?s)appendItem\("tSlot".*?appendItem\("xSlot"') {
    Add-Issue "weapon wheel items must be appended without sparse-array truncation"
}
if ($shipSchema -notmatch 'function\s+shipDefinitionGetGroupLoadoutKey' -or
    $loadoutRuntime -notmatch 'requestedLoadout\[loadoutKey\]' -or
    $loadoutRuntime -notmatch 'result\[loadoutKey\]\s*=\s*tostring\(candidate\)' -or
    $componentCatalog -notmatch '\(weaponLoadout\s+or\s+\{\}\)\[loadoutKey\]') {
    Add-Issue "numbered slot groups must share one canonical loadout-key resolver"
}
if ($configUi -match 'local\s+clicked\s*=\s*enabled\s+and\s+UiBlankButton' -or
    $configUi -match 'local\s+clicked\s*=\s*UiBlankButton\(cardW,\s*cardH\)') {
    Add-Issue "weapon configuration ship/frame switching must trigger on mouse press only"
}
if ($inputSnapshot -notmatch 'activeInterval\s*=\s*0\.05' -or
    $inputSnapshot -notmatch 'idleInterval\s*=\s*0\.20' -or
    $inputSnapshot -notmatch 'configuredBody\s*=\s*math\.floor\(client\.shipContextGetBody\(\)\s*or\s*0\)' -or
    $inputSnapshot -match '\(client\.shipControlSnapshot\s+or\s+\{\}\)\.shipBody\s+or\s+client\.shipContextGetBody\(\)' -or
    $inputSnapshot -notmatch 'server\.shipReceiveControlSnapshot' -or
    $serverRequests -notmatch 'function\s+server\.shipReceiveControlSnapshot\s*\(' -or
    $serverRequests -notmatch 'lastSequence' -or
    $shipCamera -match 'client\.shipRequestRotationError\s*\(' -or
    $shipCamera -match 'client\.shipRequestWeaponAim\s*\(' -or
    $shipRoll -match 'client\.shipRequestRollError\s*\(' -or
    $bodyMove -match 'client\.shipRequestMoveState\s*\(') {
    Add-Issue "battlecruiser controls must use the validated 20 Hz reacquirable input snapshot"
}
if ($guidedRuntime -notmatch 'syncInterval\s*=\s*0\.1' -or
    $guidedCollider -notmatch 'client\.correctMissileVisual' -or
    $guidedCollider -match 'client\.updateMissileVisual' -or
    $missileVisual -notmatch 'correctionRemain' -or
    $missileVisual -notmatch 'VecScale\(missile\.velocity') {
    Add-Issue "guided missiles must use throttled correction and client prediction"
}
if ($hSlotControl -notmatch 'server\.hSlotFlightCreate\s*\(' -or
    $hSlotControl -notmatch 'server\.hSlotFlightUpdate\s*\(' -or
    $hSlotFlight -notmatch 'guidanceRemain\s*=\s*1\.0\s*/\s*15\.0' -or
    $hSlotFlight -notmatch 'nearSweepRemain\s*=\s*1\.0\s*/\s*30\.0' -or
    $hSlotFlight -notmatch 'farProbeRemain\s*=\s*1\.0\s*/\s*8\.0' -or
    $hSlotFlight -notmatch 'craft\.plannerRemain\s*=\s*0\.20' -or
    $hSlotFlight -notmatch 'server\.netDebugCountRaycast') {
    Add-Issue "strike craft must use the staggered production flight controller"
}
if ($guidedRuntime -notmatch 'maxPerShip\s*=\s*24' -or
    $guidedRuntime -notmatch 'maxGlobal\s*=\s*96' -or
    $hSlotControl -notmatch 'maxPerShip\s*=\s*4' -or
    $hSlotControl -notmatch 'maxGlobal\s*=\s*24') {
    Add-Issue "missile or strike-craft entity budgets are missing"
}
if ($shipRegistryServer -notmatch 'math\.abs\(oldShield\s*-\s*nextShield\)\s*>=\s*threshold' -or
    $shipRegistryServer -notmatch 'math\.abs\(oldArmor\s*-\s*nextArmor\)\s*>=\s*threshold' -or
    $shipRegistryServer -notmatch 'math\.abs\(oldBody\s*-\s*nextBody\)\s*>=\s*threshold') {
    Add-Issue "ship HP registry writes must update only changed fields"
}
if ($runtimeState -notmatch 'server\.shipSlotLoadoutResolveShipDefinition\(\s*requestedShipType\s*\)' -or
    $runtimeState -notmatch 'activeGroups\s*=\s*\(definition\s+or\s+\{\}\)\.weaponGroups' -or
    $runtimeState -notmatch '_normalizeMode\(\s*mainWeapon\.current,\s*definition\s*\)') {
    Add-Issue "main weapon mode sync must normalize against the active ship definition"
}
if ($missileVisual -notmatch 'client\.missileVisualTick' -or
    $missileVisual -notmatch 'client\.missileVisualRender' -or
    $missileVisual -notmatch 'distance\s*<\s*900' -or
    $missileVisual -notmatch 'distance\s*<\s*420' -or
    $shipDefinition -notmatch 'particleCutoffDistance\s*=\s*600\.0' -or
    $shipDefinition -notmatch 'renderCutoffDistance\s*=\s*1200\.0') {
    Add-Issue "missile and engine visual distance LOD/split update-render path is missing"
}
if ($client -notmatch 'weapon_fx_resources\.lua' -or
    $client -notmatch 'weapon_muzzle_fx\.lua' -or
    $client -notmatch 'weapon_impact_fx\.lua' -or
    $weaponMuzzleFx -notmatch 'function\s+client\.spawnWeaponMuzzleFx' -or
    $weaponImpactFx -notmatch 'focusedArcImpact' -or
    $weaponImpactFx -notmatch 'disruptorImplosion' -or
    $weaponFxResources -notmatch 'function\s+client\.weaponFxResourcesInit') {
    Add-Issue "V2 shared weapon FX resources, muzzle, or specialized impact contracts are missing"
}
if ($projectileManager -notmatch 'n\[1\].*n\[2\].*n\[3\]' -or
    $projectileManager -notmatch 'impactLayer\s+or\s+"none"' -or
    $guidedRuntime -notmatch 'client\.spawnMissileVisual' -or
    $guidedRuntime -match 'spawnMissileWarpFx' -or
    $missileVisual -notmatch 'function\s+client\.missileVisualRender') {
    Add-Issue "V2 projectile impact metadata or missile render protocol is incomplete"
}
if ($xSlotState -match 'ClientCall\(0,\s*"client\.updateXSlotHudState"' -or
    $lSlotState -match 'ClientCall\(0,\s*"client\.(?:init|update|reset)LSlotHudState"' -or
    $groupRuntime -match '(?s)ClientCall\(\s*0,\s*"client\.updateWeaponGroupHudState"' -or
    $runtimeState -match '(?s)netClientCall\(\s*"hud\.weaponMode",\s*0') {
    Add-Issue "private weapon HUD must never broadcast with player id 0"
}

if ($ship -notmatch 'configurationId\s*=\s*"battleline_2x2l4m"') {
    Add-Issue "default artillery frame is missing"
}
if ($ship -notmatch 'configurationId\s*=\s*"torpedo_2x4g4m"') {
    Add-Issue "official torpedo frame is missing"
}
if ($ship -notmatch 'legacyConfigurationIds\s*=\s*\{\s*"siege_2x4g2m"\s*\}') {
    Add-Issue "legacy siege frame alias is missing"
}
if ($ship -notmatch '(?s)configurationId\s*=\s*"torpedo_2x4g4m".*?\{.*?slotType\s*=\s*"G",\s*count\s*=\s*4.*?\{.*?slotType\s*=\s*"M",\s*count\s*=\s*4') {
    Add-Issue "torpedo frame must contain 4G and 4M"
}

if ($shipDefinition -notmatch '(?s)slotType\s*=\s*"thruster".*?slotType\s*=\s*"sensor".*?slotType\s*=\s*"reactor"' -or
    $componentCatalog -notmatch 'officialComponentId\s*=\s*"BATTLESHIP_DARK_MATTER_REACTOR"' -or
    $componentCatalog -notmatch 'EXCESS|weaponDamageMultiplier\s*=\s*excessBonus' -or
    $shipComponents -notmatch 'positive power balance' -or
    $shipDamage -notmatch 'shipRuntimeGetWeaponDamageMultiplier') {
    Add-Issue "core slots, positive-power validation, or Stellaris excess-power buffs are incomplete"
}
if ($sensorHud -notmatch 'UiWorldToPixel' -or
    $sensorHud -notmatch 'registryShipGetRegisteredBodyIds' -or
    $sensorHud -notmatch 'cameraDistance\s*<\s*0\.0' -or
    $sensorHud -notmatch 'math\.deg\(math\.atan2\(dy,\s*dx\)\)') {
    Add-Issue "client sensor HUD lacks registered-ship scan, projection, or off-screen arrows"
}
if ($ship -notmatch 'slotType\s*=\s*"P",\s*count\s*=\s*2,\s*automatic\s*=\s*true' -or
    $flakWeapon -notmatch 'officialComponentId\s*=\s*"FLAK_BATTERY_3"' -or
    $flakWeapon -notmatch 'shieldFix\s*=\s*2\.0' -or
    $flakWeapon -notmatch 'shieldPenetration\s*=\s*0\.25' -or
    $pointDefenseWeapon -notmatch 'officialComponentId\s*=\s*"POINT_DEFENCE_3"' -or
    $pointDefenseWeapon -notmatch 'armorFix\s*=\s*2\.0' -or
    $pointDefenseWeapon -notmatch 'armorPenetration\s*=\s*0\.25' -or
    $pointDefenseControl -notmatch '_pdInterceptTime' -or
    $pointDefenseControl -notmatch 'automaticPointDefense' -or
    $pointDefenseFx -notmatch 'function\s+client\.spawnPointDefenseFx') {
    Add-Issue "P-slot flak/point-defense official modifiers, predictive AI, or FX are incomplete"
}
if ($interceptorShipDefinitions -notmatch 'advancedSwarmerMissile' -or
    $interceptorShipDefinitions -notmatch 'devastatorTorpedo' -or
    $interceptorShipDefinitions -notmatch 'playerDriveable\s*=\s*false' -or
    $interceptorShipDefinitions -notmatch 'playerLockable\s*=\s*false' -or
    $guidedRuntime -notmatch 'interceptorShipType' -or
    $shipRegistryServer -notmatch 'registryShipSetInterceptorOwner') {
    Add-Issue "missiles, torpedoes, or strike craft are missing non-player interceptor ship registration"
}
if ($guidedRuntime -notmatch 'function\s+server\.guidedProjectileDestroyIfDeadAt\s*\(' -or
    $guidedRuntime -notmatch '(?s)guidedProjectileDestroyIfDeadAt.*?targetBodyId\s*=\s*0.*?Explosion\s*\(.*?guidedProjectileRemoveAt' -or
    $guidedMovement -notmatch 'guidedProjectileDestroyIfDeadAt\(i\)' -or
    $guidedCollider -notmatch 'guidedProjectileDestroyIfDeadAt\(i\)' -or
    $guidedGroup -notmatch 'destroyedExplosionSize\s*=\s*tonumber\(weaponDef\.destroyedExplosionSize\)' -or
    $shipDamage -notmatch '_stopDestroyedInterceptor' -or
    $shipDamage -notmatch 'SetBodyAngularVelocity\(body,\s*Vec\(0,\s*0,\s*0\)\)') {
    Add-Issue "destroyed missiles and torpedoes must stop tracking, explode, and leave the active runtime immediately"
}
if ($hSlotControl -notmatch 'local\s+function\s+_hSlotHandleDestroyedCraft' -or
    $hSlotControl -notmatch '(?s)_hSlotHandleDestroyedCraft.*?craft\.state\s*=\s*"DISABLED".*?_hSlotCraftExplode.*?_hSlotFinishCraft' -or
    $hSlotControl -notmatch '(?s)registryShipIsBodyDead\(craft\.bodyId\).*?_hSlotHandleDestroyedCraft') {
    Add-Issue "destroyed strike craft must become disabled, explode, and notify the carrier launcher to start rebuild cooldown"
}
if ($shipServerBootstrap -notmatch 'function\s+server\.shipServerIsDestroyed\s*\(' -or
    $shipServerBootstrap -notmatch 'function\s+server\.shipServerFinalizeDestroyed\s*\(' -or
    $entry -notmatch '(?s)local\s+function\s+disableDestroyedControls\(\).*?weaponRuntimeClearCommands\(\).*?weaponRuntimeDeactivate\(\)' -or
    $entry -notmatch '(?s)shipServerIsDestroyed\(\).*?disableDestroyedControls\(\).*?return' -or
    $strikeCraftEntry -notmatch '(?s)server\.shipServerIsDestroyed\(\).*?server\.shipServerFinalizeDestroyed\(\).*?return' -or
    $serverRequests -notmatch 'registryShipIsBodyDead\(body\)' -or
    $clientRegistry -notmatch 'function\s+client\.registryShipIsBodyDead\s*\(' -or
    $clientShipBootstrap -notmatch 'function\s+client\.shipClientDestroyedUiTick\s*\(' -or
    $clientEntry -notmatch '(?s)shipClientIsDestroyed\(\).*?shipClientDestroyedUiTick\(dt\).*?return' -or
    $clientEntry -notmatch '(?s)function\s+client\.clientDraw\(\).*?shipClientDrawHealth\(\)') {
    Add-Issue "destroyed Stellaris entities must disable control simulation while retaining client UI updates"
}
if ($componentCatalog -notmatch 'reactorBooster3' -or
    $componentCatalog -notmatch 'reactorOutputMultiplier\s*=\s*0\.50' -or
    $componentCatalog -notmatch 'darkMatterCloakingField' -or
    $componentCatalog -notmatch 'cloakStrength\s*=\s*1\.0' -or
    $shipCloak -notmatch 'shipRequestToggleCloak' -or
    $shipCloak -notmatch 'shipCloakApplyShieldCap' -or
    $client -notmatch 'shipCloakInputTick') {
    Add-Issue "reactor boosters or dark-matter cloaking runtime is incomplete"
}
if ($shipDefinition -notmatch 'maxCombatSpeed\s*=\s*42\.0' -or
    $speedLimit -notmatch 'SetBodyVelocity' -or
    $shipServerBootstrap -notmatch 'bodyCombatSpeedLimitTick') {
    Add-Issue "combat speed cap is missing from the ship runtime"
}
if ($strikeCraftDefinition -notmatch 'shipType\s*=\s*"advancedStrikeCraft"' -or
    $strikeCraftDefinition -notmatch 'playerConfigurable\s*=\s*false' -or
    $strikeCraftDefinition -notmatch 'maxShieldHP\s*=\s*25\.0' -or
    $strikeCraftDefinition -notmatch 'maxArmorHP\s*=\s*0\.0' -or
    $strikeCraftDefinition -notmatch 'maxBodyHP\s*=\s*12\.0' -or
    $strikeCraftEntry -notmatch 'server\.shipServerInit\(configuredShipType\)' -or
    $strikeCraftEntry -match 'weapon/server/bootstrap\.lua' -or
    # Vehicle sound is optional.  The invalid `none` sound bank produces
    # runtime warnings, so strike craft prefabs must only be non-driveable;
    # valid sound assets are checked separately below.
    $strikeCraftPrefab -notmatch '<vehicle[^>]+driven="false"' -or
    $strikeCraftDefinition -notmatch 'playerDriveable\s*=\s*false' -or
    $strikeCraftDefinition -notmatch 'playerLockable\s*=\s*false' -or
    $strikeCraftDefinition -notmatch 'interceptorClass\s*=\s*"strike_craft"' -or
    $strikeCraftPrefab -notmatch 'strikeCraftMain\.lua' -or
    $hSlotControl -notmatch 'registryShipRegister\(\s*craftBody,\s*"advancedStrikeCraft"' -or
    $hSlotControl -notmatch 'registryShipIsBodyDead\(craft\.bodyId\)' -or
    $shipRegistryServer -notmatch 'function\s+server\.registryShipUnregister') {
    Add-Issue "advanced strike craft is not a fixed, AI-controlled, non-player-lockable registered Stellaris ship"
}

$prefabMatches = [Regex]::Matches($standard, '"(MOD/prefabs/[^"]+\.xml)"')
foreach ($match in $prefabMatches) {
    $reference = $match.Groups[1].Value
    $relative = $reference.Substring(4).Replace("/", [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath (Join-Path $modRoot $relative) -PathType Leaf)) {
        Add-Issue "weapon references missing prefab: $reference"
    }
}

$staticSoundPattern = '(?:LoadSound|LoadLoop)\s*\(\s*"(MOD/sound/[^"%]+\.ogg)"'
foreach ($luaFile in Get-ChildItem -LiteralPath $modRoot -Recurse -Filter "*.lua" -File) {
    $luaText = [IO.File]::ReadAllText($luaFile.FullName)
    foreach ($match in [Regex]::Matches($luaText, $staticSoundPattern)) {
        $reference = $match.Groups[1].Value
        $relative = $reference.Substring(4).Replace("/", [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath (Join-Path $modRoot $relative) -PathType Leaf)) {
            Add-Issue "$($luaFile.FullName) references missing sound asset: $reference"
        }
    }
}

Write-Host "=== CM2 Weapon System Semantic Checker ===" -ForegroundColor Cyan
Write-Host "Checked $($expected.Count) standard weapons, core components, sensor HUD, fixed interceptors, two frames, five behaviors, and FX/prefab references."
if ($issues -gt 0) {
    Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red
    exit 1
}
Write-Host "OK - weapon catalog and runtime contracts are valid." -ForegroundColor Green
exit 0
