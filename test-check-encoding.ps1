# Self-test for check-encoding.ps1. Creates intentionally malformed Lua fixtures in TEMP.

param(
    [switch]$KeepFixtures
)

$checker = Join-Path $PSScriptRoot "check-encoding.ps1"
if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) {
    Write-Host "[FAIL] Checker not found: $checker" -ForegroundColor Red
    exit 1
}

$fixtureRoot = Join-Path $PSScriptRoot (".encoding-check-test-" + [Guid]::NewGuid().ToString("N"))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failures++
    }
}

function Invoke-Checker {
    param([switch]$Fix)

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $checker,
        "-Path", $fixtureRoot
    )
    if ($Fix) {
        $arguments += "-Fix"
    }

    $output = & $powershellExe @arguments 2>&1
    return @{
        ExitCode = $LASTEXITCODE
        Text = ($output | Out-String)
    }
}

function Test-Utf8NoBomCrLf {
    param([string]$FilePath)

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return $false
    }

    try {
        $text = $strictUtf8.GetString($bytes)
    }
    catch {
        return $false
    }

    for ($i = 0; $i -lt $text.Length; $i++) {
        $code = [int]$text[$i]
        if ($code -eq 10 -and ($i -eq 0 -or [int]$text[$i - 1] -ne 13)) {
            return $false
        }
        if ($code -eq 13 -and ($i + 1 -ge $text.Length -or [int]$text[$i + 1] -ne 10)) {
            return $false
        }
    }
    return $true
}

try {
    [System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null

    $goodPath = Join-Path $fixtureRoot "good-crlf.lua"
    $bomPath = Join-Path $fixtureRoot "utf8-bom.lua"
    $utf16Path = Join-Path $fixtureRoot "utf16-le.lua"
    $utf16NoBomPath = Join-Path $fixtureRoot "utf16-no-bom.lua"
    $malformedPath = Join-Path $fixtureRoot "malformed-utf8.lua"
    $gbkPath = Join-Path $fixtureRoot "gbk.lua"
    $lfPath = Join-Path $fixtureRoot "lf-only.lua"

    [System.IO.File]::WriteAllText($goodPath, "local good = true`r`nreturn good`r`n", $utf8NoBom)
    [System.IO.File]::WriteAllText($bomPath, "local bom = true`r`nreturn bom`r`n", $utf8Bom)
    [System.IO.File]::WriteAllText($utf16Path, "local wide = true`r`nreturn wide`r`n", [System.Text.Encoding]::Unicode)
    [System.IO.File]::WriteAllBytes($utf16NoBomPath, [System.Text.Encoding]::Unicode.GetBytes("local wide = true`r`nreturn wide`r`n"))
    [System.IO.File]::WriteAllBytes($malformedPath, [byte[]](0x6C, 0x6F, 0x63, 0x61, 0x6C, 0x20, 0x78, 0x20, 0x3D, 0x20, 0xC3, 0x28, 0x0D, 0x0A))
    $chineseText = ([string][char]0x4E2D) + ([string][char]0x6587)
    [System.IO.File]::WriteAllBytes($gbkPath, [System.Text.Encoding]::GetEncoding(936).GetBytes("-- $chineseText`r`nlocal x = true`r`n"))
    [System.IO.File]::WriteAllText($lfPath, "local lf = true`nreturn lf`n", $utf8NoBom)

    Write-Host "Fixtures: $fixtureRoot" -ForegroundColor Cyan

    $check = Invoke-Checker
    Write-Host $check.Text
    Assert-True ($check.ExitCode -eq 1) "initial check exits with code 1"
    Assert-True ($check.Text.Contains("utf8-bom.lua") -and $check.Text.Contains("UTF-8 BOM")) "detects UTF-8 BOM"
    Assert-True ($check.Text.Contains("utf16-le.lua") -and $check.Text.Contains("UTF-16 LE")) "detects UTF-16 LE"
    Assert-True ($check.Text.Contains("utf16-no-bom.lua") -and $check.Text.Contains("possible UTF-16 without BOM")) "detects possible UTF-16 without BOM"
    Assert-True ($check.Text.Contains("malformed-utf8.lua") -and $check.Text.Contains("invalid UTF-8")) "detects malformed UTF-8"
    Assert-True ($check.Text.Contains("gbk.lua") -and $check.Text.Contains("possibly ANSI/GBK")) "detects non-UTF-8 GBK bytes"
    Assert-True ($check.Text.Contains("lf-only.lua") -and $check.Text.Contains("non-CRLF line endings")) "detects LF-only line endings"
    Assert-True (-not $check.Text.Contains("[ISSUE] $goodPath")) "accepts valid UTF-8 without BOM and CRLF"

    $fix = Invoke-Checker -Fix
    Write-Host $fix.Text
    Assert-True ($fix.ExitCode -eq 1) "fix run remains failing when ambiguous files need manual conversion"
    Assert-True (Test-Utf8NoBomCrLf -FilePath $bomPath) "fixes UTF-8 BOM file"
    Assert-True (Test-Utf8NoBomCrLf -FilePath $utf16Path) "converts BOM-marked UTF-16 LE file"
    Assert-True (Test-Utf8NoBomCrLf -FilePath $lfPath) "normalizes LF-only file to CRLF"

    Remove-Item -LiteralPath $utf16NoBomPath, $malformedPath, $gbkPath -Force
    $finalCheck = Invoke-Checker
    Write-Host $finalCheck.Text
    Assert-True ($finalCheck.ExitCode -eq 0) "second check passes after fixable issues are repaired and ambiguous fixtures are removed"
}
finally {
    if ($KeepFixtures) {
        Write-Host "Fixtures kept at: $fixtureRoot" -ForegroundColor Yellow
    }
    elseif (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

if ($failures -gt 0) {
    Write-Host "Self-test failed: $failures assertion(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
