# Battlecruiser ship definition completeness and strict field checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0

function Add-Issue {
    param([string]$Message)
    Write-Host "[BATTLECRUISER ERROR] $Message" -ForegroundColor Red
    $script:issues++
}

function Remove-LuaComments {
    param([string]$Source)
    $result = [regex]::Replace($Source, '(?s)--\[\[.*?\]\]', ' ')
    return [regex]::Replace($result, '(?m)--[^\r\n]*', ' ')
}

function Skip-LuaTrivia {
    param([string]$Source, [int]$Index)
    while ($Index -lt $Source.Length) {
        if ([char]::IsWhiteSpace($Source[$Index])) {
            $Index++
            continue
        }
        return $Index
    }
    return $Index
}

function Find-MatchingBrace {
    param([string]$Source, [int]$OpenIndex)
    $depth = 0
    $quote = [char]0
    for ($i = $OpenIndex; $i -lt $Source.Length; $i++) {
        $ch = $Source[$i]
        if ($quote -ne [char]0) {
            if ($ch -eq '\' -and $i + 1 -lt $Source.Length) {
                $i++
            } elseif ($ch -eq $quote) {
                $quote = [char]0
            }
            continue
        }
        if ($ch -eq '"' -or $ch -eq "'") {
            $quote = $ch
            continue
        }
        if ($ch -eq '{') {
            $depth++
        } elseif ($ch -eq '}') {
            $depth--
            if ($depth -eq 0) { return $i }
        }
    }
    return -1
}

function Get-TableEntries {
    param([string]$Source, [int]$OpenIndex, [int]$CloseIndex)
    $entries = @()
    $depth = 0
    $quote = [char]0
    $i = $OpenIndex + 1
    while ($i -lt $CloseIndex) {
        $ch = $Source[$i]
        if ($quote -ne [char]0) {
            if ($ch -eq '\' -and $i + 1 -lt $CloseIndex) { $i += 2; continue }
            if ($ch -eq $quote) { $quote = [char]0 }
            $i++
            continue
        }
        if ($ch -eq '"' -or $ch -eq "'") { $quote = $ch; $i++; continue }
        if ($ch -eq '{') { $depth++; $i++; continue }
        if ($ch -eq '}') { $depth--; $i++; continue }
        if ($depth -eq 0 -and ($ch -match '[A-Za-z_]')) {
            $keyStart = $i
            $i++
            while ($i -lt $CloseIndex -and $Source[$i] -match '[A-Za-z0-9_]') { $i++ }
            $key = $Source.Substring($keyStart, $i - $keyStart)
            $equals = Skip-LuaTrivia $Source $i
            if ($equals -lt $CloseIndex -and $Source[$equals] -eq '=') {
                $valueStart = Skip-LuaTrivia $Source ($equals + 1)
                $valueEnd = $valueStart
                if ($valueStart -lt $CloseIndex -and $Source[$valueStart] -eq '{') {
                    $valueEnd = Find-MatchingBrace $Source $valueStart
                }
                $entries += [pscustomobject]@{
                    Key = $key
                    ValueStart = $valueStart
                    ValueEnd = $valueEnd
                }
                $i = $valueStart
                continue
            }
            $i = $keyStart + 1
            continue
        }
        $i++
    }
    return $entries
}

function Find-NamedTable {
    param([string]$Source, [string]$Name)
    $match = [regex]::Match($Source, "(?m)\b$([regex]::Escape($Name))\s*=\s*\{")
    if (-not $match.Success) { return $null }
    $open = $Source.IndexOf('{', $match.Index, $match.Length)
    $close = Find-MatchingBrace $Source $open
    if ($close -lt 0) { return $null }
    return [pscustomobject]@{ Open = $open; Close = $close }
}

function Require-ExactKeys {
    param([object[]]$Entries, [string[]]$Required, [string[]]$Allowed, [string]$Context)
    $seen = @{}
    foreach ($entry in $Entries) {
        if ($seen.ContainsKey($entry.Key)) { Add-Issue "$Context contains duplicate field: $($entry.Key)" }
        $seen[$entry.Key] = $true
        if ($Allowed -notcontains $entry.Key) { Add-Issue "$Context contains unknown field: $($entry.Key)" }
    }
    foreach ($key in $Required) {
        if (-not $seen.ContainsKey($key)) { Add-Issue "$Context is missing required field: $key" }
    }
}

function Get-NamedEntry {
    param([object[]]$Entries, [string]$Name)
    return @($Entries | Where-Object { $_.Key -eq $Name })[0]
}

function Validate-NestedTable {
    param([string]$Source, [object]$Entry, [string[]]$Required, [string[]]$Allowed, [string]$Context)
    if ($null -eq $Entry -or $Entry.ValueStart -ge $Source.Length -or $Source[$Entry.ValueStart] -ne '{') {
        Add-Issue "$Context must be a table"
        return $null
    }
    $entries = Get-TableEntries $Source $Entry.ValueStart $Entry.ValueEnd
    Require-ExactKeys $entries $Required $Allowed $Context
    return $entries
}

function Validate-DirectChildTables {
    param([string]$Source, [int]$OpenIndex, [int]$CloseIndex, [string]$Context)
    $children = @()
    $depth = 0
    $quote = [char]0
    for ($i = $OpenIndex + 1; $i -lt $CloseIndex; $i++) {
        $ch = $Source[$i]
        if ($quote -ne [char]0) {
            if ($ch -eq '\' -and $i + 1 -lt $CloseIndex) { $i++ }
            elseif ($ch -eq $quote) { $quote = [char]0 }
            continue
        }
        if ($ch -eq '"' -or $ch -eq "'") { $quote = $ch; continue }
        if ($ch -eq '{') {
            if ($depth -eq 0) {
                $childClose = Find-MatchingBrace $Source $i
                if ($childClose -gt $i) { $children += [pscustomobject]@{ Open = $i; Close = $childClose } }
            }
            $depth++
        } elseif ($ch -eq '}') { $depth-- }
    }
    if ($children.Count -eq 0) { Add-Issue "$Context has no entries" }
    return $children
}

function Assert-LiteralField {
    param([string]$Source, [object]$Entry, [string]$Pattern, [string]$Message)
    if ($null -eq $Entry) { return }
    $end = $Entry.ValueEnd
    if ($end -eq $Entry.ValueStart) {
        $end = $Entry.ValueStart
        while ($end -lt $Source.Length -and $Source[$end] -notmatch '[,}\r\n]') { $end++ }
    }
    $value = $Source.Substring($Entry.ValueStart, [Math]::Max(0, $end - $Entry.ValueStart))
    $value = $value.Trim()
    if ($value -notmatch $Pattern) { Add-Issue $Message }
}

Write-Host "=== Battlecruiser Definition Checker ===" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

$root = (Resolve-Path -LiteralPath $Path).Path
$shipsRoot = Join-Path $root "script\data\ships"
$definitionPath = Join-Path $shipsRoot "battlecruiser\battlecruiser.lua"
$mountsPath = Join-Path $shipsRoot "battlecruiser\battlecruiser_mounts.lua"
if (-not (Test-Path -LiteralPath $definitionPath -PathType Leaf)) { Add-Issue "missing battlecruiser definition: $definitionPath" }
if (-not (Test-Path -LiteralPath $mountsPath -PathType Leaf)) { Add-Issue "missing battlecruiser mounts: $mountsPath" }
if ($issues -gt 0) { Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red; exit 1 }

$source = Remove-LuaComments ([IO.File]::ReadAllText($definitionPath))
$table = Find-NamedTable $source "battlecruiserDefinition"
if ($null -eq $table) { Add-Issue "battlecruiserDefinition table is missing or malformed"; exit 1 }
$top = Get-TableEntries $source $table.Open $table.Close
$topAllowed = @("shipType", "displayName", "maxShieldHP", "maxArmorHP", "maxBodyHP", "shieldRadius", "flightProfile", "engineFx", "cameraProfile", "regen", "componentProfile", "componentPools", "externalDamage", "weaponMountProfiles", "defaultSlotConfigurationId", "slotConfigurations")
Require-ExactKeys $top $topAllowed $topAllowed "battlecruiserDefinition"

Assert-LiteralField $source (Get-NamedEntry $top "shipType") '^"enigmaticCruiser"$' "shipType must be enigmaticCruiser"
Assert-LiteralField $source (Get-NamedEntry $top "weaponMountProfiles") '^shipMountProfileData\.enigmaticCruiser$' "weaponMountProfiles must reference shipMountProfileData.enigmaticCruiser"

$flight = Validate-NestedTable $source (Get-NamedEntry $top "flightProfile") @("gravityCompensation", "disableLiftVoxelRatio", "forwardAcceleration", "backwardAcceleration", "maxCombatSpeed", "maxReverseSpeed", "quadraticDamping", "dampingMinSpeed", "attitude", "roll") @("gravityCompensation", "disableLiftVoxelRatio", "forwardAcceleration", "backwardAcceleration", "maxCombatSpeed", "maxReverseSpeed", "quadraticDamping", "dampingMinSpeed", "attitude", "roll") "flightProfile"
if ($null -ne $flight) {
    $attitude = Validate-NestedTable $source (Get-NamedEntry $flight "attitude") @("yawDeadzone", "pitchDeadzone", "yawSoftZone", "pitchSoftZone", "yawForceGain", "pitchForceGain", "yawForceMax", "pitchForceMax", "yawDamping", "pitchDamping", "yawRateDeadzone", "pitchRateDeadzone", "yawLeverArm", "pitchLeverArm") @("yawDeadzone", "pitchDeadzone", "yawSoftZone", "pitchSoftZone", "yawForceGain", "pitchForceGain", "yawForceMax", "pitchForceMax", "yawDamping", "pitchDamping", "yawRateDeadzone", "pitchRateDeadzone", "yawLeverArm", "pitchLeverArm") "flightProfile.attitude"
    $null = Validate-NestedTable $source (Get-NamedEntry $flight "roll") @("deadzone", "forceGain", "forceMax", "damping", "rateDeadzone", "leverArm", "sign") @("deadzone", "forceGain", "forceMax", "damping", "rateDeadzone", "leverArm", "sign") "flightProfile.roll"
}

$engine = Validate-NestedTable $source (Get-NamedEntry $top "engineFx") @("speedForFullTrail", "throttleResponse", "particleRate", "maxParticleBurstsPerFrame", "particleNearDistance", "particleCutoffDistance", "renderCutoffDistance", "idleParticleRateScale", "farParticleRateScale") @("speedForFullTrail", "throttleResponse", "particleRate", "maxParticleBurstsPerFrame", "particleNearDistance", "particleCutoffDistance", "renderCutoffDistance", "idleParticleRateScale", "farParticleRateScale", "profiles") "engineFx"
if ($null -ne $engine) {
    $profilesEntry = Get-NamedEntry $engine "profiles"
    $profiles = $null
    if ($null -ne $profilesEntry) {
        $profiles = Validate-NestedTable $source $profilesEntry @() @("thruster", "smallThruster", "engine") "engineFx.profiles"
    }
    if ($null -ne $profiles) {
        $null = Validate-NestedTable $source (Get-NamedEntry $profiles "thruster") @() @("radius", "localOffset", "sourceOffset", "idleLength", "trailLength", "particleRadius") "engineFx.profiles.thruster"
        $null = Validate-NestedTable $source (Get-NamedEntry $profiles "smallThruster") @() @("radius", "localOffset", "sourceOffset", "idleLength", "trailLength", "particleRadius") "engineFx.profiles.smallThruster"
        $null = Validate-NestedTable $source (Get-NamedEntry $profiles "engine") @() @("radius", "burnAreaMin", "burnAreaMax", "burnColumns", "burnRows", "sourceOffset", "idleLength", "trailLength", "particleRadius") "engineFx.profiles.engine"
    }
}

$null = Validate-NestedTable $source (Get-NamedEntry $top "cameraProfile") @("distance", "distanceMin", "distanceMax", "pitchLimit", "rearYawMin", "rearYawMax", "mouseSensitivity", "glideStrength", "zoomSpeed", "switchDuration", "frontOffset", "frontPitchLimit", "frontYawMin", "frontYawMax", "rearDefaultPitch", "freelookTurnYawError", "freelookTurnPitchError", "rmbLongPressSeconds", "fov") @("distance", "distanceMin", "distanceMax", "pitchLimit", "rearYawMin", "rearYawMax", "mouseSensitivity", "glideStrength", "zoomSpeed", "switchDuration", "frontOffset", "frontPitchLimit", "frontYawMin", "frontYawMax", "rearDefaultPitch", "freelookTurnYawError", "freelookTurnPitchError", "rmbLongPressSeconds", "fov") "cameraProfile"
$null = Validate-NestedTable $source (Get-NamedEntry $top "regen") @("tickInterval", "shieldPerSecond", "shieldNoDamageDelay", "armorNoDamageDelay", "bodyNoDamageDelay") @("tickInterval", "shieldPerSecond", "shieldNoDamageDelay", "armorNoDamageDelay", "bodyNoDamageDelay") "regen"
$null = Validate-NestedTable $source (Get-NamedEntry $top "componentProfile") @("baseArmorRegenPercent", "baseHullRegenPercent") @("baseArmorRegenPercent", "baseHullRegenPercent") "componentProfile"
$null = Validate-NestedTable $source (Get-NamedEntry $top "externalDamage") @("bulletDamage", "explosionMinStrength", "explosionMaxDistance", "explosionDamageScale") @("bulletDamage", "explosionMinStrength", "explosionMaxDistance", "explosionDamageScale") "externalDamage"

$pools = Validate-NestedTable $source (Get-NamedEntry $top "componentPools") @("largeUtility", "auxiliary", "thruster", "sensor", "reactor") @("largeUtility", "auxiliary", "thruster", "sensor", "reactor") "componentPools"
$configEntry = Get-NamedEntry $top "slotConfigurations"
if ($null -eq $configEntry -or $configEntry.ValueStart -ge $source.Length -or $source[$configEntry.ValueStart] -ne '{') {
    Add-Issue "slotConfigurations must be a table"
} else {
    $configs = Validate-DirectChildTables $source $configEntry.ValueStart $configEntry.ValueEnd "slotConfigurations"
    if ($configs.Count -ne 2) { Add-Issue "slotConfigurations must contain exactly 2 configurations" }
    foreach ($config in $configs) {
        $entries = Get-TableEntries $source $config.Open $config.Close
        Require-ExactKeys $entries @("configurationId", "label", "slotGroups", "defaultLoadout", "componentSlots", "defaultComponentLoadout") @("configurationId", "label", "legacyConfigurationIds", "slotGroups", "defaultLoadout", "componentSlots", "defaultComponentLoadout") "slot configuration"
        $groupsEntry = Get-NamedEntry $entries "slotGroups"
        if ($null -ne $groupsEntry -and $Source[$groupsEntry.ValueStart] -eq '{') {
            foreach ($group in (Validate-DirectChildTables $source $groupsEntry.ValueStart $groupsEntry.ValueEnd "slotGroups")) {
                $groupEntries = Get-TableEntries $source $group.Open $group.Close
                Require-ExactKeys $groupEntries @("groupId", "slotType", "count") @("groupId", "slotType", "count", "automatic", "salvoGroupSize") "slot group"
            }
        }
        $componentSlotsEntry = Get-NamedEntry $entries "componentSlots"
        if ($null -ne $componentSlotsEntry -and $source[$componentSlotsEntry.ValueStart] -eq '{') {
            foreach ($slot in (Validate-DirectChildTables $source $componentSlotsEntry.ValueStart $componentSlotsEntry.ValueEnd "componentSlots")) {
                $slotEntries = Get-TableEntries $source $slot.Open $slot.Close
                Require-ExactKeys $slotEntries @("slotType", "count") @("slotType", "count") "component slot"
            }
        }
    }
}

if ($issues -gt 0) {
    Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red
    exit 1
}
Write-Host "OK - battlecruiser definition fields are complete and have no unknown fields." -ForegroundColor Green
exit 0
