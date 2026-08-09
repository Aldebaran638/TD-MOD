# Non-charged laser/arc-ray definition and profile-dispatch checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
function Add-Issue { param([string]$Message); Write-Host "[NONCHARGED LASER ERROR] $Message" -ForegroundColor Red; $script:issues++ }
function Read-Required { param([string]$Relative); $path = Join-Path $script:root $Relative; if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Issue "missing file: $Relative"; return "" }; return [IO.File]::ReadAllText($path) }
function Require-Text { param([string]$Source, [string]$Pattern, [string]$Message); if ($Source -notmatch $Pattern) { Add-Issue $Message } }
function Select-Definition { param([string]$Source, [string]$Id); $marker = "weaponType = `"$Id`""; $index = $Source.IndexOf($marker); if ($index -lt 0) { return "" }; $start = [Math]::Max(0, $index - 300); $tail = $Source.Substring($start); $end = $tail.IndexOf("`n})", $index - $start); if ($end -lt 0) { return $tail }; return $tail.Substring(0, $end + 3) }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path -LiteralPath $Path).Path
$schema = Read-Required "script\data\weapons\schema.lua"
$stellaris = (Read-Required "script\data\weapons\s\stellaris.lua") + (Read-Required "script\data\weapons\m\stellaris.lua") + (Read-Required "script\data\weapons\l\stellaris.lua") + (Read-Required "script\data\weapons\x\stellaris.lua") + (Read-Required "script\data\weapons\p\stellaris.lua")
$definitions = @{
    largeGammaLaser = Select-Definition $stellaris "largeGammaLaser"
    mediumGammaLaser = Select-Definition $stellaris "mediumGammaLaser"
    psionicLightning = Select-Definition $stellaris "psionicLightning"
    phaseDisruptor = Select-Definition $stellaris "phaseDisruptor"
    guardianPointDefense = Select-Definition $stellaris "guardianPointDefense"
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
}
foreach ($token in @('behaviorType = "raycast"', 'muzzleFxProfile = "disruptor"', 'muzzleFxProfile = "none"')) {
    Require-Text $stellaris ([regex]::Escape($token)) "Stellaris laser/arc catalog is missing $token"
}
if ($stellaris -match 'family\s*=\s*"(?:laser|disruptor|psionic_disruptor)"') { Add-Issue "Stellaris non-charged laser definitions must not use family" }
$runtime = (Read-Required "script\weapon\client\presentation\visual\phase\beam\default.lua") + "`n" +
    (Read-Required "script\weapon\client\presentation\visual\phase\beam\gamma.lua") + "`n" +
    (Read-Required "script\weapon\client\presentation\visual\phase\muzzle\default.lua") + "`n" +
    (Read-Required "script\weapon\client\presentation\visual\phase\impact\default.lua") + "`n" +
    (Read-Required "script\weapon\client\presentation\audio\sound_service.lua") + "`n" +
    (Read-Required "script\weapon\client\presentation\audio\weapon_sound_catalog.lua")
foreach ($field in @("definition.muzzleFxProfile", "definition.impactFxProfile", "definition.soundProfileId", "spawnGammaLaserMuzzleFx")) {
    Require-Text $runtime ([regex]::Escape($field)) "non-charged runtime does not dispatch $field"
}

Write-Host "=== Non-Charged Laser Definition Checker ===" -ForegroundColor Cyan
if ($issues -gt 0) { Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red; exit 1 }
Write-Host "OK - non-charged laser definitions and profile dispatch are valid." -ForegroundColor Green
exit 0
