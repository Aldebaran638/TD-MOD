# Self-test for check-weapon-system.ps1.

param([switch]$KeepFixtures)

$ErrorActionPreference = "Stop"
$checker = Join-Path $PSScriptRoot "check-weapon-system.ps1"
$sourceMod = Join-Path $PSScriptRoot "Content Mod 2"
$fixtureRoot = Join-Path $PSScriptRoot (".weapon-check-test-" + [Guid]::NewGuid().ToString("N"))
$fixtureMod = Join-Path $fixtureRoot "Content Mod 2"
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failures++
    }
}

function Invoke-Checker {
    $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $fixtureMod 2>&1
    return @{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

try {
    [IO.Directory]::CreateDirectory($fixtureMod) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod "script") -Destination $fixtureMod -Recurse
    [IO.Directory]::CreateDirectory((Join-Path $fixtureMod "prefabs")) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod "prefabs\swarmerMissile.xml") -Destination (Join-Path $fixtureMod "prefabs\swarmerMissile.xml")
    Copy-Item -LiteralPath (Join-Path $sourceMod "prefabs\devastatorTorpedoes.xml") -Destination (Join-Path $fixtureMod "prefabs\devastatorTorpedoes.xml")

    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts the complete weapon system contract"

    $standardPath = Join-Path $fixtureMod "script\data\weapons\standard_weapons.lua"
    $text = [IO.File]::ReadAllText($standardPath)
    $text = $text.Replace('_ray("focusedArcEmitter"', '_ray("brokenArcEmitter"')
    [IO.File]::WriteAllText($standardPath, $text, (New-Object Text.UTF8Encoding($false)))

    $invalid = Invoke-Checker
    Assert-True ($invalid.ExitCode -eq 1) "rejects a missing required weapon"
    Assert-True ($invalid.Output -match "focusedArcEmitter") "reports the missing weapon id"
}
finally {
    if ($KeepFixtures) {
        Write-Host "Fixtures kept at: $fixtureRoot"
    }
    elseif (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

if ($failures -gt 0) {
    Write-Host "Self-test failed: $failures assertion(s)." -ForegroundColor Red
    exit 1
}
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
