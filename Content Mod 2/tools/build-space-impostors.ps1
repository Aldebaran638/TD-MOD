[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Drawing

$modRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$outputRoot = [IO.Path]::GetFullPath((Join-Path $modRoot "gfx\space\celestial"))
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null

function New-Color {
    param([int]$A, [int]$R, [int]$G, [int]$B)
    return [Drawing.Color]::FromArgb($A, $R, $G, $B)
}

function New-PlanetBitmap {
    param(
        [string]$Name,
        [Drawing.Color]$Center,
        [Drawing.Color]$Edge,
        [Drawing.Color[]]$Details,
        [ValidateSet("continents", "bands", "cracks", "ice", "ocean", "desert")]
        [string]$Pattern,
        [switch]$Ringed
    )

    $size = 512
    $bitmap = New-Object Drawing.Bitmap $size, $size,
        ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([Drawing.Color]::Transparent)

        if ($Ringed) {
            $graphics.TranslateTransform(256, 256)
            $graphics.RotateTransform(-12)
            $ringPen = New-Object Drawing.Pen (New-Color 190 205 164 118), 34
            $ringPen.StartCap = [Drawing.Drawing2D.LineCap]::Round
            $ringPen.EndCap = [Drawing.Drawing2D.LineCap]::Round
            $graphics.DrawEllipse($ringPen, -226, -70, 452, 140)
            $ringPen.Dispose()
            $graphics.ResetTransform()
        }

        $disc = New-Object Drawing.Drawing2D.GraphicsPath
        $disc.AddEllipse(62, 62, 388, 388)
        $gradient = New-Object Drawing.Drawing2D.PathGradientBrush $disc
        $gradient.CenterPoint = New-Object Drawing.PointF 174, 142
        $gradient.CenterColor = $Center
        $gradient.SurroundColors = @($Edge)
        $graphics.FillPath($gradient, $disc)

        $oldClip = $graphics.Clip
        $graphics.SetClip($disc)

        if ($Pattern -eq "bands") {
            $bandColors = @($Details)
            for ($index = 0; $index -lt 9; $index++) {
                $height = 18 + (($index * 7) % 13)
                $y = 92 + $index * 37
                $brush = New-Object Drawing.SolidBrush $bandColors[$index % $bandColors.Count]
                $graphics.FillEllipse($brush, 48, $y, 416, $height)
                $brush.Dispose()
            }
        } else {
            $paths = @(
                @([Drawing.PointF]::new(90, 205), [Drawing.PointF]::new(145, 135), [Drawing.PointF]::new(220, 155), [Drawing.PointF]::new(244, 220), [Drawing.PointF]::new(176, 270), [Drawing.PointF]::new(112, 252)),
                @([Drawing.PointF]::new(270, 104), [Drawing.PointF]::new(360, 126), [Drawing.PointF]::new(420, 205), [Drawing.PointF]::new(382, 262), [Drawing.PointF]::new(310, 236)),
                @([Drawing.PointF]::new(235, 292), [Drawing.PointF]::new(318, 260), [Drawing.PointF]::new(402, 310), [Drawing.PointF]::new(360, 390), [Drawing.PointF]::new(275, 420), [Drawing.PointF]::new(210, 365))
            )
            for ($index = 0; $index -lt $paths.Count; $index++) {
                $detailPath = New-Object Drawing.Drawing2D.GraphicsPath
                $detailPath.AddClosedCurve($paths[$index], 0.35)
                $brush = New-Object Drawing.SolidBrush $Details[$index % $Details.Count]
                if ($Pattern -eq "cracks") {
                    $pen = New-Object Drawing.Pen $Details[$index % $Details.Count], 12
                    $graphics.DrawPath($pen, $detailPath)
                    $pen.Dispose()
                } else {
                    $graphics.FillPath($brush, $detailPath)
                }
                $brush.Dispose()
                $detailPath.Dispose()
            }

            if ($Pattern -eq "ice") {
                $icePen = New-Object Drawing.Pen $Details[0], 18
                $graphics.DrawArc($icePen, 76, 72, 360, 120, 5, 170)
                $graphics.DrawArc($icePen, 76, 322, 360, 120, 185, 170)
                $icePen.Dispose()
            }
        }

        $graphics.Clip = $oldClip
        $oldClip.Dispose()

        $shadeBrush = New-Object Drawing.Drawing2D.LinearGradientBrush (
            [Drawing.RectangleF]::new(62, 62, 388, 388)
        ), (New-Color 0 0 0 0), (New-Color 155 0 0 0), 25
        $graphics.FillPath($shadeBrush, $disc)
        $shadeBrush.Dispose()

        $rimPen = New-Object Drawing.Pen (New-Color 130 205 224 238), 2
        $graphics.DrawPath($rimPen, $disc)
        $rimPen.Dispose()

        if ($Ringed) {
            $graphics.TranslateTransform(256, 256)
            $graphics.RotateTransform(-12)
            $frontPen = New-Object Drawing.Pen (New-Color 225 232 201 158), 12
            $graphics.DrawArc($frontPen, -226, -70, 452, 140, 6, 168)
            $frontPen.Dispose()
            $graphics.ResetTransform()
        }

        $gradient.Dispose()
        $disc.Dispose()
        $path = Join-Path $outputRoot ($Name + ".png")
        $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
        Write-Output ("WROTE " + $path)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function New-StarBitmap {
    $bitmap = New-Object Drawing.Bitmap 512, 512,
        ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([Drawing.Color]::Transparent)
        foreach ($layer in @(
            @(18, 18, 476, 476, (New-Color 20 255 112 18)),
            @(52, 52, 408, 408, (New-Color 45 255 146 24)),
            @(92, 92, 328, 328, (New-Color 95 255 184 48))
        )) {
            $brush = New-Object Drawing.SolidBrush $layer[4]
            $graphics.FillEllipse($brush, $layer[0], $layer[1], $layer[2], $layer[3])
            $brush.Dispose()
        }
        $disc = New-Object Drawing.Drawing2D.GraphicsPath
        $disc.AddEllipse(126, 126, 260, 260)
        $gradient = New-Object Drawing.Drawing2D.PathGradientBrush $disc
        $gradient.CenterPoint = [Drawing.PointF]::new(216, 198)
        $gradient.CenterColor = New-Color 255 255 251 206
        $gradient.SurroundColors = @((New-Color 255 255 113 18))
        $graphics.FillPath($gradient, $disc)
        $gradient.Dispose()
        $disc.Dispose()
        $path = Join-Path $outputRoot "star_g_yellow.png"
        $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
        Write-Output ("WROTE " + $path)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

New-PlanetBitmap "planet_continental" `
    (New-Color 255 92 171 185) (New-Color 255 4 20 46) `
    @((New-Color 235 49 122 70), (New-Color 225 116 146 82), (New-Color 210 220 229 220)) `
    "continents"
New-PlanetBitmap "planet_desert" `
    (New-Color 255 243 202 135) (New-Color 255 79 36 30) `
    @((New-Color 210 185 105 58), (New-Color 190 112 57 42), (New-Color 175 247 221 173)) `
    "desert"
New-PlanetBitmap "planet_gas_giant_ringed" `
    (New-Color 255 239 198 145) (New-Color 255 72 49 78) `
    @((New-Color 185 122 78 92), (New-Color 180 223 161 103), (New-Color 175 247 220 171)) `
    "bands" -Ringed
New-PlanetBitmap "planet_frozen" `
    (New-Color 255 218 240 242) (New-Color 255 20 48 82) `
    @((New-Color 225 149 204 222), (New-Color 205 56 112 154), (New-Color 190 239 248 244)) `
    "ice"
New-PlanetBitmap "planet_volcanic" `
    (New-Color 255 110 65 48) (New-Color 255 19 15 23) `
    @((New-Color 245 255 136 35), (New-Color 230 215 57 20), (New-Color 210 93 48 42)) `
    "cracks"
New-PlanetBitmap "planet_ocean" `
    (New-Color 255 76 188 196) (New-Color 255 3 29 70) `
    @((New-Color 220 212 236 229), (New-Color 190 35 128 151), (New-Color 175 108 194 190)) `
    "ocean"
New-StarBitmap
