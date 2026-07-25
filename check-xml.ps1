# Teardown XML structure and reference checker.

param(
    [string]$Path = ".\Content Mod 2",
    [string]$Scene = "main.xml",
    [string]$BattlecruiserPrefab = "prefabs\ships\enigma_battlecruiser.xml"
)

$ErrorActionPreference = "Stop"
$issueCount = 0

function Add-Issue {
    param([string]$Message)
    Write-Host "[XML SEMANTIC ERROR] $Message" -ForegroundColor Red
    $script:issueCount++
}

function Get-XmlDocument {
    param([string]$FullPath)
    try {
        return [xml][System.IO.File]::ReadAllText($FullPath)
    }
    catch {
        Add-Issue "$FullPath is not well-formed XML: $($_.Exception.Message)"
        return $null
    }
}

function Test-TagToken {
    param([string]$Value, [string]$Token)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    return @(($Value -split "\s+") | Where-Object { $_ -eq $Token }).Count -gt 0
}

function Resolve-ModReference {
    param([string]$Reference, [string]$Source)
    if (-not $Reference.StartsWith("MOD/", [StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    $relative = $Reference.Substring(4).Replace("/", [IO.Path]::DirectorySeparatorChar)
    $candidate = [IO.Path]::GetFullPath((Join-Path $script:modRoot $relative))
    if (-not $candidate.StartsWith($script:rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        Add-Issue "$Source reference escapes mod root: $Reference"
        return $null
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        Add-Issue "$Source references missing file: $Reference"
        return $null
    }
    return $candidate
}

function Get-LuaIncludeClosure {
    param([string]$EntryPath)
    $seen = New-Object "System.Collections.Generic.HashSet[string]" ([StringComparer]::OrdinalIgnoreCase)
    $stack = New-Object "System.Collections.Generic.Stack[string]"
    $stack.Push($EntryPath)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        if (-not $seen.Add($current)) {
            continue
        }

        $directory = Split-Path -Parent $current
        foreach ($line in [System.IO.File]::ReadAllLines($current)) {
            if ($line -notmatch '^\s*#include\s+"([^"]+)"') {
                continue
            }
            $include = $matches[1]
            if ($include.StartsWith("script/", [StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
            $candidate = [IO.Path]::GetFullPath((Join-Path $directory $include))
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $stack.Push($candidate)
            }
        }
    }
    return @($seen)
}

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

$modRoot = (Resolve-Path -LiteralPath $Path).Path
$rootPrefix = $modRoot + [IO.Path]::DirectorySeparatorChar
$scenePath = [IO.Path]::GetFullPath((Join-Path $modRoot $Scene))
$prefabPath = [IO.Path]::GetFullPath((Join-Path $modRoot $BattlecruiserPrefab))

Write-Host "=== Teardown XML Semantic Checker ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $scenePath -PathType Leaf)) {
    Add-Issue "Scene is missing: $Scene"
}
if (-not (Test-Path -LiteralPath $prefabPath -PathType Leaf)) {
    Add-Issue "Battlecruiser prefab is missing: $BattlecruiserPrefab"
}

$documents = @{}
foreach ($candidate in @($scenePath, $prefabPath)) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $documents[$candidate] = Get-XmlDocument $candidate
    }
}

foreach ($entry in @($documents.GetEnumerator())) {
    $document = $entry.Value
    if ($null -eq $document) {
        continue
    }
    foreach ($node in @($document.SelectNodes("//*[@file]"))) {
        [void](Resolve-ModReference ([string]$node.file) $entry.Key)
    }
}

$sceneDocument = $documents[$scenePath]
if ($null -ne $sceneDocument) {
    foreach ($instance in @($sceneDocument.SelectNodes("//instance[@file]"))) {
        $target = Resolve-ModReference ([string]$instance.file) $scenePath
        if ($null -eq $target -or [IO.Path]::GetExtension($target) -ne ".xml") {
            continue
        }
        $targetDocument = Get-XmlDocument $target
        if ($null -ne $targetDocument -and $targetDocument.DocumentElement.Name -ne "prefab") {
            Add-Issue "instance target must have root <prefab>: $($instance.file) has <$($targetDocument.DocumentElement.Name)>"
        }
    }
}

$prefabDocument = $documents[$prefabPath]
if ($null -ne $prefabDocument) {
    if ($prefabDocument.DocumentElement.Name -ne "prefab") {
        Add-Issue "battlecruiser prefab must have root <prefab>, found <$($prefabDocument.DocumentElement.Name)>"
    }

    $vehicle = $prefabDocument.SelectSingleNode("/prefab/group//script/vehicle")
    if ($null -eq $vehicle) {
        Add-Issue "battlecruiser prefab must contain prefab/group/script/vehicle"
    }
    else {
        if (-not (Test-TagToken ([string]$vehicle.tags) "stellarisShip")) {
            Add-Issue "battlecruiser vehicle is missing tag stellarisShip"
        }
        $body = $vehicle.SelectSingleNode(".//body")
        if ($null -eq $body -or -not (Test-TagToken ([string]$body.tags) "stellarisShip")) {
            Add-Issue "battlecruiser body is missing tag stellarisShip"
        }
        $locations = @($vehicle.SelectNodes(".//location"))
        $hasPlayer = @($locations | Where-Object {
            ([string]$_.name).Equals("player", [StringComparison]::OrdinalIgnoreCase) -or
            (Test-TagToken ([string]$_.tags) "player")
        }).Count -gt 0
        $hasExit = @($locations | Where-Object {
            ([string]$_.name).Equals("exit", [StringComparison]::OrdinalIgnoreCase) -or
            (Test-TagToken ([string]$_.tags) "exit")
        }).Count -gt 0
        if (-not $hasPlayer) { Add-Issue "battlecruiser vehicle is missing player location" }
        if (-not $hasExit) { Add-Issue "battlecruiser vehicle is missing exit location" }
    }

    $light = @($prefabDocument.SelectNodes("//light") | Where-Object {
        Test-TagToken ([string]$_.tags) "tachyonMuzzleLight"
    }) | Select-Object -First 1
    if ($null -eq $light) {
        Add-Issue "battlecruiser prefab is missing light tag tachyonMuzzleLight"
    }
    foreach ($arcLightTag in @("arcMuzzleLightLeft", "arcMuzzleLightRight")) {
        $arcLight = @($prefabDocument.SelectNodes("//light") | Where-Object {
            Test-TagToken ([string]$_.tags) $arcLightTag
        }) | Select-Object -First 1
        if ($null -eq $arcLight) {
            Add-Issue "battlecruiser prefab is missing light tag $arcLightTag"
        }
    }

    $scriptNode = $prefabDocument.SelectSingleNode("/prefab/group//script[@file]")
    if ($null -ne $scriptNode) {
        $entryScript = Resolve-ModReference ([string]$scriptNode.file) $prefabPath
        if ($null -ne $entryScript) {
            $closure = Get-LuaIncludeClosure $entryScript
            $source = ($closure | ForEach-Object { [System.IO.File]::ReadAllText($_) }) -join "`n"
            foreach ($requiredPattern in @(
                'FindLight\s*\(',
                'SetLightIntensity\s*\(',
                'tachyonMuzzleLightInit\s*\(',
                'tachyonMuzzleLightTick\s*\('
            )) {
                if ($source -notmatch $requiredPattern) {
                    Add-Issue "Lua include closure lacks dynamic muzzle-light control: $requiredPattern"
                }
            }
        }
    }
}

Write-Host ""
Write-Host "Check complete: $issueCount semantic issue(s)"
if ($issueCount -gt 0) {
    exit 1
}
Write-Host "OK - Teardown XML structure, references, vehicle contract, and muzzle-light binding are valid." -ForegroundColor Green
exit 0
