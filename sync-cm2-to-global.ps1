[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$repositoryRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$cmRoot = Join-Path $repositoryRoot "Content Mod 2"
$gmRoot = Join-Path $repositoryRoot "Global Mod"

if (-not (Test-Path -LiteralPath $cmRoot -PathType Container)) {
    throw "CM2 directory not found: $cmRoot"
}
if (-not (Test-Path -LiteralPath $gmRoot -PathType Container)) {
    throw "GM directory not found: $gmRoot"
}

function Get-SafeFullPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$AllowedRoot
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd("\", "/")
    $rootPrefix = $fullRoot + [IO.Path]::DirectorySeparatorChar

    if (-not $fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing path outside GM: $fullPath"
    }
    return $fullPath
}

function Get-RelativeFilePath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$FullName
    )

    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd("\", "/")
    $prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
    $fullPath = [IO.Path]::GetFullPath($FullName)
    if (-not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "File is not below source root: $fullPath"
    }
    return $fullPath.Substring($prefix.Length)
}

function Test-FilesEqual {
    param(
        [Parameter(Mandatory = $true)][string]$First,
        [Parameter(Mandatory = $true)][string]$Second
    )

    if (-not (Test-Path -LiteralPath $First -PathType Leaf) -or
        -not (Test-Path -LiteralPath $Second -PathType Leaf)) {
        return $false
    }

    $firstFile = Get-Item -LiteralPath $First
    $secondFile = Get-Item -LiteralPath $Second
    if ($firstFile.Length -ne $secondFile.Length) {
        return $false
    }

    return (Get-FileHash -LiteralPath $First -Algorithm SHA256).Hash -eq
        (Get-FileHash -LiteralPath $Second -Algorithm SHA256).Hash
}

function Sync-Tree {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Source tree not found: $Source"
    }

    $destinationPath = Get-SafeFullPath -Path $Destination -AllowedRoot $gmRoot
    $sourceFiles = @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force)
    $sourceMap = @{}
    $added = 0
    $updated = 0
    $removed = 0
    $unchanged = 0

    foreach ($sourceFile in $sourceFiles) {
        $relativePath = Get-RelativeFilePath -Root $Source -FullName $sourceFile.FullName
        $sourceMap[$relativePath.ToLowerInvariant()] = $true
        $targetFile = Get-SafeFullPath `
            -Path (Join-Path $destinationPath $relativePath) `
            -AllowedRoot $gmRoot

        if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
            if (Test-FilesEqual -First $sourceFile.FullName -Second $targetFile) {
                $unchanged++
                continue
            }
            $updated++
        } else {
            $added++
        }

        if (-not $WhatIf) {
            $targetDirectory = Split-Path -Parent $targetFile
            if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetFile -Force
        }
    }

    if (Test-Path -LiteralPath $destinationPath -PathType Container) {
        $destinationFiles = @(Get-ChildItem -LiteralPath $destinationPath -File -Recurse -Force)
        foreach ($destinationFile in $destinationFiles) {
            $relativePath = Get-RelativeFilePath `
                -Root $destinationPath `
                -FullName $destinationFile.FullName
            if (-not $sourceMap.ContainsKey($relativePath.ToLowerInvariant())) {
                $safeFile = Get-SafeFullPath -Path $destinationFile.FullName -AllowedRoot $gmRoot
                $removed++
                if (-not $WhatIf) {
                    Remove-Item -LiteralPath $safeFile -Force
                }
            }
        }

        if (-not $WhatIf) {
            $directories = @(Get-ChildItem -LiteralPath $destinationPath -Directory -Recurse -Force |
                Sort-Object { $_.FullName.Length } -Descending)
            foreach ($directory in $directories) {
                $safeDirectory = Get-SafeFullPath `
                    -Path $directory.FullName `
                    -AllowedRoot $gmRoot
                if (@(Get-ChildItem -LiteralPath $safeDirectory -Force).Count -eq 0) {
                    Remove-Item -LiteralPath $safeDirectory -Force
                }
            }
        }
    }

    return [PSCustomObject]@{
        Tree = $Name
        Added = $added
        Updated = $updated
        Removed = $removed
        Unchanged = $unchanged
    }
}

function Set-GeneratedTextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $targetFile = Get-SafeFullPath -Path $Destination -AllowedRoot $gmRoot
    $existing = $null
    if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
        $existing = [IO.File]::ReadAllText($targetFile)
    }
    if ($existing -ceq $Content) {
        return "Unchanged"
    }

    if (-not $WhatIf) {
        $utf8WithoutBom = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($targetFile, $Content, $utf8WithoutBom)
    }
    if ($null -eq $existing) {
        return "Added"
    }
    return "Updated"
}

function Assert-TreesEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $sourceFiles = @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force)
    $destinationFiles = @(Get-ChildItem -LiteralPath $Destination -File -Recurse -Force)
    if ($sourceFiles.Count -ne $destinationFiles.Count) {
        throw "Verification failed: file count differs for $Destination"
    }

    foreach ($sourceFile in $sourceFiles) {
        $relativePath = Get-RelativeFilePath -Root $Source -FullName $sourceFile.FullName
        $targetFile = Join-Path $Destination $relativePath
        if (-not (Test-FilesEqual -First $sourceFile.FullName -Second $targetFile)) {
            throw "Verification failed: $relativePath"
        }
    }
}

$treeMappings = @(
    @{ Name = "script"; Source = "script"; Destination = "script" },
    @{ Name = "gfx"; Source = "gfx"; Destination = "gfx" },
    @{ Name = "prefabs"; Source = "prefabs"; Destination = "prefabs" },
    @{ Name = "sound"; Source = "sound"; Destination = "sound" },
    @{ Name = "vox"; Source = "vox"; Destination = "vox" }
)

$results = @()
foreach ($mapping in $treeMappings) {
    $sourceTree = Join-Path $cmRoot $mapping.Source
    $destinationTree = Join-Path $gmRoot $mapping.Destination
    $results += Sync-Tree `
        -Source $sourceTree `
        -Destination $destinationTree `
        -Name $mapping.Name
}

$configuratorSource = Join-Path $cmRoot "main.lua"
$gmMain = Join-Path $gmRoot "main.lua"
$configuratorText = [IO.File]::ReadAllText($configuratorSource)
$gmMainText = $configuratorText
$mainStatus = Set-GeneratedTextFile -Destination $gmMain -Content $gmMainText

$battlecruiserPrefab = Join-Path $cmRoot "prefabs\ships\enigma_battlecruiser.xml"
$prefabText = [IO.File]::ReadAllText($battlecruiserPrefab)
$scriptStart = $prefabText.IndexOf("<script ", [StringComparison]::Ordinal)
$scriptEndMarker = "</script>"
if ($scriptStart -lt 0) {
    throw "Battlecruiser prefab has no root script block."
}
$scriptEnd = $prefabText.IndexOf($scriptEndMarker, $scriptStart, [StringComparison]::Ordinal)
if ($scriptEnd -lt 0) {
    throw "Battlecruiser prefab script block is not closed."
}
$scriptEnd += $scriptEndMarker.Length
$spawnFragment = $prefabText.Substring($scriptStart, $scriptEnd - $scriptStart).Trim() + "`r`n"
$spawnStatus = Set-GeneratedTextFile `
    -Destination (Join-Path $gmRoot "enigma_battlecruiser.xml") `
    -Content $spawnFragment

$mode = if ($WhatIf) { "PREVIEW" } else { "SYNCED" }
Write-Host "CM2 -> GM $mode"
$results | Format-Table -AutoSize
Write-Host ("main.lua: {0}; enigma_battlecruiser.xml: {1}" -f $mainStatus, $spawnStatus)

if (-not $WhatIf) {
    foreach ($mapping in $treeMappings) {
        Assert-TreesEqual `
            -Source (Join-Path $cmRoot $mapping.Source) `
            -Destination (Join-Path $gmRoot $mapping.Destination)
    }
    $writtenMain = [IO.File]::ReadAllText($gmMain)
    if ($writtenMain -cne $gmMainText) {
        throw "Verification failed: Global Mod/main.lua"
    }
    $writtenSpawn = [IO.File]::ReadAllText((Join-Path $gmRoot "enigma_battlecruiser.xml"))
    if ($writtenSpawn -cne $spawnFragment) {
        throw "Verification failed: Global Mod/enigma_battlecruiser.xml"
    }
    Write-Host "Hash/content verification passed."
}
