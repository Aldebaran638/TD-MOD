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
$mainXml = Read-Required "main.xml"
$configurator = Read-Required "script\weapon_configurator.lua"
$clientLoadout = Read-Required "script\weapon\client\common\state\weapon_loadout.lua"
$configUi = Read-Required "script\weapon\client\config_ui\weapon_config_ui.lua"
$mainWeaponHud = Read-Required "script\weapon\client\common\hud\main_weapon_hud.lua"
$crosshair = Read-Required "script\weapon\client\common\hud\ship_crosshair.lua"
$projectileVisual = Read-Required "script\weapon\client\slots\l\kinetic_artillery\effects\projectile_visual.lua"
$clientRegistry = Read-Required "script\ship\battlecruiser\client\registry\ship_registry.lua"
$serverRequests = Read-Required "script\ship\battlecruiser\server\registry\ship_registry_request.lua"
$groupRuntime = Read-Required "script\weapon\server\common\runtime\weapon_group.lua"
$loadoutRuntime = Read-Required "script\weapon\server\common\loadout\slot_loadout.lua"
$loadoutApi = Read-Required "script\weapon\server\common\loadout\slot_loadout_api.lua"

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
    "tachyonLance", "energyBeam", "arcBeam", "kineticProjectile",
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
if ($loadoutApi -notmatch 'function\s+server\.shipWeaponApplyConfiguration\s*\(') {
    Add-Issue "shipWeaponApplyConfiguration API is missing"
}
if ($loadoutApi -notmatch 'function\s+server\.shipWeaponSetSpawnTemplate\s*\(' -or
    $loadoutApi -notmatch 'function\s+server\.shipWeaponSyncSpawnTemplate\s*\(') {
    Add-Issue "next-spawn weapon template API is missing"
}
if ($loadoutRuntime -notmatch '_readSpawnTemplate\s*\(' -or
    $loadoutRuntime -notmatch 'template\s+and\s+template\.configurationId') {
    Add-Issue "newly spawned ships do not consume the saved weapon template"
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
if ($client -notmatch 'generic_raycast_fx\.lua') {
    Add-Issue "generic raycast client FX is not included"
}
if ($mainXml -notmatch 'MOD/script/weapon_configurator\.lua' -or
    $configurator -notmatch 'config_ui/weapon_config_ui\.lua') {
    Add-Issue "independent weapon configurator is not mounted at scene level"
}
if ($configUi -notmatch 'InputPressed\("t"\)' -or
    $configUi -notmatch 'weaponConfiguratorSaveTemplate') {
    Add-Issue "weapon configuration UI toggle/apply flow is incomplete"
}
if ($configUi -match 'GetPlayerVehicle|client\.shipBody' -or
    $configurator -notmatch 'function\s+server\.weaponConfiguratorSaveTemplate\s*\(') {
    Add-Issue "weapon configuration UI is still coupled to a spawned ship"
}
if ($groupRuntime -notmatch 'client\.updateWeaponGroupHudState' -or
    $mainWeaponHud -notmatch 'function\s+client\.updateWeaponGroupHudState\s*\(') {
    Add-Issue "generic weapon charge/cooldown HUD synchronization is missing"
}
if ($configurator -notmatch 'shipWeaponSetSpawnTemplate' -or
    $configurator -match 'shipWeaponApplyConfiguration') {
    Add-Issue "independent configurator does not save a spawn-only template"
}
if ($standard -notmatch '(?s)_rocket\("devastatorTorpedoes".*?behaviorType\s*=\s*"rocketProjectile"' -and
    $standard -notmatch '_rocket\("devastatorTorpedoes"') {
    Add-Issue "Devastator Torpedoes must use the unguided rocket behavior"
}
if ($standard -match 'weaponData\.devastatorTorpedoes\.legacyController\s*=') {
    Add-Issue "Devastator Torpedoes still use the legacy guided controller"
}
if ($standard -notmatch '(?s)local function _rocket.*?targetingMode\s*=\s*"forward"') {
    Add-Issue "unguided rockets must use forward targeting"
}
if ($standard -notmatch '_projectile\("neutronLauncher".*?"neutronProjectile"\)' -or
    $standard -notmatch 'weaponData\.neutronLauncher\.targetingMode\s*=\s*"forward"') {
    Add-Issue "Neutron Launcher must be a single forward, non-guided projectile"
}
if ($projectileVisual -notmatch '(?s)plasmaProjectile.*?\{\s*0\.30,\s*1\.0,\s*0\.34\s*\}' -or
    $projectileVisual -notmatch 'gigaCannonProjectile' -or
    $projectileVisual -notmatch 'neutronProjectile') {
    Add-Issue "official plasma/giga-cannon/neutron projectile colors are missing"
}
if ($standard -notmatch 'largeStormfireAutocannon".*?0\.65,\s*220\.0' -or
    $standard -notmatch 'mediumStormfireAutocannon".*?0\.55,\s*180\.0') {
    Add-Issue "Stormfire Autocannons must remain short-range rapid-fire weapons"
}
if ($crosshair -notmatch 'weaponConfigUiIsOpen') {
    Add-Issue "crosshair is not hidden while the independent UI is open"
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
Write-Host "Checked $($expected.Count) standard weapons, two frames, five behaviors, spawn templates, and FX/prefab references."
if ($issues -gt 0) {
    Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red
    exit 1
}
Write-Host "OK - weapon catalog and runtime contracts are valid." -ForegroundColor Green
exit 0
