# Ballistic projectile weapon definition and profile-dispatch checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
function Add-Issue { param([string]$Message); Write-Host "[BALLISTIC WEAPON ERROR] $Message" -ForegroundColor Red; $script:issues++ }
function Read-Required { param([string]$Relative); $path = Join-Path $script:root $Relative; if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Issue "missing file: $Relative"; return "" }; return [IO.File]::ReadAllText($path) }
function Require-Text { param([string]$Source, [string]$Pattern, [string]$Message); if ($Source -notmatch $Pattern) { Add-Issue $Message } }
function Require-Profile { param([string]$Source, [string]$Field, [string]$Value, [string]$Id); Require-Text $Source "$Field\s*=\s*`"$Value`"" "ballistic weapon $Id has invalid $Field (expected $Value)" }
function Select-Definition { param([string]$Source, [string]$Id); $marker = "weaponType = `"$Id`""; $index = $Source.IndexOf($marker); if ($index -lt 0) { return "" }; $start = [Math]::Max(0, $index - 300); $tail = $Source.Substring($start); $end = $tail.IndexOf("`n})", $index - $start); if ($end -lt 0) { return $tail }; return $tail.Substring(0, $end + 3) }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path -LiteralPath $Path).Path
$schema = Read-Required "script\data\weapons\schema.lua"
$stellaris = (Read-Required "script\data\weapons\s\stellaris.lua") + (Read-Required "script\data\weapons\m\stellaris.lua") + (Read-Required "script\data\weapons\l\stellaris.lua") + (Read-Required "script\data\weapons\g\stellaris.lua") + (Read-Required "script\data\weapons\x\stellaris.lua")

foreach ($token in @("projectile = true", "kineticProjectile = true", "plasmaProjectile = true", "autocannonProjectile = true", "gigaCannonProjectile = true", "neutronProjectile = true", "kineticArtillery = true", "gaussLarge = true", "gaussMedium = true", "autocannonLarge = true", "autocannonMedium = true", "plasmaLarge = true", "plasmaMedium = true", "gigaPenetration = true", "neutronImpact = true", "largeGaussCannon = true", "mediumGaussCannon = true", "gigaCannon = true")) {
    Require-Text $schema ([regex]::Escape($token)) "schema is missing ballistic contract registration: $token"
}

$definitions = @{
    kineticArtillery = @{ fx = "kineticProjectile"; muzzle = "kineticArtillery"; impact = "kineticArtillery"; sound = "kineticArtillery"; variant = "kineticArtillery" }
    largeGaussCannon = @{ fx = "kineticProjectile"; muzzle = "gaussLarge"; impact = "gaussLarge"; sound = "largeGaussCannon"; variant = "gaussLarge" }
    mediumGaussCannon = @{ fx = "kineticProjectile"; muzzle = "gaussMedium"; impact = "gaussMedium"; sound = "mediumGaussCannon"; variant = "gaussMedium" }
    largePlasmaCannon = @{ fx = "plasmaProjectile"; muzzle = "plasmaLarge"; impact = "plasmaLarge"; sound = "largePlasmaCannon"; variant = "plasmaLarge" }
    mediumPlasmaCannon = @{ fx = "plasmaProjectile"; muzzle = "plasmaMedium"; impact = "plasmaMedium"; sound = "mediumPlasmaCannon"; variant = "plasmaMedium" }
    largeStormfireAutocannon = @{ fx = "autocannonProjectile"; muzzle = "autocannonLarge"; impact = "autocannonLarge"; sound = "largeStormfireAutocannon"; variant = "autocannonLarge" }
    mediumStormfireAutocannon = @{ fx = "autocannonProjectile"; muzzle = "autocannonMedium"; impact = "autocannonMedium"; sound = "mediumStormfireAutocannon"; variant = "autocannonMedium" }
    neutronLauncher = @{ fx = "neutronProjectile"; muzzle = "neutronCompression"; impact = "neutronImpact"; sound = "neutronLauncher"; variant = "neutron" }
    gigaCannon = @{ fx = "gigaCannonProjectile"; muzzle = "gigaMagneticLaunch"; impact = "gigaPenetration"; sound = "gigaCannon"; variant = "gigaCannon" }
}

foreach ($id in $definitions.Keys) {
    $contract = $definitions[$id]
    $source = Select-Definition $stellaris $id
    Require-Text $source 'weaponDefineProjectile\s*\(' "$id is not defined as a projectile weapon"
    Require-Text $source 'behaviorType\s*=\s*"projectile"' "$id is missing explicit projectile behaviorType"
    foreach ($field in @("fxProfile", "muzzleFxProfile", "impactFxProfile", "soundProfileId", "projectileFxVariant")) { Require-Text $source "$field\s*=\s*`"[A-Za-z0-9_]+`"" "$id is missing $field" }
    Require-Profile $source "fxProfile" $contract.fx $id
    Require-Profile $source "muzzleFxProfile" $contract.muzzle $id
    Require-Profile $source "impactFxProfile" $contract.impact $id
    Require-Profile $source "soundProfileId" $contract.sound $id
    Require-Profile $source "projectileFxVariant" $contract.variant $id
    Require-Text $source 'projectileSpeed\s*=\s*[0-9.]+' "$id is missing projectileSpeed"
    Require-Text $source 'projectileRadius\s*=\s*[0-9.]+' "$id is missing projectileRadius"
}

foreach ($token in @('behaviorType = "projectile"', 'impactFxProfile = "kineticArtillery"', 'projectileRadius = 0.35', 'projectileRadius = 0.55', 'impactFxProfile = "neutronImpact"')) {
    Require-Text $stellaris ([regex]::Escape($token)) "static Stellaris ballistic definitions are missing $token"
}

$runtime = (Read-Required "script\weapon\client\slots\l\kinetic_artillery\effects\projectile_visual.lua") + "`n" +
    (Read-Required "script\weapon\client\common\effects\weapon_muzzle_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\common\sound\sound_service.lua") + "`n" +
    (Read-Required "script\weapon\server\slots\l\kinetic_artillery\projectile_manager.lua")
foreach ($token in @("definition.fxProfile", "definition.projectileFxVariant", "definition.impactFxProfile", "definition.muzzleFxProfile", "definition.soundProfileId", "projectileSpeed", "projectileRadius")) {
    Require-Text $runtime ([regex]::Escape($token)) "ballistic runtime does not dispatch $token"
}
Require-Text $runtime "impactFxProfile" "ballistic impact runtime is not profile-driven"

Write-Host "=== Ballistic Weapon Definition Checker ===" -ForegroundColor Cyan
if ($issues -gt 0) { Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red; exit 1 }
Write-Host "OK - ballistic projectile definitions and profile dispatch are valid." -ForegroundColor Green
exit 0
