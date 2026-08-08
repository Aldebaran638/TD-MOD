# Charged-ray weapon definition and profile-dispatch checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
function Add-Issue { param([string]$Message); Write-Host "[CHARGED WEAPON ERROR] $Message" -ForegroundColor Red; $script:issues++ }
function Read-Required { param([string]$Relative); $path = Join-Path $script:root $Relative; if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Issue "missing file: $Relative"; return "" }; return [IO.File]::ReadAllText($path) }
function Require-Text { param([string]$Source, [string]$Pattern, [string]$Message); if ($Source -notmatch $Pattern) { Add-Issue $Message } }
function Select-Definition { param([string]$Source, [string]$Id); $marker = "weaponType = `"$Id`""; $index = $Source.IndexOf($marker); if ($index -lt 0) { return "" }; $start = [Math]::Max(0, $index - 300); $tail = $Source.Substring($start); $end = $tail.IndexOf("`n})", $index - $start); if ($end -lt 0) { return $tail }; return $tail.Substring(0, $end + 3) }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path -LiteralPath $Path).Path
$schema = Read-Required "script\data\weapons\schema.lua"
$stellaris = (Read-Required "script\data\weapons\x\stellaris.lua") + "`n" + (Read-Required "script\data\weapons\t\stellaris.lua")
$definitions = @{
    tachyonLance = Select-Definition $stellaris "tachyonLance"
    focusedArcEmitter = Select-Definition $stellaris "focusedArcEmitter"
    perditionBeam = Select-Definition $stellaris "perditionBeam"
    particleLance = Select-Definition $stellaris "particleLance"
    arcEmitter = Select-Definition $stellaris "arcEmitter"
}

foreach ($token in @("weaponChargeFxProfiles", "weaponFxProfiles", "weaponImpactFxProfiles", "weaponSoundProfiles", 'controllerType or "") == "chargedRay"', "has invalid chargeFxProfile")) {
    Require-Text $schema ([regex]::Escape($token)) "schema is missing charged-ray contract: $token"
}
foreach ($id in $definitions.Keys) {
    $source = $definitions[$id]
    foreach ($field in @("chargeFxProfile", "fxProfile", "impactFxProfile", "soundProfileId")) {
        Require-Text $source ("$field\s*=\s*`"[A-Za-z0-9_]+`"") "charged weapon $id is missing $field"
    }
    Require-Text $source 'controllerType\s*=\s*"chargedRay"' "charged weapon $id is missing controllerType = chargedRay"
}

$runtime = (Read-Required "script\weapon\client\slots\x\tachyon_lance\effects\charging_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\slots\x\focused_arc_emitter\effects\charging_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\slots\t\perdition_beam\effects\charging_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\slots\x\tachyon_lance\effects\beam_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\slots\x\tachyon_lance\effects\impact_fx.lua") + "`n" +
    (Read-Required "script\weapon\client\common\sound\sound_service.lua")
foreach ($field in @("definition.chargeFxProfile", "definition.fxProfile", "definition.impactFxProfile", "definition.soundProfileId")) {
    Require-Text $runtime ([regex]::Escape($field)) "charged runtime does not dispatch $field"
}

Write-Host "=== Charged Weapon Definition Checker ===" -ForegroundColor Cyan
if ($issues -gt 0) { Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red; exit 1 }
Write-Host "OK - charged weapon definitions and profile dispatch are valid." -ForegroundColor Green
exit 0
