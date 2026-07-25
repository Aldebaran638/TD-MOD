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
    Copy-Item -LiteralPath (Join-Path $sourceMod "main.xml") -Destination (Join-Path $fixtureMod "main.xml")
    [IO.Directory]::CreateDirectory((Join-Path $fixtureMod "gfx\ui")) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod "gfx\ui\weapon_icons") -Destination (Join-Path $fixtureMod "gfx\ui") -Recurse
    [IO.Directory]::CreateDirectory((Join-Path $fixtureMod "prefabs")) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod "prefabs\swarmerMissile.xml") -Destination (Join-Path $fixtureMod "prefabs\swarmerMissile.xml")
    Copy-Item -LiteralPath (Join-Path $sourceMod "prefabs\devastatorTorpedoes.xml") -Destination (Join-Path $fixtureMod "prefabs\devastatorTorpedoes.xml")
    [IO.Directory]::CreateDirectory((Join-Path $fixtureMod "sound")) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod "sound\weapons") -Destination (Join-Path $fixtureMod "sound") -Recurse

    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts the complete weapon system contract"

    $standardPath = Join-Path $fixtureMod "script\data\weapons\standard_weapons.lua"
    $text = [IO.File]::ReadAllText($standardPath)

    $heatText = $text.Replace('definition.heatPerShot = 4.0', 'definition.heatPerShot = 5.0')
    [IO.File]::WriteAllText($standardPath, $heatText, (New-Object Text.UTF8Encoding($false)))
    $invalidHeat = Invoke-Checker
    Assert-True ($invalidHeat.ExitCode -eq 1) "rejects a mismatched Stormfire heat profile"
    Assert-True ($invalidHeat.Output -match "Stormfire Autocannons") "reports the Stormfire heat contract"

    [IO.File]::WriteAllText($standardPath, $text, (New-Object Text.UTF8Encoding($false)))
    $text = $text.Replace('_ray("focusedArcEmitter"', '_ray("brokenArcEmitter"')
    [IO.File]::WriteAllText($standardPath, $text, (New-Object Text.UTF8Encoding($false)))

    $invalid = Invoke-Checker
    Assert-True ($invalid.ExitCode -eq 1) "rejects a missing required weapon"
    Assert-True ($invalid.Output -match "focusedArcEmitter") "reports the missing weapon id"

    [IO.File]::WriteAllText($standardPath, $text.Replace('_ray("brokenArcEmitter"', '_ray("focusedArcEmitter"'), (New-Object Text.UTF8Encoding($false)))
    $profileText = [IO.File]::ReadAllText($standardPath)
    $profileText = $profileText.Replace(
        'gigaCannon = { "xSpinal", 1, "sequential" }',
        'gigaCannon = { "xSpinal", 2, "grouped" }'
    )
    [IO.File]::WriteAllText($standardPath, $profileText, (New-Object Text.UTF8Encoding($false)))
    $invalidGiga = Invoke-Checker
    Assert-True ($invalidGiga.ExitCode -eq 1) "rejects simultaneous Giga Cannon barrels"
    Assert-True ($invalidGiga.Output -match "Giga Cannon") "reports the Giga Cannon salvo contract"

    [IO.File]::WriteAllText($standardPath, $text.Replace('_ray("brokenArcEmitter"', '_ray("focusedArcEmitter"'), (New-Object Text.UTF8Encoding($false)))
    $inputPath = Join-Path $fixtureMod "script\weapon\client\common\input\main_weapon_input.lua"
    $inputText = [IO.File]::ReadAllText($inputPath).Replace('InputDown("lmb")', 'InputPressed("lmb")')
    [IO.File]::WriteAllText($inputPath, $inputText, (New-Object Text.UTF8Encoding($false)))
    $invalidHold = Invoke-Checker
    Assert-True ($invalidHold.ExitCode -eq 1) "rejects click-only weapon input"
    Assert-True ($invalidHold.Output -match "hold-to-refire") "reports the continuous-fire input contract"

    $missingSound = Join-Path $fixtureMod "sound\weapons\tachyonLance"
    Remove-Item -LiteralPath $missingSound -Recurse -Force
    $invalidSound = Invoke-Checker
    Assert-True ($invalidSound.ExitCode -eq 1) "rejects a weapon without dedicated audio assets"
    Assert-True ($invalidSound.Output -match "tachyonLance.*dedicated OGG") "reports the missing weapon audio directory"
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
