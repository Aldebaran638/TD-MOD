# Explicit per-slot component definition checker.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
$slots = @(
    @{ Path = "defense\a"; SlotType = "auxiliary"; Label = "A" },
    @{ Path = "defense\l"; SlotType = "largeUtility"; Label = "L" },
    @{ Path = "core\reactor"; SlotType = "reactor"; Label = "REACTOR" },
    @{ Path = "core\thruster"; SlotType = "thruster"; Label = "THRUSTER" },
    @{ Path = "core\sensor"; SlotType = "sensor"; Label = "SENSOR" }
)
$definitionPattern = '(?s)\bshipComponentDefine\s*\(\s*\{.*?\}\s*\)'

function Add-Issue {
    param([string]$Message)
    Write-Host "[EXPLICIT COMPONENT ERROR] $Message" -ForegroundColor Red
    $script:issues++
}

function Remove-LuaComments {
    param([string]$Source)
    $result = [regex]::Replace($Source, '(?s)--\[\[.*?\]\]', ' ')
    return [regex]::Replace($result, '(?m)--[^\r\n]*', ' ')
}

function Remove-LuaTrivia {
    param([string]$Source)
    $result = Remove-LuaComments $Source
    $result = [regex]::Replace($result, '(?s)"(?:\\.|[^"\\])*"', '""')
    return [regex]::Replace($result, "(?s)'(?:\\.|[^'\\])*'", "''")
}

Write-Host "=== Explicit Component Definition Checker ===" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

$root = (Resolve-Path -LiteralPath $Path).Path
$componentsRoot = Join-Path $root "script\data\components"
$catalogPath = Join-Path $componentsRoot "component_catalog.lua"
$schemaPath = Join-Path $componentsRoot "schema.lua"
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) { Add-Issue "missing component_catalog.lua" }
if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) { Add-Issue "missing schema.lua" }

$componentIds = @{}
foreach ($slot in $slots) {
    $slotRoot = Join-Path $componentsRoot $slot.Path
    $definitionPath = Join-Path $slotRoot "stellaris.lua"
    if (-not (Test-Path -LiteralPath $definitionPath -PathType Leaf)) {
        Add-Issue "missing slot definition: $($slot.Path)\stellaris.lua"
        continue
    }
    $extraLua = @(Get-ChildItem -LiteralPath $slotRoot -Filter "*.lua" -File | Where-Object { $_.Name -ne "stellaris.lua" })
    foreach ($file in $extraLua) {
        Add-Issue "slot $($slot.Label) has an extra Lua definition file: $($file.Name)"
    }

    $source = [IO.File]::ReadAllText($definitionPath)
    $code = Remove-LuaTrivia $source
    if ($code -match '\b(for|while|repeat)\b') {
        Add-Issue "slot $($slot.Label) uses a loop to define components"
    }
    foreach ($call in [regex]::Matches($code, '\b([A-Za-z_][A-Za-z0-9_]*)\s*\(')) {
        if ($call.Groups[1].Value -ne "shipComponentDefine") {
            Add-Issue "slot $($slot.Label) calls unsupported function: $($call.Groups[1].Value)"
        }
    }

    $definitionSource = Remove-LuaComments $source
    $definitions = @([regex]::Matches($definitionSource, $definitionPattern))
    if ($definitions.Count -eq 0) {
        Add-Issue "slot $($slot.Label) has no direct component definitions"
        continue
    }
    foreach ($definition in $definitions) {
        $idMatches = @([regex]::Matches($definition.Value, 'componentId\s*=\s*"([^"]+)"'))
        if ($idMatches.Count -ne 1) {
            Add-Issue "slot $($slot.Label) definition must contain exactly one literal componentId"
            continue
        }
        $componentId = $idMatches[0].Groups[1].Value
        if ($componentIds.ContainsKey($componentId)) {
            Add-Issue "componentId $componentId is defined more than once ($($componentIds[$componentId]) and $($slot.Label))"
        } else {
            $componentIds[$componentId] = $slot.Label
        }
        $slotMatches = @([regex]::Matches($definition.Value, 'slotType\s*=\s*"([A-Za-z0-9_]+)"'))
        if ($slotMatches.Count -ne 1 -or $slotMatches[0].Groups[1].Value -ne $slot.SlotType) {
            Add-Issue "component $componentId must declare slotType = `"$($slot.SlotType)`""
        }
        foreach ($field in @("displayName", "englishName", "iconPath")) {
            if ($definition.Value -notmatch ("\b" + $field + '\s*=\s*"[^"]+"')) {
                Add-Issue "component $componentId is missing literal $field"
            }
        }
    }

    $outsideDefinitions = [regex]::Replace($definitionSource, $definitionPattern, ' ')
    $outsideDefinitions = Remove-LuaTrivia $outsideDefinitions
    if (-not [string]::IsNullOrWhiteSpace($outsideDefinitions)) {
        Add-Issue "slot $($slot.Label) contains a batch table, wrapper, assignment, or other top-level structure"
    }
}

if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
    $catalog = [IO.File]::ReadAllText($catalogPath)
    foreach ($slot in $slots) {
        $include = '#include "' + ($slot.Path -replace '\\', '/') + '/stellaris.lua"'
        if (-not $catalog.Contains($include)) { Add-Issue "component catalog does not include $include" }
    }
    if ($catalog -notmatch '\bcomponentSlotPools\b' -or $catalog -notmatch '\bshipComponentGetSlotPool\s*\(') {
        Add-Issue "component catalog is missing automatic slot pool support"
    }
}

if ($issues -gt 0) {
    Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red
    exit 1
}
Write-Host "OK - all component slots use separate direct definitions and automatic pools." -ForegroundColor Green
exit 0
