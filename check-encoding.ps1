# Teardown Lua source encoding and line-ending checker

param(
    [string]$Path = ".",
    [switch]$Fix,
    [switch]$Verbose
)

Write-Host "=== Teardown Mod Source Checker ===" -ForegroundColor Cyan
Write-Host ""

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
$strictUtf16Le = New-Object System.Text.UnicodeEncoding($false, $true, $true)
$strictUtf16Be = New-Object System.Text.UnicodeEncoding($true, $true, $true)

$checkedCount = 0
$issueCount = 0
$fixedCount = 0
$failedCount = 0
$unfixableCount = 0

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

function Test-LooksLikeUtf16WithoutBom {
    param([byte[]]$Bytes)

    if ($Bytes.Length -lt 4) {
        return $false
    }

    $pairCount = [Math]::Floor($Bytes.Length / 2)
    $evenNulls = 0
    $oddNulls = 0
    for ($i = 0; $i -lt ($pairCount * 2); $i += 2) {
        if ($Bytes[$i] -eq 0) { $evenNulls++ }
        if ($Bytes[$i + 1] -eq 0) { $oddNulls++ }
    }

    $threshold = [Math]::Max(2, [Math]::Ceiling($pairCount * 0.3))
    return (($evenNulls -ge $threshold -and $oddNulls -lt $threshold) -or
            ($oddNulls -ge $threshold -and $evenNulls -lt $threshold))
}

function Get-LineEndingIssues {
    param([string]$Text)

    $lfWithoutCr = 0
    $crWithoutLf = 0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $code = [int]$Text[$i]
        if ($code -eq 10) {
            if ($i -eq 0 -or [int]$Text[$i - 1] -ne 13) {
                $lfWithoutCr++
            }
        }
        elseif ($code -eq 13) {
            if ($i + 1 -ge $Text.Length -or [int]$Text[$i + 1] -ne 10) {
                $crWithoutLf++
            }
        }
    }

    return @($lfWithoutCr, $crWithoutLf)
}

$files = Get-ChildItem -LiteralPath $Path -Filter *.lua -Recurse -File -ErrorAction SilentlyContinue
foreach ($file in $files) {
    $checkedCount++
    $issues = @()
    $content = $null
    $canFix = $true

    try {
        [byte[]]$bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    }
    catch {
        Write-Host "[ERROR] Cannot read: $($file.FullName): $_" -ForegroundColor Red
        $issueCount++
        $failedCount++
        continue
    }

    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $hasUtf16LeBom = $bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE
    $hasUtf16BeBom = $bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF
    $hasUtf32Bom = $bytes.Length -ge 4 -and (
        ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) -or
        ($bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF)
    )

    try {
        if ($hasUtf32Bom) {
            $issues += "UTF-32 is not supported"
            $canFix = $false
        }
        elseif ($hasUtf8Bom) {
            $issues += "UTF-8 BOM"
            $content = $strictUtf8.GetString($bytes, 3, $bytes.Length - 3)
        }
        elseif ($hasUtf16LeBom) {
            $issues += "UTF-16 LE"
            $content = $strictUtf16Le.GetString($bytes, 2, $bytes.Length - 2)
        }
        elseif ($hasUtf16BeBom) {
            $issues += "UTF-16 BE"
            $content = $strictUtf16Be.GetString($bytes, 2, $bytes.Length - 2)
        }
        elseif (Test-LooksLikeUtf16WithoutBom -Bytes $bytes) {
            $issues += "possible UTF-16 without BOM"
            $canFix = $false
        }
        else {
            $content = $strictUtf8.GetString($bytes)
        }
    }
    catch {
        $issues += "invalid UTF-8 or malformed Unicode (possibly ANSI/GBK)"
        $content = $null
        $canFix = $false
    }

    if ($content -ne $null) {
        $lineIssues = Get-LineEndingIssues -Text $content
        if ($lineIssues[0] -gt 0 -or $lineIssues[1] -gt 0) {
            $issues += "non-CRLF line endings (LF-only: $($lineIssues[0]), CR-only: $($lineIssues[1]))"
        }
    }

    if ($issues.Count -eq 0) {
        if ($Verbose) {
            Write-Host "[OK] $($file.FullName)" -ForegroundColor Green
        }
        continue
    }

    $issueCount++
    Write-Host "[ISSUE] $($file.FullName)" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "        - $issue" -ForegroundColor Yellow
    }

    if (-not $Fix) {
        continue
    }

    if (-not $canFix -or $content -eq $null) {
        Write-Host "        [NOT FIXED] Encoding cannot be determined safely" -ForegroundColor Yellow
        $unfixableCount++
        continue
    }

    try {
        $normalized = $content.Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
        [System.IO.File]::WriteAllText($file.FullName, $normalized, $utf8NoBom)
        Write-Host "        [FIXED] UTF-8 without BOM, CRLF" -ForegroundColor Green
        $fixedCount++
    }
    catch {
        Write-Host "        [FAILED] $_" -ForegroundColor Red
        $failedCount++
    }
}

Write-Host ""
Write-Host "Check complete: $checkedCount files checked, $issueCount files with issues" -ForegroundColor Cyan

if ($Fix) {
    Write-Host "Fix result: $fixedCount fixed, $unfixableCount need manual conversion, $failedCount failed" -ForegroundColor Cyan
}

if ($issueCount -eq 0) {
    Write-Host "OK - All Lua files are valid UTF-8 without BOM and use CRLF." -ForegroundColor Green
    exit 0
}

if ($Fix -and $unfixableCount -eq 0 -and $failedCount -eq 0 -and $fixedCount -eq $issueCount) {
    Write-Host "OK - All detected issues were fixed." -ForegroundColor Green
    exit 0
}

if (-not $Fix) {
    Write-Host "Tip: rerun with -Fix to repair safe, unambiguous issues." -ForegroundColor Yellow
}
exit 1
