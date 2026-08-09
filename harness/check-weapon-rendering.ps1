# Client weapon-effect layout and profile-dispatch checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
function Add-Issue { param([string]$Message); Write-Host "[WEAPON RENDERING ERROR] $Message" -ForegroundColor Red; $script:issues++ }
function Read-Required { param([string]$Relative); $file = Join-Path $script:root $Relative; if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { Add-Issue "missing file: $Relative"; return "" }; return [IO.File]::ReadAllText($file) }
function Require-Text { param([string]$Source, [string]$Pattern, [string]$Message); if ($Source -notmatch $Pattern) { Add-Issue $Message } }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path -LiteralPath $Path).Path
$effectRoot = "script\weapon\client\presentation\visual"

$requiredFiles = @(
    "runtime\registry\effect_profile_registry.lua", "runtime\registry\palette_profile_registry.lua", "runtime\registry\effect_dispatch.lua",
    "runtime\shared\effect_budget.lua", "runtime\shared\effect_resources.lua", "runtime\shared\shield_hit.lua",
    "phase\charge\default.lua", "phase\charge\tachyon_lance.lua", "phase\charge\focused_arc.lua", "phase\charge\perdition_beam.lua",
    "phase\beam\default.lua", "phase\beam\gamma.lua", "phase\beam\arc.lua", "phase\beam\tachyon_lance.lua", "phase\beam\perdition_beam.lua",
    "phase\muzzle\default.lua", "phase\muzzle\gamma.lua", "phase\muzzle\ballistic.lua", "phase\muzzle\guided.lua",
    "phase\projectile\default.lua", "phase\projectile\kinetic.lua", "phase\projectile\plasma.lua", "phase\projectile\autocannon.lua", "phase\projectile\neutron.lua", "phase\projectile\giga_cannon.lua", "phase\projectile\guided_missile.lua", "phase\projectile\guided_torpedo.lua",
    "phase\trail\default.lua", "phase\trail\plasma.lua", "phase\trail\neutron.lua", "phase\trail\guided_missile.lua", "phase\trail\guided_torpedo.lua",
    "phase\impact\default.lua", "phase\impact\gamma.lua", "phase\impact\arc.lua", "phase\impact\ballistic.lua", "phase\impact\plasma.lua", "phase\impact\neutron.lua", "phase\impact\guided.lua", "phase\impact\perdition_beam.lua",
    "entity\strike_craft\craft.lua", "entity\strike_craft\engine.lua", "entity\strike_craft\launch.lua", "entity\strike_craft\recover.lua", "entity\strike_craft\subweapon\beam.lua", "entity\strike_craft\subweapon\muzzle.lua", "entity\strike_craft\subweapon\impact.lua"
)
foreach ($relative in $requiredFiles) { [void](Read-Required (Join-Path $effectRoot $relative)) }

foreach ($obsolete in @(
    "script\weapon\client\common",
    "script\weapon\client\config_ui",
    "script\weapon\client\guided",
    "script\weapon\client\slots",
    "script\weapon\server\common",
    "script\weapon\server\behaviors",
    "script\weapon\server\guided",
    "script\weapon\server\slots",
    "script\weapon\client\slots\x\tachyon_lance\effects",
    "script\weapon\client\slots\x\focused_arc_emitter\effects",
    "script\weapon\client\slots\t\perdition_beam\effects",
    "script\weapon\client\slots\l\kinetic_artillery\effects",
    "script\weapon\client\slots\h\gamma_strike_craft\effects",
    "script\weapon\client\guided\effects"
)) {
    if (Test-Path -LiteralPath (Join-Path $root $obsolete)) { Add-Issue "obsolete representative-weapon effect directory remains: $obsolete" }
}

$registry = Read-Required "$effectRoot\runtime\registry\effect_profile_registry.lua"
$paletteRegistry = Read-Required "$effectRoot\runtime\registry\palette_profile_registry.lua"
$dispatch = Read-Required "$effectRoot\runtime\registry\effect_dispatch.lua"
$bootstrap = Read-Required "script\weapon\client\bootstrap.lua"
foreach ($token in @("weaponFxRegister", "weaponFxResolve", "weaponFxProfiles")) { Require-Text $registry ([regex]::Escape($token)) "effect profile registry is missing $token" }
foreach ($token in @("weaponFxPaletteRegister", "weaponFxGetPalette", '"particleLance"')) { Require-Text $paletteRegistry ([regex]::Escape($token)) "palette registry is missing $token" }
foreach ($token in @("weaponFxInitAll", "weaponFxTickAll", "weaponFxRenderAll", '"tachyonLance"', '"perditionImpact"', '"guidedMissile"')) { Require-Text $dispatch ([regex]::Escape($token)) "effect dispatcher is missing $token" }
foreach ($token in @("weaponFxInitAll", "weaponFxTickAll", "weaponFxRenderAll")) { Require-Text $bootstrap ([regex]::Escape($token)) "client bootstrap does not use unified $token" }
if ($bootstrap -match 'slots/[xlh]/.+/effects|guided/effects|common/effects|common/sound|common/hud|common/state') { Add-Issue "bootstrap still includes an obsolete effect path" }

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
    "phase\beam\default.lua" = "function client.spawnGenericRaycastWeaponFx"
    "phase\projectile\default.lua" = "function client.spawnProjectileVisual"
    "phase\projectile\guided_missile.lua" = "function client.spawnMissileVisual"
    "phase\muzzle\default.lua" = "function client.spawnWeaponMuzzleFx"
    "phase\impact\default.lua" = "function client.spawnWeaponImpactFx"
    "entity\strike_craft\subweapon\beam.lua" = "function client.spawnHSlotBeamFx"
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
