[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$modRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$outputRoot = [IO.Path]::GetFullPath(
    (Join-Path $modRoot "vox\celestial")
)
$gfxRoot = [IO.Path]::GetFullPath(
    (Join-Path $modRoot "gfx\space")
)
$allowedPrefix = $modRoot.TrimEnd("\", "/") +
    [IO.Path]::DirectorySeparatorChar
if (-not $outputRoot.StartsWith(
    $allowedPrefix,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing output outside Content Mod 2: $outputRoot"
}
if (-not $gfxRoot.StartsWith(
    $allowedPrefix,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing output outside Content Mod 2: $gfxRoot"
}
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
[IO.Directory]::CreateDirectory($gfxRoot) | Out-Null

$suggestedXmlScale = 20.0
$defaultVoxelMeters = 0.1
$scaledVoxelMeters = $defaultVoxelMeters * $suggestedXmlScale

function New-PaletteColor {
    param(
        [int]$R,
        [int]$G,
        [int]$B
    )

    return [byte[]]@(
        [byte]$R,
        [byte]$G,
        [byte]$B,
        [byte]255
    )
}

$definitions = @(
    [pscustomobject]@{
        Id = "star_g_yellow"
        DisplayName = "G-type yellow star"
        Kind = "star"
        FileName = "star_g_yellow.vox"
        SizeX = 112
        SizeY = 112
        SizeZ = 112
        BodyDiameterVoxels = 112
        ShellThickness = 2.0
        Ringed = $false
        Palette = @(
            (New-PaletteColor 255 132 24),
            (New-PaletteColor 255 176 42),
            (New-PaletteColor 255 220 92),
            (New-PaletteColor 255 245 178)
        )
        EmissivePaletteIndices = @(1, 2, 3, 4)
    },
    [pscustomobject]@{
        Id = "planet_continental"
        DisplayName = "Continental world"
        Kind = "continental"
        FileName = "planet_continental.vox"
        SizeX = 48
        SizeY = 48
        SizeZ = 48
        BodyDiameterVoxels = 48
        ShellThickness = 2.0
        Ringed = $false
        Palette = @(
            (New-PaletteColor 13 47 76),
            (New-PaletteColor 20 82 116),
            (New-PaletteColor 35 117 135),
            (New-PaletteColor 38 105 66),
            (New-PaletteColor 79 135 68),
            (New-PaletteColor 132 145 93),
            (New-PaletteColor 212 227 222)
        )
        EmissivePaletteIndices = @()
    },
    [pscustomobject]@{
        Id = "planet_desert"
        DisplayName = "Desert world"
        Kind = "desert"
        FileName = "planet_desert.vox"
        SizeX = 52
        SizeY = 52
        SizeZ = 52
        BodyDiameterVoxels = 52
        ShellThickness = 2.0
        Ringed = $false
        Palette = @(
            (New-PaletteColor 84 47 38),
            (New-PaletteColor 132 72 46),
            (New-PaletteColor 177 105 57),
            (New-PaletteColor 210 147 79),
            (New-PaletteColor 229 187 119),
            (New-PaletteColor 245 216 162)
        )
        EmissivePaletteIndices = @()
    },
    [pscustomobject]@{
        Id = "planet_gas_giant_ringed"
        DisplayName = "Ringed gas giant"
        Kind = "gas_giant_ringed"
        FileName = "planet_gas_giant_ringed.vox"
        SizeX = 96
        SizeY = 60
        SizeZ = 96
        BodyDiameterVoxels = 60
        ShellThickness = 2.0
        Ringed = $true
        RingInnerRadius = 28.0
        RingOuterRadius = 45.5
        RingHalfThickness = 1.0
        Palette = @(
            (New-PaletteColor 91 67 85),
            (New-PaletteColor 142 91 88),
            (New-PaletteColor 190 127 92),
            (New-PaletteColor 224 173 111),
            (New-PaletteColor 238 205 151),
            (New-PaletteColor 184 151 130),
            (New-PaletteColor 112 91 104),
            (New-PaletteColor 226 197 155)
        )
        EmissivePaletteIndices = @()
    },
    [pscustomobject]@{
        Id = "planet_frozen"
        DisplayName = "Frozen world"
        Kind = "frozen"
        FileName = "planet_frozen.vox"
        SizeX = 56
        SizeY = 56
        SizeZ = 56
        BodyDiameterVoxels = 56
        ShellThickness = 2.0
        Ringed = $false
        Palette = @(
            (New-PaletteColor 37 68 101),
            (New-PaletteColor 55 105 142),
            (New-PaletteColor 92 151 178),
            (New-PaletteColor 143 192 207),
            (New-PaletteColor 194 224 226),
            (New-PaletteColor 232 242 236)
        )
        EmissivePaletteIndices = @()
    },
    [pscustomobject]@{
        Id = "planet_volcanic"
        DisplayName = "Volcanic world"
        Kind = "volcanic"
        FileName = "planet_volcanic.vox"
        SizeX = 60
        SizeY = 60
        SizeZ = 60
        BodyDiameterVoxels = 60
        ShellThickness = 2.0
        Ringed = $false
        Palette = @(
            (New-PaletteColor 29 25 30),
            (New-PaletteColor 53 42 43),
            (New-PaletteColor 82 55 48),
            (New-PaletteColor 115 66 47),
            (New-PaletteColor 156 55 31),
            (New-PaletteColor 211 82 32),
            (New-PaletteColor 242 142 51)
        )
        EmissivePaletteIndices = @()
    },
    [pscustomobject]@{
        Id = "planet_ocean"
        DisplayName = "Ocean world"
        Kind = "ocean"
        FileName = "planet_ocean.vox"
        SizeX = 64
        SizeY = 64
        SizeZ = 64
        BodyDiameterVoxels = 64
        ShellThickness = 2.0
        Ringed = $false
        Palette = @(
            (New-PaletteColor 8 38 77),
            (New-PaletteColor 9 67 112),
            (New-PaletteColor 13 99 142),
            (New-PaletteColor 25 134 159),
            (New-PaletteColor 59 166 176),
            (New-PaletteColor 121 197 193),
            (New-PaletteColor 216 235 226)
        )
        EmissivePaletteIndices = @()
    }
)

function Get-LinearIndex {
    param(
        [int]$X,
        [int]$Y,
        [int]$Z,
        [int]$SizeX,
        [int]$SizeY
    )

    return (($Z * $SizeY + $Y) * $SizeX + $X)
}

function Set-ModelVoxel {
    param(
        [byte[]]$Colors,
        [Collections.Generic.List[int]]$Filled,
        [int]$SizeX,
        [int]$SizeY,
        [int]$SizeZ,
        [int]$X,
        [int]$Y,
        [int]$Z,
        [byte]$Color
    )

    if ($X -lt 0 -or $X -ge $SizeX -or
        $Y -lt 0 -or $Y -ge $SizeY -or
        $Z -lt 0 -or $Z -ge $SizeZ) {
        return
    }

    $index = Get-LinearIndex $X $Y $Z $SizeX $SizeY
    if ($Colors[$index] -eq 0) {
        $Filled.Add($index)
    }
    $Colors[$index] = $Color
}

function Get-SurfaceColor {
    param(
        [string]$Kind,
        [double]$Nx,
        [double]$Ny,
        [double]$Nz
    )

    $absLatitude = [Math]::Abs($Ny)

    if ($Kind -eq "star") {
        $field = [Math]::Sin($Nx * 3.2 + $Nz * 1.1) +
            [Math]::Cos($Ny * 3.6 - $Nx * 0.8) +
            [Math]::Sin(($Nx + $Ny + $Nz) * 2.0)
        if ($field -gt 1.35) { return [byte]4 }
        if ($field -gt 0.30) { return [byte]3 }
        if ($field -gt -0.85) { return [byte]2 }
        return [byte]1
    }

    if ($Kind -eq "continental") {
        if ($absLatitude -gt 0.82) { return [byte]7 }
        $landField = [Math]::Sin($Nx * 3.4 + $Nz * 1.2) +
            [Math]::Cos($Nz * 2.9 - $Ny * 1.1) +
            [Math]::Sin(($Nx - $Nz) * 1.8 + $Ny * 1.4)
        if ($landField -gt 0.55) {
            if ($landField -gt 1.55) { return [byte]6 }
            if ($absLatitude -gt 0.58) { return [byte]5 }
            if ($Ny -gt 0.05) { return [byte]4 }
            return [byte]5
        }
        if ($landField -gt 0.20) { return [byte]3 }
        if ($absLatitude -gt 0.62) { return [byte]2 }
        return [byte]1
    }

    if ($Kind -eq "desert") {
        $dune = [Math]::Sin($Ny * 10.0 + $Nx * 1.4) +
            0.45 * [Math]::Cos($Nz * 3.0 - $Nx * 1.2)
        $basin = [Math]::Sin(($Nx + $Nz) * 2.2 - $Ny * 1.3)
        if ($absLatitude -gt 0.84) { return [byte]6 }
        if ($basin -lt -0.75) { return [byte]1 }
        if ($dune -gt 1.05) { return [byte]5 }
        if ($dune -gt 0.30) { return [byte]4 }
        if ($dune -gt -0.45) { return [byte]3 }
        return [byte]2
    }

    if ($Kind -eq "gas_giant_ringed") {
        $band = [Math]::Sin($Ny * 18.0 +
            [Math]::Sin($Nx * 1.4 + $Nz * 0.9) * 0.8)
        $storm = (($Nx - 0.52) * ($Nx - 0.52)) / 0.12 +
            (($Ny + 0.18) * ($Ny + 0.18)) / 0.025 +
            (($Nz - 0.34) * ($Nz - 0.34)) / 0.18
        if ($storm -lt 1.0) { return [byte]1 }
        if ($band -gt 0.72) { return [byte]5 }
        if ($band -gt 0.18) { return [byte]4 }
        if ($band -gt -0.42) { return [byte]3 }
        if ($band -gt -0.82) { return [byte]2 }
        return [byte]6
    }

    if ($Kind -eq "frozen") {
        $ridge = [Math]::Abs(
            [Math]::Sin($Nx * 3.8 + $Nz * 2.5 + $Ny * 1.1)
        )
        $shelf = [Math]::Cos($Ny * 7.5 + $Nx * 1.2)
        if ($ridge -lt 0.10) { return [byte]1 }
        if ($absLatitude -gt 0.80) { return [byte]6 }
        if ($shelf -gt 0.60) { return [byte]5 }
        if ($shelf -gt 0.05) { return [byte]4 }
        if ($shelf -gt -0.60) { return [byte]3 }
        return [byte]2
    }

    if ($Kind -eq "volcanic") {
        $crust = [Math]::Sin($Nx * 3.7 + $Nz * 2.3) +
            [Math]::Cos($Ny * 3.1 - $Nx * 1.5)
        $fissure = [Math]::Abs(
            [Math]::Sin($Nx * 4.4 + $Nz * 3.2 + $Ny * 1.3) +
            0.45 * [Math]::Cos(($Nx - $Nz) * 3.0)
        )
        if ($fissure -lt 0.12) { return [byte]7 }
        if ($fissure -lt 0.24) { return [byte]6 }
        if ($crust -gt 1.15) { return [byte]5 }
        if ($crust -gt 0.35) { return [byte]4 }
        if ($crust -gt -0.55) { return [byte]3 }
        if ($crust -gt -1.20) { return [byte]2 }
        return [byte]1
    }

    if ($Kind -eq "ocean") {
        $current = [Math]::Sin($Ny * 6.5 + $Nx * 1.4) +
            0.55 * [Math]::Cos($Nz * 3.1 - $Nx * 1.0)
        $shallows = [Math]::Sin($Nx * 2.6 + $Nz * 2.0) +
            [Math]::Cos($Ny * 2.1 - $Nz * 1.4)
        if ($absLatitude -gt 0.86) { return [byte]7 }
        if ($shallows -gt 1.20) { return [byte]6 }
        if ($current -gt 1.05) { return [byte]5 }
        if ($current -gt 0.35) { return [byte]4 }
        if ($current -gt -0.40) { return [byte]3 }
        if ($current -gt -1.05) { return [byte]2 }
        return [byte]1
    }

    throw "Unsupported celestial kind: $Kind"
}

function New-CelestialModel {
    param([pscustomobject]$Definition)

    $sizeX = [int]$Definition.SizeX
    $sizeY = [int]$Definition.SizeY
    $sizeZ = [int]$Definition.SizeZ
    if ($sizeX -gt 256 -or $sizeY -gt 256 -or $sizeZ -gt 256) {
        throw "VOX dimensions exceed 256 for $($Definition.Id)"
    }

    $colors = New-Object byte[] ($sizeX * $sizeY * $sizeZ)
    $filled = New-Object 'Collections.Generic.List[int]'
    $centerX = ($sizeX - 1) * 0.5
    $centerY = ($sizeY - 1) * 0.5
    $centerZ = ($sizeZ - 1) * 0.5
    $radius = ($Definition.BodyDiameterVoxels - 1) * 0.5
    $innerRadius = $radius - [double]$Definition.ShellThickness
    $outerRadiusSquared = $radius * $radius
    $innerRadiusSquared = $innerRadius * $innerRadius

    $minX = [Math]::Max(0, [Math]::Ceiling($centerX - $radius))
    $maxX = [Math]::Min($sizeX - 1, [Math]::Floor($centerX + $radius))
    $minY = [Math]::Max(0, [Math]::Ceiling($centerY - $radius))
    $maxY = [Math]::Min($sizeY - 1, [Math]::Floor($centerY + $radius))

    for ($x = $minX; $x -le $maxX; $x++) {
        $dx = $x - $centerX
        $dxSquared = $dx * $dx
        for ($y = $minY; $y -le $maxY; $y++) {
            $dy = $y - $centerY
            $radialSquared = $dxSquared + $dy * $dy
            if ($radialSquared -gt $outerRadiusSquared) {
                continue
            }

            $outerZ = [Math]::Sqrt(
                [Math]::Max(0.0, $outerRadiusSquared - $radialSquared)
            )
            $zStart = [Math]::Max(
                0,
                [Math]::Ceiling($centerZ - $outerZ)
            )
            $zEnd = [Math]::Min(
                $sizeZ - 1,
                [Math]::Floor($centerZ + $outerZ)
            )

            if ($radialSquared -ge $innerRadiusSquared) {
                $segments = @(,@($zStart, $zEnd))
            } else {
                $innerZ = [Math]::Sqrt(
                    [Math]::Max(0.0, $innerRadiusSquared - $radialSquared)
                )
                $lowerEnd = [Math]::Floor($centerZ - $innerZ)
                $upperStart = [Math]::Ceiling($centerZ + $innerZ)
                $segments = @()
                if ($zStart -le $lowerEnd) {
                    $segments += ,@($zStart, $lowerEnd)
                }
                if ($upperStart -le $zEnd) {
                    $segments += ,@($upperStart, $zEnd)
                }
            }

            foreach ($segment in $segments) {
                for ($z = $segment[0]; $z -le $segment[1]; $z++) {
                    $dz = $z - $centerZ
                    $color = Get-SurfaceColor `
                        $Definition.Kind `
                        ($dx / $radius) `
                        ($dy / $radius) `
                        ($dz / $radius)
                    Set-ModelVoxel `
                        $colors `
                        $filled `
                        $sizeX `
                        $sizeY `
                        $sizeZ `
                        $x `
                        $y `
                        $z `
                        $color
                }
            }
        }
    }

    if ($Definition.Ringed) {
        $ringInner = [double]$Definition.RingInnerRadius
        $ringOuter = [double]$Definition.RingOuterRadius
        $ringHalfThickness = [double]$Definition.RingHalfThickness
        $ringInnerSquared = $ringInner * $ringInner
        $ringOuterSquared = $ringOuter * $ringOuter
        $ringMinX = [Math]::Max(
            0,
            [Math]::Ceiling($centerX - $ringOuter)
        )
        $ringMaxX = [Math]::Min(
            $sizeX - 1,
            [Math]::Floor($centerX + $ringOuter)
        )
        $ringMinZ = [Math]::Max(
            0,
            [Math]::Ceiling($centerZ - $ringOuter)
        )
        $ringMaxZ = [Math]::Min(
            $sizeZ - 1,
            [Math]::Floor($centerZ + $ringOuter)
        )
        $ringMinY = [Math]::Max(
            0,
            [Math]::Ceiling($centerY - $ringHalfThickness)
        )
        $ringMaxY = [Math]::Min(
            $sizeY - 1,
            [Math]::Floor($centerY + $ringHalfThickness)
        )

        for ($x = $ringMinX; $x -le $ringMaxX; $x++) {
            $dx = $x - $centerX
            for ($z = $ringMinZ; $z -le $ringMaxZ; $z++) {
                $dz = $z - $centerZ
                $ringRadiusSquared = $dx * $dx + $dz * $dz
                if ($ringRadiusSquared -lt $ringInnerSquared -or
                    $ringRadiusSquared -gt $ringOuterSquared) {
                    continue
                }

                $ringRadius = [Math]::Sqrt($ringRadiusSquared)
                $ringPhase = ($ringRadius - $ringInner) /
                    ($ringOuter - $ringInner)
                if ($ringPhase -lt 0.24) {
                    $ringColor = [byte]7
                } elseif ($ringPhase -lt 0.52) {
                    $ringColor = [byte]8
                } elseif ($ringPhase -lt 0.78) {
                    $ringColor = [byte]6
                } else {
                    $ringColor = [byte]7
                }

                for ($y = $ringMinY; $y -le $ringMaxY; $y++) {
                    Set-ModelVoxel `
                        $colors `
                        $filled `
                        $sizeX `
                        $sizeY `
                        $sizeZ `
                        $x `
                        $y `
                        $z `
                        $ringColor
                }
            }
        }
    }

    return [pscustomobject]@{
        SizeX = $sizeX
        SizeY = $sizeY
        SizeZ = $sizeZ
        CenterX = $centerX
        CenterY = $centerY
        CenterZ = $centerZ
        Radius = $radius
        Colors = $colors
        Filled = $filled
    }
}

function Write-StringValue {
    param(
        [IO.BinaryWriter]$Writer,
        [string]$Value
    )

    $bytes = [Text.Encoding]::ASCII.GetBytes($Value)
    $Writer.Write([int]$bytes.Length)
    $Writer.Write($bytes)
}

function New-MaterialContent {
    param([int]$MaterialId)

    $stream = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([int]$MaterialId)
        $entries = @(
            @("_type", "_emit"),
            @("_rough", "0.35"),
            @("_emit", "1"),
            @("_flux", "2")
        )
        $writer.Write([int]$entries.Count)
        foreach ($entry in $entries) {
            Write-StringValue $writer $entry[0]
            Write-StringValue $writer $entry[1]
        }
        $writer.Flush()
        return $stream.ToArray()
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function Write-ChunkHeader {
    param(
        [IO.BinaryWriter]$Writer,
        [string]$Id,
        [int]$ContentBytes,
        [int]$ChildrenBytes = 0
    )

    $Writer.Write([Text.Encoding]::ASCII.GetBytes($Id))
    $Writer.Write([int]$ContentBytes)
    $Writer.Write([int]$ChildrenBytes)
}

function New-TransformNodeContent {
    param(
        [int]$NodeId,
        [int]$ChildNodeId
    )

    $stream = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([int]$NodeId)
        $writer.Write([int]0)
        $writer.Write([int]$ChildNodeId)
        $writer.Write([int]-1)
        $writer.Write([int]0)
        $writer.Write([int]1)
        $writer.Write([int]0)
        $writer.Flush()
        return $stream.ToArray()
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function New-GroupNodeContent {
    param(
        [int]$NodeId,
        [int]$ChildNodeId
    )

    $stream = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([int]$NodeId)
        $writer.Write([int]0)
        $writer.Write([int]1)
        $writer.Write([int]$ChildNodeId)
        $writer.Flush()
        return $stream.ToArray()
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function New-ShapeNodeContent {
    param(
        [int]$NodeId,
        [int]$ModelId
    )

    $stream = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([int]$NodeId)
        $writer.Write([int]0)
        $writer.Write([int]1)
        $writer.Write([int]$ModelId)
        $writer.Write([int]0)
        $writer.Flush()
        return $stream.ToArray()
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function New-LayerContent {
    param([int]$LayerId)

    $stream = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([int]$LayerId)
        $writer.Write([int]0)
        $writer.Write([int]-1)
        $writer.Flush()
        return $stream.ToArray()
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

function Write-CelestialVox {
    param(
        [string]$Path,
        [pscustomobject]$Definition,
        [pscustomobject]$Model
    )

    $materialContents = @()
    foreach ($materialId in $Definition.EmissivePaletteIndices) {
        $materialContents += ,(New-MaterialContent ([int]$materialId))
    }

    $sceneContents = @(
        [pscustomobject]@{
            Id = "nTRN"
            Content = New-TransformNodeContent 0 1
        },
        [pscustomobject]@{
            Id = "nGRP"
            Content = New-GroupNodeContent 1 2
        },
        [pscustomobject]@{
            Id = "nTRN"
            Content = New-TransformNodeContent 2 3
        },
        [pscustomobject]@{
            Id = "nSHP"
            Content = New-ShapeNodeContent 3 0
        },
        [pscustomobject]@{
            Id = "LAYR"
            Content = New-LayerContent 0
        }
    )

    $sizeContentBytes = 12
    $xyziContentBytes = 4 + $Model.Filled.Count * 4
    $rgbaContentBytes = 1024
    $childrenBytes =
        (12 + $sizeContentBytes) +
        (12 + $xyziContentBytes) +
        (12 + $rgbaContentBytes)
    foreach ($sceneContent in $sceneContents) {
        $childrenBytes += 12 + $sceneContent.Content.Length
    }
    foreach ($materialContent in $materialContents) {
        $childrenBytes += 12 + $materialContent.Length
    }

    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::Create,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $writer = New-Object IO.BinaryWriter($stream)
        try {
            $writer.Write([Text.Encoding]::ASCII.GetBytes("VOX "))
            $writer.Write([int]200)

            Write-ChunkHeader $writer "MAIN" 0 $childrenBytes

            Write-ChunkHeader $writer "SIZE" $sizeContentBytes
            $writer.Write([int]$Model.SizeX)
            $writer.Write([int]$Model.SizeZ)
            $writer.Write([int]$Model.SizeY)

            Write-ChunkHeader $writer "XYZI" $xyziContentBytes
            $writer.Write([int]$Model.Filled.Count)
            foreach ($index in $Model.Filled) {
                $x = $index % $Model.SizeX
                $row = [Math]::Floor($index / $Model.SizeX)
                $y = $row % $Model.SizeY
                $z = [Math]::Floor($row / $Model.SizeY)
                $writer.Write([byte]$x)
                $writer.Write([byte](($Model.SizeZ - 1) - $z))
                $writer.Write([byte]$y)
                $writer.Write([byte]$Model.Colors[$index])
            }

            foreach ($sceneContent in $sceneContents) {
                Write-ChunkHeader `
                    $writer `
                    $sceneContent.Id `
                    $sceneContent.Content.Length
                $writer.Write([byte[]]$sceneContent.Content)
            }

            Write-ChunkHeader $writer "RGBA" $rgbaContentBytes
            for ($index = 0; $index -lt 256; $index++) {
                if ($index -lt $Definition.Palette.Count) {
                    $writer.Write([byte[]]$Definition.Palette[$index])
                } else {
                    $writer.Write([byte[]]@(0, 0, 0, 0))
                }
            }

            $materialIndex = 0
            foreach ($materialContent in $materialContents) {
                Write-ChunkHeader `
                    $writer `
                    "MATL" `
                    $materialContent.Length
                $writer.Write([byte[]]$materialContent)
                $materialIndex++
            }
        } finally {
            $writer.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Read-CelestialVox {
    param([string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    try {
        $reader = New-Object IO.BinaryReader($stream)
        try {
            $magic = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
            if ($magic -ne "VOX ") {
                throw "Invalid VOX header in $Path"
            }
            $version = $reader.ReadInt32()
            $mainId = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
            $mainContentBytes = $reader.ReadInt32()
            $mainChildrenBytes = $reader.ReadInt32()
            if ($mainId -ne "MAIN" -or $mainContentBytes -ne 0) {
                throw "Invalid MAIN chunk in $Path"
            }
            $mainEnd = $stream.Position + $mainChildrenBytes

            $sizeMagicaX = 0
            $sizeMagicaY = 0
            $sizeMagicaZ = 0
            $xyziEntries = $null
            $rgbaCount = 0
            $materialIds = New-Object 'Collections.Generic.List[int]'
            $chunkIds = New-Object 'Collections.Generic.List[string]'

            while ($stream.Position -lt $mainEnd) {
                $chunkId = [Text.Encoding]::ASCII.GetString(
                    $reader.ReadBytes(4)
                )
                $contentBytes = $reader.ReadInt32()
                $childrenBytes = $reader.ReadInt32()
                $contentStart = $stream.Position
                $chunkIds.Add($chunkId)

                if ($chunkId -eq "SIZE") {
                    $sizeMagicaX = $reader.ReadInt32()
                    $sizeMagicaY = $reader.ReadInt32()
                    $sizeMagicaZ = $reader.ReadInt32()
                } elseif ($chunkId -eq "XYZI") {
                    $count = $reader.ReadInt32()
                    $xyziEntries = New-Object byte[] ($count * 4)
                    $readCount = $reader.Read(
                        $xyziEntries,
                        0,
                        $xyziEntries.Length
                    )
                    if ($readCount -ne $xyziEntries.Length) {
                        throw "Truncated XYZI chunk in $Path"
                    }
                } elseif ($chunkId -eq "RGBA") {
                    $paletteBytes = $reader.ReadBytes($contentBytes)
                    if ($paletteBytes.Length -ne 1024) {
                        throw "Invalid RGBA chunk in $Path"
                    }
                    $rgbaCount++
                } elseif ($chunkId -eq "MATL") {
                    $materialIds.Add($reader.ReadInt32())
                }

                $stream.Position = $contentStart +
                    $contentBytes +
                    $childrenBytes
            }

            if ($sizeMagicaX -le 0 -or
                $sizeMagicaY -le 0 -or
                $sizeMagicaZ -le 0 -or
                $null -eq $xyziEntries -or
                $rgbaCount -ne 1) {
                throw "Missing required VOX chunks in $Path"
            }

            $sizeX = $sizeMagicaX
            $sizeY = $sizeMagicaZ
            $sizeZ = $sizeMagicaY
            $colors = New-Object byte[] ($sizeX * $sizeY * $sizeZ)
            $filled = New-Object 'Collections.Generic.List[int]'

            for ($offset = 0; $offset -lt $xyziEntries.Length; $offset += 4) {
                $x = [int]$xyziEntries[$offset]
                $z = ($sizeZ - 1) - [int]$xyziEntries[$offset + 1]
                $y = [int]$xyziEntries[$offset + 2]
                $color = [byte]$xyziEntries[$offset + 3]
                $index = Get-LinearIndex $x $y $z $sizeX $sizeY
                if ($colors[$index] -ne 0) {
                    throw "Duplicate voxel in $Path at $x,$y,$z"
                }
                $colors[$index] = $color
                $filled.Add($index)
            }

            return [pscustomobject]@{
                Version = $version
                SizeX = $sizeX
                SizeY = $sizeY
                SizeZ = $sizeZ
                Colors = $colors
                Filled = $filled
                ChunkIds = $chunkIds.ToArray()
                MaterialIds = $materialIds.ToArray()
                RgbaChunkCount = $rgbaCount
            }
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-ConnectivityStats {
    param([pscustomobject]$Model)

    $visited = New-Object byte[] $Model.Colors.Length
    $queue = New-Object int[] $Model.Filled.Count
    $componentCount = 0
    $largestComponent = 0
    $strideY = $Model.SizeX
    $strideZ = $Model.SizeX * $Model.SizeY

    foreach ($seed in $Model.Filled) {
        if ($visited[$seed] -ne 0) {
            continue
        }

        $componentCount++
        $head = 0
        $tail = 0
        $queue[$tail] = $seed
        $tail++
        $visited[$seed] = 1
        $componentSize = 0

        while ($head -lt $tail) {
            $index = $queue[$head]
            $head++
            $componentSize++

            $x = $index % $Model.SizeX
            $row = [Math]::Floor($index / $Model.SizeX)
            $y = $row % $Model.SizeY
            $z = [Math]::Floor($row / $Model.SizeY)

            $neighbors = @()
            if ($x -gt 0) { $neighbors += $index - 1 }
            if ($x -lt $Model.SizeX - 1) { $neighbors += $index + 1 }
            if ($y -gt 0) { $neighbors += $index - $strideY }
            if ($y -lt $Model.SizeY - 1) {
                $neighbors += $index + $strideY
            }
            if ($z -gt 0) { $neighbors += $index - $strideZ }
            if ($z -lt $Model.SizeZ - 1) {
                $neighbors += $index + $strideZ
            }

            foreach ($neighbor in $neighbors) {
                if ($visited[$neighbor] -eq 0 -and
                    $Model.Colors[$neighbor] -ne 0) {
                    $visited[$neighbor] = 1
                    $queue[$tail] = $neighbor
                    $tail++
                }
            }
        }

        if ($componentSize -gt $largestComponent) {
            $largestComponent = $componentSize
        }
    }

    return [pscustomobject]@{
        ComponentCount = $componentCount
        LargestComponentVoxelCount = $largestComponent
    }
}

function Get-HollowStats {
    param(
        [pscustomobject]$Definition,
        [pscustomobject]$Model
    )

    $centerX = ($Model.SizeX - 1) * 0.5
    $centerY = ($Model.SizeY - 1) * 0.5
    $centerZ = ($Model.SizeZ - 1) * 0.5
    $centerIndex = Get-LinearIndex `
        ([Math]::Floor($centerX)) `
        ([Math]::Floor($centerY)) `
        ([Math]::Floor($centerZ)) `
        $Model.SizeX `
        $Model.SizeY
    $coreRadius = (($Definition.BodyDiameterVoxels - 1) * 0.5) -
        [double]$Definition.ShellThickness -
        2.0
    $coreRadiusSquared = $coreRadius * $coreRadius
    $coreVoxelCount = 0

    foreach ($index in $Model.Filled) {
        $x = $index % $Model.SizeX
        $row = [Math]::Floor($index / $Model.SizeX)
        $y = $row % $Model.SizeY
        $z = [Math]::Floor($row / $Model.SizeY)
        $dx = $x - $centerX
        $dy = $y - $centerY
        $dz = $z - $centerZ
        if ($dx * $dx + $dy * $dy + $dz * $dz -lt
            $coreRadiusSquared) {
            $coreVoxelCount++
        }
    }

    return [pscustomobject]@{
        CenterEmpty = ($Model.Colors[$centerIndex] -eq 0)
        CoreVoxelCount = $coreVoxelCount
        CoreRadiusVoxels = [Math]::Round($coreRadius, 2)
    }
}

function Get-SmoothStep {
    param([double]$Value)

    $clamped = [Math]::Max(0.0, [Math]::Min(1.0, $Value))
    return $clamped * $clamped * (3.0 - 2.0 * $clamped)
}

function Write-NebulaBackdrop {
    param([string]$Path)

    Add-Type -AssemblyName System.Drawing

    $width = 1024
    $height = 1024
    $bitmap = New-Object Drawing.Bitmap(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $rectangle = New-Object Drawing.Rectangle(0, 0, $width, $height)
    $bitmapData = $bitmap.LockBits(
        $rectangle,
        [Drawing.Imaging.ImageLockMode]::WriteOnly,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    $edgeAlphaMaximum = 0
    $maximumAlpha = 0
    try {
        $stride = [Math]::Abs($bitmapData.Stride)
        $pixels = New-Object byte[] ($stride * $height)
        $pi = [Math]::PI

        for ($pixelY = 0; $pixelY -lt $height; $pixelY++) {
            $ny = ($pixelY / ($height - 1.0)) * 2.0 - 1.0
            $edgeY = (1.0 - [Math]::Abs($ny)) / 0.26
            for ($pixelX = 0; $pixelX -lt $width; $pixelX++) {
                $nx = ($pixelX / ($width - 1.0)) * 2.0 - 1.0
                $edgeX = (1.0 - [Math]::Abs($nx)) / 0.26
                $edgeEnvelope = Get-SmoothStep (
                    [Math]::Min($edgeX, $edgeY)
                )

                $warpA = 0.22 * [Math]::Sin(
                    ($ny * 2.2 + [Math]::Sin($nx * 1.7)) * $pi
                )
                $warpB = 0.18 * [Math]::Cos(
                    ($nx * 1.5 - $ny * 1.1) * $pi
                )
                $cyanField =
                    0.58 * [Math]::Sin(
                        ($nx * 1.45 + $ny * 0.72 + $warpA) * $pi
                    ) +
                    0.29 * [Math]::Sin(
                        ($nx * 2.85 - $ny * 1.25 + $warpB) * $pi
                    ) +
                    0.13 * [Math]::Cos(
                        ($nx * 5.10 + $ny * 2.20) * $pi
                    )
                $purpleField =
                    0.56 * [Math]::Cos(
                        ($nx * 0.82 - $ny * 1.48 - $warpA) * $pi
                    ) +
                    0.31 * [Math]::Sin(
                        ($nx * 2.15 + $ny * 2.60 + $warpB) * $pi
                    ) +
                    0.13 * [Math]::Cos(
                        ($nx * 4.20 - $ny * 3.10) * $pi
                    )

                $cyanDensity = Get-SmoothStep (($cyanField + 0.36) / 1.36)
                $purpleDensity = Get-SmoothStep (
                    ($purpleField + 0.30) / 1.30
                )
                $combinedDensity = [Math]::Min(
                    1.0,
                    0.72 * $cyanDensity + 0.58 * $purpleDensity
                )
                $alpha = [int][Math]::Round(
                    72.0 * $combinedDensity * $edgeEnvelope
                )

                $cyanWeight = $cyanDensity /
                    [Math]::Max(0.0001, $cyanDensity + $purpleDensity)
                $red = [int][Math]::Round(70.0 - 42.0 * $cyanWeight)
                $green = [int][Math]::Round(31.0 + 42.0 * $cyanWeight)
                $blue = [int][Math]::Round(64.0 + 34.0 * $cyanWeight)

                if ($alpha -eq 0) {
                    $red = 0
                    $green = 0
                    $blue = 0
                }

                $offset = $pixelY * $stride + $pixelX * 4
                $pixels[$offset] = [byte]$blue
                $pixels[$offset + 1] = [byte]$green
                $pixels[$offset + 2] = [byte]$red
                $pixels[$offset + 3] = [byte]$alpha

                if ($alpha -gt $maximumAlpha) {
                    $maximumAlpha = $alpha
                }
                if (($pixelX -eq 0 -or $pixelX -eq $width - 1 -or
                    $pixelY -eq 0 -or $pixelY -eq $height - 1) -and
                    $alpha -gt $edgeAlphaMaximum) {
                    $edgeAlphaMaximum = $alpha
                }
            }
        }

        [Runtime.InteropServices.Marshal]::Copy(
            $pixels,
            0,
            $bitmapData.Scan0,
            $pixels.Length
        )
    } finally {
        $bitmap.UnlockBits($bitmapData)
    }

    try {
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }

    if ($edgeAlphaMaximum -ne 0) {
        throw "Nebula backdrop edge pixels are not fully transparent"
    }
    if ($maximumAlpha -lt 32 -or $maximumAlpha -gt 80) {
        throw "Nebula backdrop contrast is outside the intended range"
    }

    $image = [Drawing.Image]::FromFile($Path)
    try {
        if ($image.Width -ne $width -or $image.Height -ne $height) {
            throw "Nebula backdrop dimensions are invalid"
        }
    } finally {
        $image.Dispose()
    }

    return [ordered]@{
        file = "MOD/gfx/space/nebula_backdrop.png"
        width = $width
        height = $height
        maximumAlpha = $maximumAlpha
        edgeAlphaMaximum = $edgeAlphaMaximum
        transparentBackground = $true
        starsIncluded = $false
        deterministic = $true
    }
}

$manifestEntries = @()

foreach ($definition in $definitions) {
    Write-Host "Generating $($definition.Id)..."
    $outputPath = Join-Path $outputRoot $definition.FileName
    $generatedModel = New-CelestialModel $definition
    Write-CelestialVox $outputPath $definition $generatedModel

    $parsedModel = Read-CelestialVox $outputPath
    if ($parsedModel.Version -ne 200 -or
        $parsedModel.SizeX -ne $definition.SizeX -or
        $parsedModel.SizeY -ne $definition.SizeY -or
        $parsedModel.SizeZ -ne $definition.SizeZ -or
        $parsedModel.Filled.Count -ne $generatedModel.Filled.Count) {
        throw "Round-trip validation failed for $($definition.Id)"
    }

    foreach ($requiredChunk in @("nTRN", "nGRP", "nSHP", "LAYR")) {
        if ($requiredChunk -notin @($parsedModel.ChunkIds)) {
            throw "Missing $requiredChunk scene chunk for $($definition.Id)"
        }
    }

    $expectedMaterials = @($definition.EmissivePaletteIndices)
    $actualMaterials = @($parsedModel.MaterialIds)
    if ($actualMaterials.Count -ne $expectedMaterials.Count) {
        throw "Unexpected MATL count for $($definition.Id)"
    }
    for ($index = 0; $index -lt $expectedMaterials.Count; $index++) {
        if ($actualMaterials[$index] -ne $expectedMaterials[$index]) {
            throw "Unexpected MATL id for $($definition.Id)"
        }
    }

    $connectivity = Get-ConnectivityStats $parsedModel
    if ($connectivity.ComponentCount -ne 1) {
        throw "$($definition.Id) has $($connectivity.ComponentCount) components"
    }
    $hollow = Get-HollowStats $definition $parsedModel
    if (-not $hollow.CenterEmpty -or $hollow.CoreVoxelCount -ne 0) {
        throw "$($definition.Id) failed hollow-core validation"
    }

    $modelVoxelCapacity =
        $parsedModel.SizeX * $parsedModel.SizeY * $parsedModel.SizeZ
    $modelDiameterMeters = [Math]::Max(
        $parsedModel.SizeX,
        [Math]::Max($parsedModel.SizeY, $parsedModel.SizeZ)
    ) * $scaledVoxelMeters
    $bodyDiameterMeters =
        $definition.BodyDiameterVoxels * $scaledVoxelMeters
    $xmlOffset = @(
        (-0.5 * $parsedModel.SizeX * $scaledVoxelMeters)
        (-0.5 * $parsedModel.SizeY * $scaledVoxelMeters)
        (0.5 * $parsedModel.SizeZ * $scaledVoxelMeters)
    )

    $manifestEntries += [ordered]@{
        id = $definition.Id
        displayName = $definition.DisplayName
        kind = $definition.Kind
        file = "MOD/vox/celestial/$($definition.FileName)"
        voxVersion = $parsedModel.Version
        logicalSizeVoxels = @(
            $parsedModel.SizeX,
            $parsedModel.SizeY,
            $parsedModel.SizeZ
        )
        bodyDiameterVoxels = $definition.BodyDiameterVoxels
        bodyDiameterMetersAtSuggestedScale = $bodyDiameterMeters
        fullModelDiameterMetersAtSuggestedScale = $modelDiameterMeters
        shellThicknessVoxels = $definition.ShellThickness
        ringed = [bool]$definition.Ringed
        paletteColorCount = $definition.Palette.Count
        emissivePaletteIndices = $actualMaterials
        voxelCount = $parsedModel.Filled.Count
        fillFraction = [Math]::Round(
            $parsedModel.Filled.Count / $modelVoxelCapacity,
            6
        )
        connectedComponents = $connectivity.ComponentCount
        largestComponentVoxelCount =
            $connectivity.LargestComponentVoxelCount
        centerEmpty = $hollow.CenterEmpty
        hollowCoreEmpty = ($hollow.CoreVoxelCount -eq 0)
        hollowCoreRadiusVoxels = $hollow.CoreRadiusVoxels
        chunks = @($parsedModel.ChunkIds)
        suggestedXmlScale = $suggestedXmlScale
        suggestedXmlVoxelOffset = $xmlOffset
        suggestedXml = (
            '<vox tags="celestial unbreakable" collide="false" ' +
            'file="MOD/vox/celestial/' +
            $definition.FileName +
            '" scale="' + $suggestedXmlScale + '"/>'
        )
    }

    Write-Host (
        "Validated {0}: {1} voxels, {2} component, hollow core, {3}" -f
        $definition.Id,
        $parsedModel.Filled.Count,
        $connectivity.ComponentCount,
        ($parsedModel.ChunkIds -join "/")
    )

    $generatedModel = $null
    $parsedModel = $null
    [GC]::Collect()
}

$minimumPlanetDiameter = [double]::MaxValue
foreach ($entry in $manifestEntries) {
    if ($entry["kind"] -ne "star") {
        $diameter = [double]$entry[
            "bodyDiameterMetersAtSuggestedScale"
        ]
        if ($diameter -lt $minimumPlanetDiameter) {
            $minimumPlanetDiameter = $diameter
        }
    }
}
if ($minimumPlanetDiameter -lt 96.0) {
    throw "Minimum planet diameter is below 96 meters"
}

$nebulaPath = Join-Path $gfxRoot "nebula_backdrop.png"
$nebulaManifest = Write-NebulaBackdrop $nebulaPath

$manifest = [ordered]@{
    schemaVersion = 1
    generator = "Content Mod 2/tools/build-space-celestials.ps1"
    coordinateConvention = [ordered]@{
        logicalAxes = "Teardown x/y/z"
        storedMagicaAxes = "x/logical-z/logical-y"
        defaultVoxelMeters = $defaultVoxelMeters
        suggestedXmlScale = $suggestedXmlScale
        voxelMetersAtSuggestedScale = $scaledVoxelMeters
    }
    design = [ordered]@{
        bodyCount = $manifestEntries.Count
        starCount = 1
        planetCount = 6
        minimumPlanetDiameterMeters = $minimumPlanetDiameter
        hollowShells = $true
        randomNoiseUsed = $false
        planetsEmissive = $false
        starEmissive = $true
    }
    backdrop = $nebulaManifest
    bodies = $manifestEntries
}

$manifestPath = Join-Path $outputRoot "manifest.json"
$manifestJson = $manifest | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText(
    $manifestPath,
    $manifestJson + [Environment]::NewLine,
    [Text.Encoding]::ASCII
)

Write-Host "Generated and validated $($manifestEntries.Count) celestial bodies."
Write-Host "Manifest: $manifestPath"
Write-Host (
    "Nebula backdrop: {0}x{1}, edge alpha {2}" -f
    $nebulaManifest.width,
    $nebulaManifest.height,
    $nebulaManifest.edgeAlphaMaximum
)
