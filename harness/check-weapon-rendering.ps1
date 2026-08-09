# Client weapon-effect layout and profile-dispatch checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
function Add-Issue { param([string]$Message); Write-Host "[WEAPON RENDERING ERROR] $Message" -ForegroundColor Red; $script:issues++ }
function Read-Required { param([string]$Relative); $file = Join-Path $script:root $Relative; if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { Add-Issue "missing file: $Relative"; return "" }; return [IO.File]::ReadAllText($file) }
function Require-Text { param([string]$Source, [string]$Pattern, [string]$Message); if ($Source -notmatch $Pattern) { Add-Issue $Message } }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path -LiteralPath $Path).Path
$effectRoot = "script\weapon\client\common\effects"

$requiredFiles = @(
    "registry\effect_profile_registry.lua", "registry\palette_profile_registry.lua", "registry\effect_dispatch.lua",
    "shared\effect_budget.lua", "shared\effect_resources.lua", "shared\shield_hit.lua",
    "charge\default.lua", "charge\tachyon_lance.lua", "charge\focused_arc.lua", "charge\perdition_beam.lua",
    "beam\default.lua", "beam\gamma.lua", "beam\arc.lua", "beam\tachyon_lance.lua", "beam\perdition_beam.lua",
    "muzzle\default.lua", "muzzle\gamma.lua", "muzzle\ballistic.lua", "muzzle\guided.lua",
    "projectile\default.lua", "projectile\kinetic.lua", "projectile\plasma.lua", "projectile\autocannon.lua", "projectile\neutron.lua", "projectile\giga_cannon.lua",
    "trail\default.lua", "trail\plasma.lua", "trail\neutron.lua", "trail\guided_missile.lua", "trail\guided_torpedo.lua",
    "impact\default.lua", "impact\gamma.lua", "impact\arc.lua", "impact\ballistic.lua", "impact\plasma.lua", "impact\neutron.lua", "impact\guided.lua", "impact\perdition_beam.lua",
    "guided\missile.lua", "guided\torpedo.lua",
    "craft\default.lua", "craft\engine.lua", "craft\launch.lua", "craft\recover.lua", "craft\subweapon_beam.lua", "craft\subweapon_muzzle.lua", "craft\subweapon_impact.lua"
)
foreach ($relative in $requiredFiles) { [void](Read-Required (Join-Path $effectRoot $relative)) }

foreach ($obsolete in @(
    "script\weapon\client\slots\x\tachyon_lance\effects",
    "script\weapon\client\slots\x\focused_arc_emitter\effects",
    "script\weapon\client\slots\t\perdition_beam\effects",
    "script\weapon\client\slots\l\kinetic_artillery\effects",
    "script\weapon\client\slots\h\gamma_strike_craft\effects",
    "script\weapon\client\guided\effects"
)) {
    if (Test-Path -LiteralPath (Join-Path $root $obsolete)) { Add-Issue "obsolete representative-weapon effect directory remains: $obsolete" }
}

$registry = Read-Required "$effectRoot\registry\effect_profile_registry.lua"
$paletteRegistry = Read-Required "$effectRoot\registry\palette_profile_registry.lua"
$dispatch = Read-Required "$effectRoot\registry\effect_dispatch.lua"
$bootstrap = Read-Required "script\weapon\client\bootstrap.lua"
foreach ($token in @("weaponFxRegister", "weaponFxResolve", "weaponFxProfiles")) { Require-Text $registry ([regex]::Escape($token)) "effect profile registry is missing $token" }
foreach ($token in @("weaponFxPaletteRegister", "weaponFxGetPalette", '"particleLance"')) { Require-Text $paletteRegistry ([regex]::Escape($token)) "palette registry is missing $token" }
foreach ($token in @("weaponFxInitAll", "weaponFxTickAll", "weaponFxRenderAll", '"tachyonLance"', '"perditionImpact"', '"guidedMissile"')) { Require-Text $dispatch ([regex]::Escape($token)) "effect dispatcher is missing $token" }
foreach ($token in @("weaponFxInitAll", "weaponFxTickAll", "weaponFxRenderAll")) { Require-Text $bootstrap ([regex]::Escape($token)) "client bootstrap does not use unified $token" }
if ($bootstrap -match 'slots/[xlh]/.+/effects|guided/effects|common/effects/(?:generic_raycast|gamma_laser|weapon_muzzle|weapon_impact|shield_hit)') { Add-Issue "bootstrap still includes an obsolete effect path" }

$dataFiles = Get-ChildItem -LiteralPath (Join-Path $root "script\data\weapons") -Filter "*.lua" -Recurse
$paletteIds = @{}
$visualProfileIds = @{}
foreach ($file in $dataFiles) {
    $text = [IO.File]::ReadAllText($file.FullName)
    foreach ($match in [regex]::Matches($text, 'fxPalette\s*=\s*"([A-Za-z0-9_]+)"')) { $paletteIds[$match.Groups[1].Value] = $true }
    foreach ($field in @("chargeFxProfile", "fxProfile", "muzzleFxProfile", "impactFxProfile")) {
        foreach ($match in [regex]::Matches($text, ($field + '\s*=\s*"([A-Za-z0-9_]+)"'))) { $visualProfileIds[$match.Groups[1].Value] = $true }
    }
}
foreach ($paletteId in $paletteIds.Keys) {
    Require-Text $paletteRegistry ('weaponFxPaletteRegister\("' + [regex]::Escape($paletteId) + '"') "fxPalette $paletteId has no client palette registration"
}
foreach ($profileId in $visualProfileIds.Keys) {
    Require-Text $dispatch ([regex]::Escape('"' + $profileId + '"')) "visual profile $profileId has no client effect registration"
}

$publicEntries = @{
    "beam\default.lua" = "function client.spawnGenericRaycastWeaponFx"
    "projectile\default.lua" = "function client.spawnProjectileVisual"
    "guided\missile.lua" = "function client.spawnMissileVisual"
    "muzzle\default.lua" = "function client.spawnWeaponMuzzleFx"
    "impact\default.lua" = "function client.spawnWeaponImpactFx"
    "craft\subweapon_beam.lua" = "function client.spawnHSlotBeamFx"
}
foreach ($relative in $publicEntries.Keys) {
    Require-Text (Read-Required (Join-Path $effectRoot $relative)) ([regex]::Escape($publicEntries[$relative])) "missing stable client entry in $relative"
}

$clientFiles = Get-ChildItem -LiteralPath (Join-Path $root "script\weapon\client") -Filter "*.lua" -Recurse
foreach ($file in $clientFiles) {
    $text = [IO.File]::ReadAllText($file.FullName)
    if ($text -match 'weaponType\s*==\s*"[A-Za-z0-9_]+"|"[A-Za-z0-9_]+"\s*==\s*weaponType') {
        Add-Issue "client rendering must not select effects by concrete weaponType: $($file.FullName)"
    }
}

Write-Host "=== Weapon Rendering Architecture Checker ===" -ForegroundColor Cyan
if ($issues -gt 0) { Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red; exit 1 }
Write-Host "OK - client effects are stage-organized and profile-dispatched." -ForegroundColor Green
exit 0
