[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$modRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$outputPath = [IO.Path]::GetFullPath(
    (Join-Path $modRoot "vox\gammaStrikeCraftTest.vox")
)
$allowedPrefix = $modRoot.TrimEnd("\", "/") +
    [IO.Path]::DirectorySeparatorChar
if (-not $outputPath.StartsWith(
    $allowedPrefix,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing output outside Content Mod 2: $outputPath"
}

$sizeX = 45
$sizeY = 12
$sizeZ = 51
$centerX = 22
$voxels = @{}

function Add-ModelVoxel {
    param(
        [int]$X,
        [int]$Y,
        [int]$Z,
        [byte]$Color
    )

    if ($X -lt 0 -or $X -ge $sizeX -or
        $Y -lt 0 -or $Y -ge $sizeY -or
        $Z -lt 0 -or $Z -ge $sizeZ) {
        return
    }
    # MagicaVoxel uses Z as its vertical axis. Teardown imports that axis as
    # world Y and maps VOX Y to the opposite world-Z direction. Therefore
    # logical Teardown (x, y, z) is stored as VOX (x, maxZ-z, y).
    $voxels["$X,$Y,$Z"] = [byte[]]@(
        [byte]$X,
        [byte](($sizeZ - 1) - $Z),
        [byte]$Y,
        $Color
    )
}

# Low, swept delta wing. The cyan strips deliberately echo the Stellaris icon.
for ($z = 9; $z -le 45; $z++) {
    $wingHalf = [Math]::Min(21, [Math]::Floor(($z - 6) * 0.58))
    if ($z -gt 41) {
        $wingHalf -= ($z - 41)
    }
    for ($x = -$wingHalf; $x -le $wingHalf; $x++) {
        $absX = [Math]::Abs($x)
        $edge = $wingHalf - $absX
        $color = if ($edge -le 1) { 1 } else { 2 }
        if ($z -ge 18 -and $z -le 39) {
            $stripe = [Math]::Floor(($z - 8) * 0.37)
            if ([Math]::Abs($absX - $stripe) -le 1) {
                $color = 4
            }
        }
        Add-ModelVoxel ($centerX + $x) 3 $z ([byte]$color)
        Add-ModelVoxel ($centerX + $x) 4 $z ([byte]$color)
    }
}

# Armored central wedge and sharp nose.
for ($z = 0; $z -le 47; $z++) {
    if ($z -lt 12) {
        $half = [Math]::Min(4, 1 + [Math]::Floor($z / 3))
    } elseif ($z -gt 39) {
        $half = [Math]::Max(2, 5 - [Math]::Floor(($z - 39) / 3))
    } else {
        $half = 5
    }
    $height = if ($z -lt 8) { 5 } elseif ($z -lt 34) { 7 } else { 6 }
    for ($x = -$half; $x -le $half; $x++) {
        for ($y = 2; $y -le $height; $y++) {
            $color = if ($y -eq $height -or [Math]::Abs($x) -eq $half) {
                3
            } else {
                2
            }
            Add-ModelVoxel ($centerX + $x) $y $z ([byte]$color)
        }
    }
}

# Raised cyan cockpit.
for ($z = 10; $z -le 24; $z++) {
    $cockpitHalf = if ($z -lt 14 -or $z -gt 21) { 1 } else { 2 }
    $cockpitHeight = if ($z -ge 14 -and $z -le 20) { 9 } else { 8 }
    for ($x = -$cockpitHalf; $x -le $cockpitHalf; $x++) {
        for ($y = 7; $y -le $cockpitHeight; $y++) {
            $color = if ($y -eq $cockpitHeight) { 5 } else { 6 }
            Add-ModelVoxel ($centerX + $x) $y $z ([byte]$color)
        }
    }
}

# Twin engine blocks and bright exhaust faces.
foreach ($engineX in @(-7, 7)) {
    for ($z = 39; $z -le 50; $z++) {
        for ($x = $engineX - 2; $x -le $engineX + 2; $x++) {
            for ($y = 2; $y -le 6; $y++) {
                $color = if ($z -eq 50) { 5 } elseif ($y -eq 2) { 8 } else { 7 }
                Add-ModelVoxel ($centerX + $x) $y $z ([byte]$color)
            }
        }
    }
}

# Compact dorsal tail with a cyan power spine.
for ($z = 34; $z -le 48; $z++) {
    $tailHeight = 7 + [Math]::Floor(($z - 34) / 4)
    for ($y = 7; $y -le [Math]::Min(11, $tailHeight); $y++) {
        Add-ModelVoxel $centerX $y $z ([byte]4)
        if ($y -lt $tailHeight) {
            Add-ModelVoxel ($centerX - 1) $y $z ([byte]2)
            Add-ModelVoxel ($centerX + 1) $y $z ([byte]2)
        }
    }
}

$orderedVoxels = @(
    $voxels.GetEnumerator() |
        Sort-Object {
            $parts = $_.Key.Split(",")
            ([int]$parts[2] * 10000) +
                ([int]$parts[1] * 100) +
                [int]$parts[0]
        } |
        ForEach-Object { ,([byte[]]$_.Value) }
)

$palette = @(
    @(7, 14, 20, 255),
    @(12, 30, 38, 255),
    @(18, 62, 70, 255),
    @(20, 225, 225, 255),
    @(130, 255, 255, 255),
    @(20, 100, 120, 255),
    @(70, 90, 95, 255),
    @(3, 6, 8, 255)
)

$sizeContentBytes = 12
$xyziContentBytes = 4 + $orderedVoxels.Count * 4
$rgbaContentBytes = 1024
$childrenBytes =
    (12 + $sizeContentBytes) +
    (12 + $xyziContentBytes) +
    (12 + $rgbaContentBytes)

$stream = [IO.File]::Open(
    $outputPath,
    [IO.FileMode]::Create,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None
)
try {
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([Text.Encoding]::ASCII.GetBytes("VOX "))
        $writer.Write([int]150)

        $writer.Write([Text.Encoding]::ASCII.GetBytes("MAIN"))
        $writer.Write([int]0)
        $writer.Write([int]$childrenBytes)

        $writer.Write([Text.Encoding]::ASCII.GetBytes("SIZE"))
        $writer.Write([int]$sizeContentBytes)
        $writer.Write([int]0)
        $writer.Write([int]$sizeX)
        $writer.Write([int]$sizeZ)
        $writer.Write([int]$sizeY)

        $writer.Write([Text.Encoding]::ASCII.GetBytes("XYZI"))
        $writer.Write([int]$xyziContentBytes)
        $writer.Write([int]0)
        $writer.Write([int]$orderedVoxels.Count)
        foreach ($voxel in $orderedVoxels) {
            $writer.Write([byte[]]$voxel)
        }

        $writer.Write([Text.Encoding]::ASCII.GetBytes("RGBA"))
        $writer.Write([int]$rgbaContentBytes)
        $writer.Write([int]0)
        for ($index = 0; $index -lt 256; $index++) {
            if ($index -lt $palette.Count) {
                $writer.Write([byte[]]$palette[$index])
            } else {
                $writer.Write([byte[]]@(0, 0, 0, 0))
            }
        }
    } finally {
        $writer.Dispose()
    }
} finally {
    $stream.Dispose()
}

Write-Host (
    "Generated {0}: {1} voxels, {2}x{3}x{4}" -f
    $outputPath,
    $orderedVoxels.Count,
    $sizeX,
    $sizeY,
    $sizeZ
)
