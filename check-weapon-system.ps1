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
$standard = Read-Required "script\data\weapons\standard_weapons.lua"
$catalog = Read-Required "script\data\weapons\weapon_catalog.lua"
$ship = Read-Required "script\data\ships\battlecruiser.lua"
$entry = Read-Required "script\shipMain.lua"
$client = Read-Required "script\client.lua"
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
$configurationBinding = Read-Required "script\ship\battlecruiser\client\config\weapon_configuration_binding.lua"
$mainWeaponHud = Read-Required "script\weapon\client\common\hud\main_weapon_hud.lua"
$crosshair = Read-Required "script\weapon\client\common\hud\ship_crosshair.lua"
$projectileVisual = Read-Required "script\weapon\client\slots\l\kinetic_artillery\effects\projectile_visual.lua"
$shieldHitFx = Read-Required "script\weapon\client\common\effects\shield_hit_fx.lua"
$clientRegistry = Read-Required "script\ship\battlecruiser\client\registry\ship_registry.lua"
$engineThrusterFx = Read-Required "script\ship\battlecruiser\client\effects\engine_thruster_fx.lua"
$serverRequests = Read-Required "script\ship\battlecruiser\server\registry\ship_registry_request.lua"
$groupRuntime = Read-Required "script\weapon\server\common\runtime\weapon_group.lua"
$loadoutRuntime = Read-Required "script\weapon\server\common\loadout\slot_loadout.lua"
$loadoutApi = Read-Required "script\weapon\server\common\loadout\slot_loadout_api.lua"
$mainWeaponInput = Read-Required "script\weapon\client\common\input\main_weapon_input.lua"
$behaviorCommon = Read-Required "script\weapon\server\behaviors\common.lua"
$raycastBehavior = Read-Required "script\weapon\server\behaviors\raycast.lua"
$genericRaycastFx = Read-Required "script\weapon\client\common\effects\generic_raycast_fx.lua"
$gammaLaserFx = Read-Required "script\weapon\client\common\effects\gamma_laser_fx.lua"
$weaponMuzzleFx = Read-Required "script\weapon\client\common\effects\weapon_muzzle_fx.lua"
$weaponImpactFx = Read-Required "script\weapon\client\common\effects\weapon_impact_fx.lua"
$weaponFxResources = Read-Required "script\weapon\client\common\effects\weapon_fx_resources.lua"
$guidedRuntime = Read-Required "script\weapon\server\guided\runtime.lua"
$guidedMovement = Read-Required "script\weapon\server\guided\movement.lua"
$guidedCollider = Read-Required "script\weapon\server\guided\collider.lua"
$guidedTargeting = Read-Required "script\weapon\client\guided\targeting\guided_targeting.lua"
$clientMain = Read-Required "script\client.lua"
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
$networkDebug = Read-Required "script\net\network_debug.lua"
$syncLimiter = Read-Required "script\net\server_sync_limiter.lua"
$inputSnapshot = Read-Required "script\net\client_input_snapshot.lua"
$guidedGroup = Read-Required "script\ship\battlecruiser\server\control\guided_slot_group.lua"
$runtimeState = Read-Required "script\ship\battlecruiser\server\state\runtime_state.lua"
$lSlotState = Read-Required "script\weapon\server\slots\l\kinetic_artillery\state.lua"
$shipCamera = Read-Required "script\ship\battlecruiser\client\camera\ship_camera.lua"
$shipRoll = Read-Required "script\ship\battlecruiser\client\hud\ship_roll_error.lua"
$bodyMove = Read-Required "script\ship\battlecruiser\client\input\body_move_input.lua"
$shipRegistryServer = Read-Required "script\ship\battlecruiser\server\registry\ship_registry.lua"

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
    if ($standard -notmatch "(?s)(?:(?:_ray|_projectile|_guided|_rocket)\(`"$id`".*?\{\s*`"$($item.Value)`"\s*\}|weaponType\s*=\s*`"$id`".*?slotTypes\s*=\s*\{\s*`"$($item.Value)`"\s*\})") {
        Add-Issue "weapon $($item.Key) is missing or is not assigned to slot $($item.Value)"
    }
    if ($ship -notmatch "`"$id`"") {
        Add-Issue "weapon $($item.Key) is absent from battlecruiser weapon pools"
    }
    if ($standard -notmatch "(?m)^\s*$id\s*=\s*\{\s*`"[A-Z0-9_]+`",\s*`"[a-z0-9_]+`"\s*\}") {
        Add-Issue "weapon $($item.Key) has no official component/family metadata"
    }
    $iconRelative = "gfx\ui\weapon_icons\$($item.Key).png"
    if (-not (Test-Path -LiteralPath (Join-Path $modRoot $iconRelative) -PathType Leaf)) {
        Add-Issue "weapon $($item.Key) is missing UI icon: $iconRelative"
    }
    if ($standard -notmatch "(?m)^\s*$id\s*=\s*\{\s*`"[xlmgh][A-Za-z]+`",\s*[124],\s*`"(?:sequential|grouped)`"\s*\}") {
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
    if ($standard -notmatch "(?s)(?:_(?:ray|projectile|guided|rocket)\(`"$id`",.*?,\s*`"$name`"|weaponType\s*=\s*`"$id`".*?englishName\s*=\s*`"$name`")") {
        Add-Issue "weapon $($item.Key) does not use official English name '$($item.Value)'"
    }
}

foreach ($behavior in @("raycast", "projectile", "rocketProjectile", "guidedProjectile", "strikeCraft")) {
    if ($standard -notmatch [Regex]::Escape("$behavior = true")) {
        Add-Issue "catalog does not declare behavior $behavior"
    }
    if ($entry -notmatch [Regex]::Escape("behaviors/$($behavior.Replace('rocketProjectile','rocket_projectile').Replace('guidedProjectile','guided_projectile').Replace('strikeCraft','strike_craft')).lua")) {
        Add-Issue "shipMain does not include controller for $behavior"
    }
}

foreach ($profile in @(
    "tachyonLance", "gammaBeam", "energyBeam", "focusedArcBeam", "arcBeam", "kineticProjectile",
    "plasmaProjectile", "autocannonProjectile", "gigaCannonProjectile",
    "neutronProjectile", "guidedMissile",
    "energyTorpedo", "strikeCraft"
)) {
    if ($standard -notmatch [Regex]::Escape("$profile = true")) {
        Add-Issue "FX profile is not registered: $profile"
    }
}

if ($catalog -notmatch '#include\s+"standard_weapons\.lua"') {
    Add-Issue "weapon catalog does not include standard_weapons.lua"
}
if ($groupRuntime -notmatch 'function\s+server\.weaponGroupRequestFire\s*\(') {
    Add-Issue "weaponGroupRequestFire API is missing"
}
if ($groupRuntime -notmatch 'function\s+server\.weaponGroupTick\s*\(') {
    Add-Issue "weaponGroupTick API is missing"
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
if ($clientLoadout -notmatch 'mSlot\s*=\s*"swarmerMissile"' -or
    $clientLoadout -notmatch 'hSlot\s*=\s*"gammaStrikeCraft"') {
    Add-Issue "client default lock-on weapons are missing"
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
if ($client -notmatch 'ship/battlecruiser/client/effects/engine_thruster_fx\.lua' -or
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
    $xSlotChargingFx -notmatch '(?s)focusedArcEmitter.*emittersByShip' -or
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
    $client -notmatch 'weaponConfigurationBindingInit\("enigmaticCruiser",\s*client\.shipBody\)' -or
    $client -notmatch 'weaponConfigurationBindingTick\(dt\)') {
    Add-Issue "battlecruiser client does not run the local configuration binding"
}
if ($configUi -notmatch 'definition\.englishName\s+or\s+weaponType') {
    Add-Issue "weapon configuration UI has no English-name fallback"
}
if ($standard -notmatch '(?s)_rocket\("devastatorTorpedoes".*?behaviorType\s*=\s*"rocketProjectile"' -and
    $standard -notmatch '_rocket\("devastatorTorpedoes"') {
    Add-Issue "Devastator Torpedoes must use the unguided rocket behavior"
}
if ($standard -match 'weaponData\.devastatorTorpedoes\.legacyController\s*=') {
    Add-Issue "Devastator Torpedoes still use the legacy guided controller"
}
if ($standard -notmatch 'weaponData\.devastatorTorpedoes\.ignoreGravity\s*=\s*true' -or
    $guidedRuntime -notmatch 'SetBodyDynamic\(bodyId,\s*not ignoreGravity\)' -or
    $guidedMovement -notmatch 'projectile\.ignoreGravity' -or
    $guidedMovement -notmatch 'SetBodyTransform\(' -or
    $guidedCollider -notmatch 'projectile\.kinematicVelocity') {
    Add-Issue "Devastator Torpedoes do not have a complete gravity-free flight path"
}
if ($standard -notmatch '(?s)local function _rocket.*?targetingMode\s*=\s*"forward"') {
    Add-Issue "unguided rockets must use forward targeting"
}
if ($standard -notmatch '_projectile\("neutronLauncher".*?"neutronProjectile"\)' -or
    $standard -notmatch 'weaponData\.neutronLauncher\.targetingMode\s*=\s*"forward"') {
    Add-Issue "Neutron Launcher must be a single forward, non-guided projectile"
}
if ($projectileVisual -notmatch '(?s)local function _updatePlasmaProjectile.*?_drawBillboard.*?0\.10,\s*0\.95,\s*0\.20' -or
    $projectileVisual -notmatch '(?s)local function _updateGigaCannonProjectile.*?_pointLight.*?0\.50,\s*0\.08,\s*1\.0' -or
    $projectileVisual -notmatch '(?s)local function _updateNeutronProjectile.*?_drawDirectionalSprite.*?0\.05,\s*0\.35,\s*1\.4') {
    Add-Issue "plasma/giga-cannon/neutron projectile visuals are missing their dedicated color paths"
}
if ($standard -notmatch 'largeStormfireAutocannon".*?0\.65,\s*220\.0' -or
    $standard -notmatch 'mediumStormfireAutocannon".*?0\.55,\s*180\.0') {
    Add-Issue "Stormfire Autocannons must remain short-range rapid-fire weapons"
}
if ($standard -notmatch '(?s)largeStormfireAutocannon\.fireProfile\.burstCount\s*=\s*1.*?largeStormfireAutocannon\.cooldown\s*=\s*0\.0' -or
    $standard -notmatch '(?s)mediumStormfireAutocannon\.fireProfile\.burstCount\s*=\s*1.*?mediumStormfireAutocannon\.cooldown\s*=\s*0\.0' -or
    $standard -notmatch '(?s)definition\.heatPerShot\s*=\s*4\.0.*?definition\.heatDissipationPerSecond\s*=\s*32\.0.*?definition\.overheatThreshold\s*=\s*100\.0.*?definition\.recoverThreshold\s*=\s*45\.0' -or
    $standard -notmatch 'largeStormfireAutocannon\s*=\s*0\.06' -or
    $standard -notmatch 'mediumStormfireAutocannon\s*=\s*0\.06') {
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
if ($standard -notmatch 'focusedArcEmitter\.legacyController\s*=\s*"xSlot"' -or
    $standard -notmatch '_ray\("focusedArcEmitter".*?0\.0,\s*0\.0,\s*2\.3.*?0\.50\)' -or
    $standard -notmatch 'focusedArcEmitter\.chargeDuration\s*=\s*weaponData\.focusedArcEmitter\.fireProfile\.chargeDuration' -or
    $xSlotState -notmatch 'weaponDef\.chargeDuration\s+or\s+fireProfile\.chargeDuration' -or
    $xSlotControl -notmatch '(?s)elseif\s+activeState\s*==\s*"charged"\s+then.*?if\s+releaseRequested\s+then.*?elseif\s+not\s+holdRequested\s+then' -or
    $xSlotControl -match 'if\s+holdRequested\s+or\s+releaseRequested\s+then') {
    Add-Issue "Focused Arc Emitter does not share the Tachyon Lance charge/fire lifecycle"
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
if ($standard -notmatch 'gigaCannon\s*=\s*\{\s*"xSpinal",\s*1,\s*"sequential"\s*\}' -or
    $standard -match 'gigaCannon\s*=\s*\{\s*"xSpinal",\s*2') {
    Add-Issue "Giga Cannon must use Tachyon hardpoints and fire one barrel at a time"
}
if ($standard -notmatch '_projectile\("gigaCannon".*?2350,\s*3\.5,\s*750\.0,\s*560\.0' -or
    $projectileVisual -notmatch '(?s)local function _updateGigaCannonProjectile.*?_emitDistanceEvents.*?"nextTrailDistance".*?function\(p, eventPos\)') {
    Add-Issue "Giga Cannon speed, cooldown, or dedicated trail rendering is missing"
}
if ($standard -notmatch 'neutronLauncher\s*=\s*\{\s*"gNeutron",\s*1,\s*"sequential"\s*\}' -or
    $standard -notmatch '_projectile\("neutronLauncher".*?610,\s*4\.5,\s*1150\.0' -or
    $standard -notmatch 'weaponData\.neutronLauncher\.targetingMode\s*=\s*"forward"' -or
    $standard -notmatch 'neutronLauncher\s*=\s*\{\s*mode\s*=\s*"camera_limited"') {
    Add-Issue "Neutron Launcher must rotate through four X-aligned mounts, support tilt fire, and use a 4.5s cooldown"
}
$gRocketBlock = [Regex]::Match($ship, '(?s)gRocket\s*=\s*\{(.*?)\n\s*\},\s*\n\s*gNeutron\s*=').Groups[1].Value
$gNeutronBlock = [Regex]::Match($ship, '(?s)gNeutron\s*=\s*\{(.*?)\n\s*\},\s*\n\s*gEnergy\s*=').Groups[1].Value
$rocketFrontMountPattern = 'firePosOffset\s*=\s*\{\s*x\s*=\s*0,\s*y\s*=\s*0,\s*z\s*=\s*-4\.8\s*\}.*?fireDirRelative\s*=\s*\{\s*x\s*=\s*0,\s*y\s*=\s*0,\s*z\s*=\s*-1\s*\}'
$neutronFrontMountPattern = 'firePosOffset\s*=\s*\{\s*x\s*=\s*0,\s*y\s*=\s*0,\s*z\s*=\s*-4\s*\}.*?fireDirRelative\s*=\s*\{\s*x\s*=\s*0,\s*y\s*=\s*0,\s*z\s*=\s*-1\s*\}'
if ([Regex]::Matches($gRocketBlock, $rocketFrontMountPattern).Count -ne 4 -or
    $standard -notmatch '_rocket\("devastatorTorpedoes".*?1200\.0,\s*30\.8') {
    Add-Issue "Devastator Torpedoes must use four X-aligned forward mounts"
}
if ([Regex]::Matches($gNeutronBlock, $neutronFrontMountPattern).Count -ne 4) {
    Add-Issue "Neutron Launcher must expose four X-aligned forward mounts"
}
if ($standard -notmatch 'weaponData\.phaseDisruptor\.suppressShipExplosion\s*=\s*true' -or
    $raycastBehavior -notmatch 'suppressPhysicalExplosion\s*=\s*definition\.suppressShipExplosion\s*==\s*true' -or
    $raycastBehavior -notmatch 'not\s+suppressPhysicalExplosion') {
    Add-Issue "Phase Disruptor must not create physical explosions on registered ships"
}
if ($standard -notmatch '_ray\("phaseDisruptor".*?"arcBeam"\)' -or
    $genericRaycastFx -notmatch 'arcBeam\s*=\s*\{\s*color\s*=\s*\{\s*0\.18,\s*1\.0,\s*0\.32\s*\}') {
    Add-Issue "Phase Disruptor arc beam must use the green FX profile"
}
if ($standard -notmatch '_ray\("focusedArcEmitter".*?"focusedArcBeam",\s*0\.50\)' -or
    $genericRaycastFx -notmatch 'focusedArcBeam\s*=\s*\{\s*color\s*=\s*\{\s*0\.72,\s*0\.22,\s*1\.0\s*\}' -or
    $xSlotControl -notmatch 'weaponType,\s*"focusedArcBeam"' -or
    $client -notmatch 'focused_arc_emitter/effects/charging_fx\.lua' -or
    $arcChargingFx -notmatch 'focusedArcChargingFxRender' -or
    $xSlotChargingFx -notmatch '(?s)focusedArcEmitter.*?_clearEffectsByShip' -or
    $xSlotChargingFx -match 'ParticleColor\(0\.82,\s*0\.24,\s*1\.0' -or
    $xSlotMuzzleLight -notmatch 'SetLightColor\(center,\s*0\.72,\s*0\.22,\s*1\.0\)') {
    Add-Issue "Focused Arc Emitter must use independent purple charge/beam/light FX"
}
if ($standard -notmatch '_ray\("largeGammaLaser".*?"gammaBeam"\)' -or
    $standard -notmatch '_ray\("mediumGammaLaser".*?"gammaBeam"\)' -or
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
if ($standard -notmatch 'mediumStormfireAutocannon\s*=\s*\{\s*"mAutocannon",\s*4,\s*"grouped"\s*\}' -or
    $standard -notmatch 'mediumGaussCannon\s*=\s*\{\s*"mKinetic",\s*2,\s*"grouped"\s*\}') {
    Add-Issue "M Stormfire must fire all four mounts while M Gauss remains two grouped pairs"
}
if ($standard -notmatch '(?s)"largePlasmaCannon",\s*"mediumPlasmaCannon",\s*"largeGaussCannon",\s*"mediumGaussCannon".*?definition\.cooldown\s*=\s*0\.0.*?definition\.heatPerShot\s*=\s*12\.0.*?definition\.heatDissipationPerSecond\s*=\s*10\.0.*?definition\.overheatThreshold\s*=\s*100\.0.*?definition\.recoverThreshold\s*=\s*60\.0' -or
    $standard -notmatch 'largePlasmaCannon\s*=\s*0\.10' -or
    $standard -notmatch 'largeGaussCannon\s*=\s*0\.10' -or
    $standard -notmatch 'mediumPlasmaCannon\s*=\s*0\.10' -or
    $standard -notmatch 'mediumGaussCannon\s*=\s*0\.10') {
    Add-Issue "Plasma/Gauss weapons do not use the slightly cooler Kinetic Artillery heat cycle"
}
foreach ($profile in @(
    "xSpinal", "lLaser", "lEnergy", "lKinetic", "lAutocannon",
    "mLaser", "mEnergy", "mKinetic", "mAutocannon", "mSwarmer",
    "gRocket", "gNeutron", "gEnergy", "hHangar"
)) {
    if ($ship -notmatch "(?m)^\s*$profile\s*=\s*\{") {
        Add-Issue "battlecruiser mount profile is missing: $profile"
    }
}
if ($loadoutRuntime -notmatch 'weaponMountProfiles' -or
    $loadoutRuntime -notmatch 'weaponDefinition\.mountProfile') {
    Add-Issue "loadout resolver does not select mounts by weapon profile"
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
if ($inputSnapshot -notmatch 'activeInterval\s*=\s*0\.05' -or
    $inputSnapshot -notmatch 'idleInterval\s*=\s*0\.20' -or
    $inputSnapshot -notmatch 'server\.shipReceiveControlSnapshot' -or
    $serverRequests -notmatch 'function\s+server\.shipReceiveControlSnapshot\s*\(' -or
    $serverRequests -notmatch 'lastSequence' -or
    $shipCamera -match 'client\.shipRequestRotationError\s*\(' -or
    $shipCamera -match 'client\.shipRequestWeaponAim\s*\(' -or
    $shipRoll -match 'client\.shipRequestRollError\s*\(' -or
    $bodyMove -match 'client\.shipRequestMoveState\s*\(') {
    Add-Issue "battlecruiser controls must use the validated 20 Hz input snapshot"
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
if ($missileVisual -notmatch 'client\.missileVisualTick' -or
    $missileVisual -notmatch 'client\.missileVisualRender' -or
    $missileVisual -notmatch 'distance\s*<\s*900' -or
    $missileVisual -notmatch 'distance\s*<\s*420' -or
    $engineThrusterFx -notmatch 'particleCutoffDistance\s*=\s*600\.0' -or
    $engineThrusterFx -notmatch 'renderCutoffDistance\s*=\s*1200\.0') {
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
if ($ship -notmatch '(?s)configurationId\s*=\s*"torpedo_2x4g4m".*?\{\s*slotType\s*=\s*"G",\s*count\s*=\s*4.*?\{\s*slotType\s*=\s*"M",\s*count\s*=\s*4') {
    Add-Issue "torpedo frame must contain 4G and 4M"
}

$prefabMatches = [Regex]::Matches($standard, '"(MOD/prefabs/[^"]+\.xml)"')
foreach ($match in $prefabMatches) {
    $reference = $match.Groups[1].Value
    $relative = $reference.Substring(4).Replace("/", [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath (Join-Path $modRoot $relative) -PathType Leaf)) {
        Add-Issue "weapon references missing prefab: $reference"
    }
}

Write-Host "=== CM2 Weapon System Semantic Checker ===" -ForegroundColor Cyan
Write-Host "Checked $($expected.Count) standard weapons, official English names, local UI configuration binding, two frames, five behaviors, and FX/prefab references."
if ($issues -gt 0) {
    Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red
    exit 1
}
Write-Host "OK - weapon catalog and runtime contracts are valid." -ForegroundColor Green
exit 0
