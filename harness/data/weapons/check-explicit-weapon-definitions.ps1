# Explicit per-slot weapon definition checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
$allowedFunctions = @(
    "weaponDefineRay",
    "weaponDefineProjectile",
    "weaponDefineGuided",
    "weaponDefineStrikeCraft"
)
$allowedPattern = [string]::Join("|", ($allowedFunctions | ForEach-Object { [regex]::Escape($_) }))
$definitionPattern = "(?s)\b(?:$allowedPattern)\s*\(\s*\{.*?\}\s*\)"

function Add-Issue {
    param([string]$Message)
    Write-Host "[EXPLICIT WEAPON ERROR] $Message" -ForegroundColor Red
    $script:issues++
}

function Remove-LuaComments {
    param([string]$Source)
    $result = [regex]::Replace($Source, '(?s)--\[\[.*?\]\]', ' ')
    $result = [regex]::Replace($result, '(?m)--[^\r\n]*', ' ')
    return $result
}

function Remove-LuaTrivia {
    param([string]$Source)
    $result = Remove-LuaComments $Source
    $result = [regex]::Replace($result, '(?s)"(?:\\.|[^"\\])*"', '""')
    $result = [regex]::Replace($result, "(?s)'(?:\\.|[^'\\])*'", "''")
    return $result
}

Write-Host "=== Explicit Weapon Definition Checker ===" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

$root = (Resolve-Path -LiteralPath $Path).Path
$weaponsRoot = Join-Path $root "script\data\weapons"
if (-not (Test-Path -LiteralPath $weaponsRoot -PathType Container)) {
    Write-Host "[ERROR] Weapon directory does not exist: $weaponsRoot" -ForegroundColor Red
    exit 1
}

$weaponIds = @{}
foreach ($slot in @("s", "g", "h", "l", "m", "p", "t", "x")) {
    $slotRoot = Join-Path $weaponsRoot $slot
    $definitionPath = Join-Path $slotRoot "stellaris.lua"
    if (-not (Test-Path -LiteralPath $definitionPath -PathType Leaf)) {
        Add-Issue "missing slot definition: $slot\stellaris.lua"
        continue
    }

    $extraLua = @(Get-ChildItem -LiteralPath $slotRoot -Filter "*.lua" -File | Where-Object { $_.Name -ne "stellaris.lua" })
    foreach ($file in $extraLua) {
        Add-Issue "slot $($slot.ToUpperInvariant()) has an extra Lua definition file: $($file.Name)"
    }

    $source = [IO.File]::ReadAllText($definitionPath)
    $code = Remove-LuaTrivia $source
    if ($code -match '\b(for|while|repeat)\b') {
        Add-Issue "slot $($slot.ToUpperInvariant()) uses a loop to define weapons"
    }
    if ($code -match '\b(local\s+function|function)\b') {
        Add-Issue "slot $($slot.ToUpperInvariant()) declares a helper function"
    }

    foreach ($call in [regex]::Matches($code, '\b([A-Za-z_][A-Za-z0-9_]*)\s*\(')) {
        $name = $call.Groups[1].Value
        if ($allowedFunctions -notcontains $name) {
            Add-Issue "slot $($slot.ToUpperInvariant()) calls unsupported function: $name"
        }
    }

    $definitionSource = Remove-LuaComments $source
    $definitions = @([regex]::Matches($definitionSource, $definitionPattern))
    if ($definitions.Count -eq 0) {
        Add-Issue "slot $($slot.ToUpperInvariant()) has no direct weapon definitions"
        continue
    }

    foreach ($definition in $definitions) {
        $weaponTypeMatches = @([regex]::Matches($definition.Value, 'weaponType\s*=\s*"([^"]+)"'))
        if ($weaponTypeMatches.Count -ne 1) {
            Add-Issue "slot $($slot.ToUpperInvariant()) definition must contain exactly one literal weaponType"
            continue
        }

        $weaponType = $weaponTypeMatches[0].Groups[1].Value
        if ($weaponIds.ContainsKey($weaponType)) {
            Add-Issue "weaponType $weaponType is defined more than once ($($weaponIds[$weaponType]) and $($slot.ToUpperInvariant()))"
        } else {
            $weaponIds[$weaponType] = $slot.ToUpperInvariant()
        }

        $slotMatches = @([regex]::Matches($definition.Value, 'slotTypes\s*=\s*\{\s*"([A-Za-z0-9]+)"\s*\}'))
        if ($slotMatches.Count -ne 1 -or $slotMatches[0].Groups[1].Value -ne $slot.ToUpperInvariant()) {
            Add-Issue "weapon $weaponType must declare only slotTypes = { `"$($slot.ToUpperInvariant())`" }"
        }
    }

    $outsideDefinitions = [regex]::Replace($definitionSource, $definitionPattern, ' ')
    $outsideDefinitions = Remove-LuaTrivia $outsideDefinitions
    if (-not [string]::IsNullOrWhiteSpace($outsideDefinitions)) {
        Add-Issue "slot $($slot.ToUpperInvariant()) contains a batch table, wrapper, assignment, or other top-level structure"
    }
}

if ($issues -gt 0) {
    Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red
    exit 1
}

Write-Host "OK - all slot weapons use separate direct definitions." -ForegroundColor Green
exit 0
