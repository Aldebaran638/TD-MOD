# Complete player and AI ship definition contract checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0

function Add-Issue {
    param([string]$Message)
    Write-Host "[SHIPS ERROR] $Message" -ForegroundColor Red
    $script:issues++
}

function Remove-LuaComments {
    param([string]$Source)
    $result = [regex]::Replace($Source, '(?s)--\[\[.*?\]\]', ' ')
    return [regex]::Replace($result, '(?m)--[^\r\n]*', ' ')
}

function Skip-LuaTrivia {
    param([string]$Source, [int]$Index)
    while ($Index -lt $Source.Length -and [char]::IsWhiteSpace($Source[$Index])) { $Index++ }
    return $Index
}

function Find-MatchingBrace {
    param([string]$Source, [int]$OpenIndex)
    $depth = 0
    $quote = [char]0
    for ($i = $OpenIndex; $i -lt $Source.Length; $i++) {
        $ch = $Source[$i]
        if ($quote -ne [char]0) {
            if ($ch -eq '\' -and $i + 1 -lt $Source.Length) { $i++ }
            elseif ($ch -eq $quote) { $quote = [char]0 }
            continue
        }
        if ($ch -eq '"' -or $ch -eq "'") { $quote = $ch; continue }
        if ($ch -eq '{') { $depth++ }
        elseif ($ch -eq '}') {
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
                $entries += [pscustomobject]@{ Key = $key; ValueStart = $valueStart; ValueEnd = $valueEnd }
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

function Find-DefinitionTable {
    param([string]$Source, [string]$VariableName)
    $pattern = if ($VariableName -eq "") {
        'shipDefinitionRegister\s*\(\s*\{'
    } else {
        "(?m)\b$([regex]::Escape($VariableName))\s*=\s*\{"
    }
    $match = [regex]::Match($Source, $pattern)
    if (-not $match.Success) { return $null }
    $open = $Source.IndexOf('{', $match.Index, $match.Length)
    $close = Find-MatchingBrace $Source $open
    if ($close -lt 0) { return $null }
    return [pscustomobject]@{ Open = $open; Close = $close }
}

function Get-NamedEntry {
    param([object[]]$Entries, [string]$Name)
    return @($Entries | Where-Object { $_.Key -eq $Name })[0]
}

function Require-ExactKeys {
    param([object[]]$Entries, [string[]]$Expected, [string]$Context)
    $seen = @{}
    foreach ($entry in $Entries) {
        if ($seen.ContainsKey($entry.Key)) { Add-Issue "$Context contains duplicate field: $($entry.Key)" }
        $seen[$entry.Key] = $true
        if ($Expected -notcontains $entry.Key) { Add-Issue "$Context contains unknown field: $($entry.Key)" }
    }
    foreach ($key in $Expected) {
        if (-not $seen.ContainsKey($key)) { Add-Issue "$Context is missing required field: $key" }
    }
}

function Validate-NestedTable {
    param([string]$Source, [object]$Entry, [string[]]$Required, [string]$Context, [string[]]$Allowed = $Required)
    if ($null -eq $Entry -or $Entry.ValueStart -ge $Source.Length -or $Source[$Entry.ValueStart] -ne '{') {
        Add-Issue "$Context must be a table"
        return @()
    }
    $entries = Get-TableEntries $Source $Entry.ValueStart $Entry.ValueEnd
    $seen = @{}
    foreach ($entry in $entries) {
        if ($seen.ContainsKey($entry.Key)) { Add-Issue "$Context contains duplicate field: $($entry.Key)" }
        $seen[$entry.Key] = $true
        if ($Allowed -notcontains $entry.Key) { Add-Issue "$Context contains unknown field: $($entry.Key)" }
    }
    foreach ($key in $Required) {
        if (-not $seen.ContainsKey($key)) { Add-Issue "$Context is missing required field: $key" }
    }
    return $entries
}

function Get-DirectChildTables {
    param([string]$Source, [int]$OpenIndex, [int]$CloseIndex)
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
    return $children
}

function Assert-LiteralField {
    param([string]$Source, [object]$Entry, [string]$Pattern, [string]$Message)
    if ($null -eq $Entry) { return }
    $end = $Entry.ValueEnd
    if ($end -eq $Entry.ValueStart) {
        while ($end -lt $Source.Length -and $Source[$end] -notmatch '[,}\r\n]') { $end++ }
    }
    $value = $Source.Substring($Entry.ValueStart, [Math]::Max(0, $end - $Entry.ValueStart)).Trim()
    if ($value -notmatch $Pattern) { Add-Issue $Message }
}

$playerFields = @("shipType", "displayName", "englishName", "controlMode", "maxShieldHP", "maxArmorHP", "maxBodyHP", "shieldRadius", "flightProfile", "engineFx", "engineSound", "cameraProfile", "regen", "componentProfile", "externalDamage", "weaponMountProfiles", "defaultSlotConfigurationId", "slotConfigurations")
$aiFields = @("shipType", "displayName", "englishName", "controlMode", "interceptorClass", "maxShieldHP", "maxArmorHP", "maxBodyHP", "shieldRadius")
$flightFields = @("gravityCompensation", "disableLiftVoxelRatio", "forwardAcceleration", "backwardAcceleration", "maxCombatSpeed", "maxReverseSpeed", "quadraticDamping", "dampingMinSpeed", "attitude", "roll")
$attitudeFields = @("yawDeadzone", "pitchDeadzone", "yawSoftZone", "pitchSoftZone", "yawForceGain", "pitchForceGain", "yawForceMax", "pitchForceMax", "yawDamping", "pitchDamping", "yawRateDeadzone", "pitchRateDeadzone", "yawLeverArm", "pitchLeverArm")
$rollFields = @("deadzone", "forceGain", "forceMax", "damping", "rateDeadzone", "leverArm", "sign")
$engineFields = @("speedForFullTrail", "throttleResponse", "particleRate", "maxParticleBurstsPerFrame", "particleNearDistance", "particleCutoffDistance", "renderCutoffDistance", "idleParticleRateScale", "farParticleRateScale", "profiles")
$engineRequired = $engineFields | Where-Object { $_ -ne "profiles" }
$cameraFields = @("distance", "distanceMin", "distanceMax", "pitchLimit", "rearYawMin", "rearYawMax", "mouseSensitivity", "glideStrength", "zoomSpeed", "switchDuration", "frontOffset", "frontPitchLimit", "frontYawMin", "frontYawMax", "rearDefaultPitch", "freelookTurnYawError", "freelookTurnPitchError", "rmbLongPressSeconds", "fov")
$regenFields = @("tickInterval", "shieldPerSecond", "shieldNoDamageDelay", "armorNoDamageDelay", "bodyNoDamageDelay")
$componentFields = @("baseArmorRegenPercent", "baseHullRegenPercent")
$damageFields = @("bulletDamage", "explosionMinStrength", "explosionMaxDistance", "explosionDamageScale")

function Validate-PlayerDefinition {
    param([string]$Source, [object]$Table, [hashtable]$Spec)
    $top = Get-TableEntries $Source $Table.Open $Table.Close
    Require-ExactKeys $top $playerFields "$($Spec.ShipType) definition"
    Assert-LiteralField $Source (Get-NamedEntry $top "shipType") ('^"' + $Spec.ShipType + '"$') "$($Spec.ShipType) has an invalid shipType"
    Assert-LiteralField $Source (Get-NamedEntry $top "controlMode") '^"player"$' "$($Spec.ShipType) must use controlMode player"
    $flight = Validate-NestedTable $Source (Get-NamedEntry $top "flightProfile") $flightFields "$($Spec.ShipType).flightProfile"
    $null = Validate-NestedTable $Source (Get-NamedEntry $flight "attitude") $attitudeFields "$($Spec.ShipType).flightProfile.attitude"
    $null = Validate-NestedTable $Source (Get-NamedEntry $flight "roll") $rollFields "$($Spec.ShipType).flightProfile.roll"
    $engine = Validate-NestedTable $Source (Get-NamedEntry $top "engineFx") $engineRequired "$($Spec.ShipType).engineFx" $engineFields
    $null = Validate-NestedTable $Source (Get-NamedEntry $top "engineSound") @("idleLoopPath", "volume") "$($Spec.ShipType).engineSound"
    $null = Validate-NestedTable $Source (Get-NamedEntry $top "cameraProfile") $cameraFields "$($Spec.ShipType).cameraProfile"
    $null = Validate-NestedTable $Source (Get-NamedEntry $top "regen") $regenFields "$($Spec.ShipType).regen"
    $null = Validate-NestedTable $Source (Get-NamedEntry $top "componentProfile") $componentFields "$($Spec.ShipType).componentProfile"
    $null = Validate-NestedTable $Source (Get-NamedEntry $top "externalDamage") $damageFields "$($Spec.ShipType).externalDamage"

    $configs = Get-NamedEntry $top "slotConfigurations"
    if ($null -eq $configs -or $Source[$configs.ValueStart] -ne '{') { Add-Issue "$($Spec.ShipType).slotConfigurations must be a table"; return }
    $children = Get-DirectChildTables $Source $configs.ValueStart $configs.ValueEnd
    if ($children.Count -eq 0) { Add-Issue "$($Spec.ShipType).slotConfigurations has no entries" }
    foreach ($child in $children) {
        $configuration = Get-TableEntries $Source $child.Open $child.Close
        $configurationFields = @("configurationId", "label", "legacyConfigurationIds", "slotGroups", "defaultLoadout", "componentSlots", "defaultComponentLoadout")
        foreach ($required in @("configurationId", "label", "slotGroups", "defaultLoadout", "componentSlots", "defaultComponentLoadout")) {
            if ($null -eq (Get-NamedEntry $configuration $required)) { Add-Issue "$($Spec.ShipType) slot configuration is missing required field: $required" }
        }
        foreach ($entry in $configuration) {
            if ($configurationFields -notcontains $entry.Key) { Add-Issue "$($Spec.ShipType) slot configuration contains unknown field: $($entry.Key)" }
        }
    }
}

function Validate-AiDefinition {
    param([string]$Source, [object]$Table, [hashtable]$Spec)
    $top = Get-TableEntries $Source $Table.Open $Table.Close
    $expected = @($aiFields)
    if ($Spec.InterceptorClass -eq "strike_craft") { $expected += "externalDamage" }
    Require-ExactKeys $top $expected "$($Spec.ShipType) definition"
    Assert-LiteralField $Source (Get-NamedEntry $top "shipType") ('^"' + $Spec.ShipType + '"$') "$($Spec.ShipType) has an invalid shipType"
    Assert-LiteralField $Source (Get-NamedEntry $top "controlMode") '^"ai"$' "$($Spec.ShipType) must use controlMode ai"
    Assert-LiteralField $Source (Get-NamedEntry $top "interceptorClass") ('^"' + $Spec.InterceptorClass + '"$') "$($Spec.ShipType) has an invalid interceptorClass"
    if ($Spec.InterceptorClass -eq "strike_craft") {
        $null = Validate-NestedTable $Source (Get-NamedEntry $top "externalDamage") $damageFields "$($Spec.ShipType).externalDamage"
    }
}

Write-Host "=== Ship Definition Checker ===" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Add-Issue "Mod directory does not exist: $Path" }
$root = (Resolve-Path -LiteralPath $Path).Path
$shipsRoot = Join-Path $root "script\data\ships"
$schemaPath = Join-Path $shipsRoot "schema.lua"
$catalogPath = Join-Path $shipsRoot "ship_catalog.lua"
foreach ($required in @($schemaPath, $catalogPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { Add-Issue "missing required file: $required" }
}

$definitions = @(
    @{ RelativePath = "battlecruiser\battlecruiser.lua"; Table = ""; ShipType = "enigmaticCruiser"; Mode = "player" },
    @{ RelativePath = "titan\titan.lua"; Table = ""; ShipType = "titan"; Mode = "player" },
    @{ RelativePath = "advanced_strike_craft\advanced_strike_craft.lua"; Table = ""; ShipType = "advancedStrikeCraft"; Mode = "ai"; InterceptorClass = "strike_craft" },
    @{ RelativePath = "advanced_swarmer_missile\advanced_swarmer_missile.lua"; Table = ""; ShipType = "advancedSwarmerMissile"; Mode = "ai"; InterceptorClass = "missile" },
    @{ RelativePath = "devastator_torpedo\devastator_torpedo.lua"; Table = ""; ShipType = "devastatorTorpedo"; Mode = "ai"; InterceptorClass = "torpedo" }
)

foreach ($spec in $definitions) {
    $path = Join-Path $shipsRoot $spec.RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Add-Issue "missing definition: $path"; continue }
    $source = Remove-LuaComments ([IO.File]::ReadAllText($path))
    $table = Find-DefinitionTable $source $spec.Table
    if ($null -eq $table) { Add-Issue "$($spec.ShipType) definition table is missing or malformed"; continue }
    if ($spec.Mode -eq "player") { Validate-PlayerDefinition $source $table $spec }
    else { Validate-AiDefinition $source $table $spec }
}

if (Test-Path -LiteralPath $schemaPath -PathType Leaf) {
    $schema = [IO.File]::ReadAllText($schemaPath)
    foreach ($symbol in @("shipDefinitionRegister", "shipDefinitionIsPlayerControlled", "shipDefinitionIsAiControlled", "shipDefinitionIsPlayerConfigurable", "shipDefinitionIsPlayerLockable", "_validatePlayerDefinition", "_validateAiDefinition")) {
        if ($schema -notmatch ("function\s+" + [regex]::Escape($symbol) + "\b")) { Add-Issue "schema.lua is missing $symbol" }
    }
    if ($schema -notmatch 'controlMode') { Add-Issue "schema.lua does not validate controlMode" }
}

if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
    $catalog = Remove-LuaComments ([IO.File]::ReadAllText($catalogPath))
    $includes = @([regex]::Matches($catalog, '(?m)^\s*#include\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $expectedIncludes = @("schema.lua", "advanced_strike_craft/advanced_strike_craft.lua", "advanced_swarmer_missile/advanced_swarmer_missile.lua", "devastator_torpedo/devastator_torpedo.lua", "battlecruiser/battlecruiser.lua", "titan/titan.lua")
    if ($includes.Count -ne $expectedIncludes.Count) { Add-Issue "ship_catalog.lua has an unexpected include count" }
    for ($i = 0; $i -lt [Math]::Min($includes.Count, $expectedIncludes.Count); $i++) {
        if ($includes[$i] -ne $expectedIncludes[$i]) { Add-Issue "ship_catalog.lua include order or path is invalid at index $i" }
    }
}

if ($issues -gt 0) { Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red; exit 1 }
Write-Host "OK - all player and AI ship definitions, schema, and catalog are valid." -ForegroundColor Green
exit 0
