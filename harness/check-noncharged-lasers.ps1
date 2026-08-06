# Non-charged laser/arc-ray definition and profile-dispatch checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
function Add-Issue { param([string]$Message); Write-Host "[NONCHARGED LASER ERROR] $Message" -ForegroundColor Red; $script:issues++ }
function Read-Required { param([string]$Relative); $path = Join-Path $script:root $Relative; if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Issue "missing file: $Relative"; return "" }; return [IO.File]::ReadAllText($path) }
function Require-Text { param([string]$Source, [string]$Pattern, [string]$Message); if ($Source -notmatch $Pattern) { Add-Issue $Message } }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path -LiteralPath $Path).Path
$schema = Read-Required "script\data\weapons\schema.lua"
$stellaris = Read-Required "script\data\weapons\stellaris_4_4_6.lua"
$generated = Read-Required "script\data\weapons\stellaris_generated_4_4_6.lua"
$definitions = @{
    largeGammaLaser = Read-Required "script\data\weapons\l\large_gamma_laser.lua"
    mediumGammaLaser = Read-Required "script\data\weapons\m\medium_gamma_laser.lua"
    psionicLightning = Read-Required "script\data\weapons\l\psionic_lightning.lua"
    phaseDisruptor = Read-Required "script\data\weapons\m\phase_disruptor.lua"
    guardianPointDefense = Read-Required "script\data\weapons\p\guardian_point_defense.lua"
}
$expected = @{
    largeGammaLaser = @("gammaBeam", "gammaLarge", "gammaLarge", "largeGammaLaser")
    mediumGammaLaser = @("gammaBeam", "gammaMedium", "gammaMedium", "mediumGammaLaser")
    psionicLightning = @("psionicArcBeam", "none", "focusedArcImpact", "focusedArcEmitter")
    phaseDisruptor = @("arcBeam", "disruptor", "disruptorImplosion", "phaseDisruptor")
    guardianPointDefense = @("energyBeam", "none", "none", "none")
}

foreach ($token in @("weaponMuzzleFxProfiles", "weaponImpactFxProfiles", "weaponSoundProfiles", "none = true", "has invalid muzzleFxProfile", "has invalid soundProfileId")) {
    Require-Text $schema ([regex]::Escape($token)) "schema is missing non-charged laser contract: $token"
}
foreach ($id in $definitions.Keys) {
    $source, $profiles = $definitions[$id], $expected[$id]
    Require-Text $source 'behaviorType\s*=\s*"raycast"' "non-charged laser $id is missing raycast behavior"
    foreach ($index in 0..3) {
        $field = @("fxProfile", "muzzleFxProfile", "impactFxProfile", "soundProfileId")[$index]
        Require-Text $source "$field\s*=\s*`"$($profiles[$index])`"" "non-charged laser $id has invalid $field"
    }
    if ($source -match 'family\s*=') { Add-Issue "non-charged laser $id must not use family for runtime dispatch" }
}
foreach ($token in @('behaviorType = "raycast"', 'muzzleFxProfile = tier.fx', 'impactFxProfile = tier.fx', 'soundProfileId = tier.fx', 'muzzleFxProfile = "disruptor"', 'muzzleFxProfile = "none"')) {
    Require-Text $stellaris ([regex]::Escape($token)) "Stellaris laser/arc catalog is missing $token"
}
if ($stellaris -match 'family\s*=\s*"(?:laser|disruptor|psionic_disruptor)"') { Add-Issue "Stellaris non-charged laser definitions must not use family" }
foreach ($component in @("SMALL_RED_LASER", "SMALL_GAMMA_LASER", "SMALL_NV_WEAPON", "SMALL_DISRUPTOR_1", "PSIONIC_LIGHTNING")) {
    $row = [regex]::Match($generated, "(?m)^.*component = `"$component`".*$").Value
    foreach ($token in @('behaviorType = "raycast"', "fxProfile =", "muzzleFxProfile =", "impactFxProfile =", "soundProfileId =")) {
        Require-Text $row ([regex]::Escape($token)) "generated non-charged laser $component is missing $token"
    }
    if ($row -match 'family =') { Add-Issue "generated non-charged laser $component must not use family" }
}

$runtime = (Read-Required "script\weapon\client\common\effects\generic_raycast_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\common\effects\gamma_laser_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\common\effects\weapon_muzzle_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\common\effects\weapon_impact_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\common\sound\sound_service.lua") + "`n" +
    (Read-Required "script\weapon\client\common\sound\weapon_sound_catalog.lua")
foreach ($field in @("definition.muzzleFxProfile", "definition.impactFxProfile", "definition.soundProfileId", "spawnGammaLaserMuzzleFx")) {
    Require-Text $runtime ([regex]::Escape($field)) "non-charged runtime does not dispatch $field"
}

Write-Host "=== Non-Charged Laser Definition Checker ===" -ForegroundColor Cyan
if ($issues -gt 0) { Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red; exit 1 }
Write-Host "OK - non-charged laser definitions and profile dispatch are valid." -ForegroundColor Green
exit 0
