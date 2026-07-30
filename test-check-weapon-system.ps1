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
    Copy-Item -LiteralPath (Join-Path $sourceMod "main.lua") -Destination (Join-Path $fixtureMod "main.lua")
    [IO.Directory]::CreateDirectory((Join-Path $fixtureMod "gfx\ui")) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod "gfx\ui\weapon_icons") -Destination (Join-Path $fixtureMod "gfx\ui") -Recurse
    [IO.Directory]::CreateDirectory((Join-Path $fixtureMod "gfx\weapons")) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod "gfx\weapons\common") -Destination (Join-Path $fixtureMod "gfx\weapons") -Recurse
    [IO.Directory]::CreateDirectory((Join-Path $fixtureMod "prefabs")) | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceMod "prefabs\swarmerMissile.xml") -Destination (Join-Path $fixtureMod "prefabs\swarmerMissile.xml")
    Copy-Item -LiteralPath (Join-Path $sourceMod "prefabs\devastatorTorpedoes.xml") -Destination (Join-Path $fixtureMod "prefabs\devastatorTorpedoes.xml")
    Copy-Item -LiteralPath (Join-Path $sourceMod "prefabs\gammaStrikeCraft.xml") -Destination (Join-Path $fixtureMod "prefabs\gammaStrikeCraft.xml")
    Copy-Item -LiteralPath (Join-Path $sourceMod "sound") -Destination $fixtureMod -Recurse

    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts the complete weapon system contract"

    $shipCatalogPath = Join-Path $fixtureMod "script\data\ships\ship_catalog.lua"
    $shipCatalogText = [IO.File]::ReadAllText($shipCatalogPath)
    [IO.File]::WriteAllText(
        $shipCatalogPath,
        $shipCatalogText.Replace(
            "#include `"schema.lua`"`r`n#include `"battlecruiser.lua`"",
            "#include `"battlecruiser.lua`"`r`n#include `"schema.lua`""
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidShipIncludeOrder = Invoke-Checker
    Assert-True ($invalidShipIncludeOrder.ExitCode -eq 1) "rejects ship definitions loaded before their schema"
    Assert-True ($invalidShipIncludeOrder.Output -match "schema must be included before") "reports the Teardown include execution contract"
    [IO.File]::WriteAllText(
        $shipCatalogPath,
        $shipCatalogText,
        (New-Object Text.UTF8Encoding($false))
    )

    $entryPath = Join-Path $fixtureMod "script\shipMain.lua"
    $entryText = [IO.File]::ReadAllText($entryPath)
    [IO.File]::WriteAllText(
        $entryPath,
        $entryText.Replace(
            'server.weaponRuntimeCommandTick(dt)',
            'server.weaponGroupTick(dt)'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidWeaponLifecycle = Invoke-Checker
    Assert-True ($invalidWeaponLifecycle.ExitCode -eq 1) "rejects direct concrete weapon lifecycle calls from shipMain"
    Assert-True ($invalidWeaponLifecycle.Output -match "unified runtime|directly calls concrete") "reports the weapon lifecycle boundary"
    [IO.File]::WriteAllText($entryPath, $entryText, (New-Object Text.UTF8Encoding($false)))

    $requestAuthorizerPath = Join-Path $fixtureMod "script\ship\common\server\network\request_authorizer.lua"
    $requestAuthorizerText = [IO.File]::ReadAllText($requestAuthorizerPath)
    [IO.File]::WriteAllText(
        $requestAuthorizerPath,
        ($requestAuthorizerText + "`r`nserver.shipBody = 123`r`n"),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidShipGlobal = Invoke-Checker
    Assert-True ($invalidShipGlobal.ExitCode -eq 1) "rejects implicit battlecruiser runtime globals"
    Assert-True ($invalidShipGlobal.Output -match "implicit battlecruiser") "reports the ShipRuntimeContext boundary"
    [IO.File]::WriteAllText(
        $requestAuthorizerPath,
        $requestAuthorizerText,
        (New-Object Text.UTF8Encoding($false))
    )

    $configUiPath = Join-Path $fixtureMod "script\weapon\client\config_ui\weapon_config_ui.lua"
    $configUiText = [IO.File]::ReadAllText($configUiPath)
    [IO.File]::WriteAllText(
        $configUiPath,
        ($configUiText + "`r`nServerCall(`"server.invalidUiDependency`")`r`n"),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidUiServerCall = Invoke-Checker
    Assert-True ($invalidUiServerCall.ExitCode -eq 1) "rejects server-coupled configuration UI"
    Assert-True ($invalidUiServerCall.Output -match "must not communicate with the server") "reports the local-only UI contract"
    [IO.File]::WriteAllText($configUiPath, $configUiText, (New-Object Text.UTF8Encoding($false)))

    $bindingPath = Join-Path $fixtureMod "script\ship\common\client\config\weapon_configuration_binding.lua"
    $bindingText = [IO.File]::ReadAllText($bindingPath)
    [IO.File]::WriteAllText(
        $bindingPath,
        $bindingText.Replace(
            'ServerCall(',
            'ClientCall('
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidBinding = Invoke-Checker
    Assert-True ($invalidBinding.ExitCode -eq 1) "rejects a missing first-driver server handoff"
    Assert-True ($invalidBinding.Output -match "snapshot and submit") "reports the ship snapshot binding contract"
    [IO.File]::WriteAllText($bindingPath, $bindingText, (New-Object Text.UTF8Encoding($false)))

    $stormfirePath = Join-Path $fixtureMod "script\data\weapons\l\large_stormfire_autocannon.lua"
    $stormfireText = [IO.File]::ReadAllText($stormfirePath)
    [IO.File]::WriteAllText(
        $stormfirePath,
        $stormfireText.Replace('heatPerShot = 4.0', 'heatPerShot = 5.0'),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidHeat = Invoke-Checker
    Assert-True ($invalidHeat.ExitCode -eq 1) "rejects a mismatched Stormfire heat profile"
    Assert-True ($invalidHeat.Output -match "Stormfire|largeStormfireAutocannon") "reports the Stormfire heat contract"
    [IO.File]::WriteAllText($stormfirePath, $stormfireText, (New-Object Text.UTF8Encoding($false)))

    $arcPath = Join-Path $fixtureMod "script\data\weapons\x\focused_arc_emitter.lua"
    $arcText = [IO.File]::ReadAllText($arcPath)
    [IO.File]::WriteAllText(
        $arcPath,
        $arcText.Replace('weaponType = "focusedArcEmitter"', 'weaponType = "brokenArcEmitter"'),
        (New-Object Text.UTF8Encoding($false))
    )

    $invalid = Invoke-Checker
    Assert-True ($invalid.ExitCode -eq 1) "rejects a missing required weapon"
    Assert-True ($invalid.Output -match "focusedArcEmitter") "reports the missing weapon id"
    [IO.File]::WriteAllText($arcPath, $arcText, (New-Object Text.UTF8Encoding($false)))

    $gigaPath = Join-Path $fixtureMod "script\data\weapons\x\giga_cannon.lua"
    $gigaText = [IO.File]::ReadAllText($gigaPath)
    [IO.File]::WriteAllText(
        $gigaPath,
        $gigaText.Replace(
            'salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.18 }',
            'salvoProfile = { groupSize = 2, sequence = "grouped", interval = 0.18 }'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidGiga = Invoke-Checker
    Assert-True ($invalidGiga.ExitCode -eq 1) "rejects simultaneous Giga Cannon barrels"
    Assert-True ($invalidGiga.Output -match "Giga Cannon|gigaCannon") "reports the Giga Cannon salvo contract"
    [IO.File]::WriteAllText($gigaPath, $gigaText, (New-Object Text.UTF8Encoding($false)))

    $shieldPath = Join-Path $fixtureMod "script\weapon\client\common\effects\shield_hit_fx.lua"
    $shieldText = [IO.File]::ReadAllText($shieldPath)
    [IO.File]::WriteAllText(
        $shieldPath,
        $shieldText.Replace('maxRing = 4', 'maxRing = 3'),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidShieldLayers = Invoke-Checker
    Assert-True ($invalidShieldLayers.ExitCode -eq 1) "rejects an incomplete shield hex expansion"
    Assert-True ($invalidShieldLayers.Output -match "fixed five-layer hex sprite") "reports the shield visual contract"
    [IO.File]::WriteAllText($shieldPath, $shieldText, (New-Object Text.UTF8Encoding($false)))

    $shieldAssetPath = Join-Path $fixtureMod "gfx\weapons\common\hex_soft.png"
    Remove-Item -LiteralPath $shieldAssetPath -Force
    $invalidShieldAsset = Invoke-Checker
    Assert-True ($invalidShieldAsset.ExitCode -eq 1) "rejects a missing shield hex sprite"
    Assert-True ($invalidShieldAsset.Output -match "fixed five-layer hex sprite") "reports the missing shield sprite contract"
    Copy-Item -LiteralPath (Join-Path $sourceMod "gfx\weapons\common\hex_soft.png") -Destination $shieldAssetPath

    $inputPath = Join-Path $fixtureMod "script\weapon\client\common\input\main_weapon_input.lua"
    $inputText = [IO.File]::ReadAllText($inputPath).Replace('InputDown("lmb")', 'InputPressed("lmb")')
    [IO.File]::WriteAllText($inputPath, $inputText, (New-Object Text.UTF8Encoding($false)))
    $invalidHold = Invoke-Checker
    Assert-True ($invalidHold.ExitCode -eq 1) "rejects click-only weapon input"
    Assert-True ($invalidHold.Output -match "hold-to-refire") "reports the continuous-fire input contract"

    $snapshotPath = Join-Path $fixtureMod "script\net\client_input_snapshot.lua"
    $snapshotText = [IO.File]::ReadAllText($snapshotPath)
    [IO.File]::WriteAllText(
        $snapshotPath,
        $snapshotText.Replace(
            'activeInterval = 0.05',
            'activeInterval = 0.001'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidSnapshot = Invoke-Checker
    Assert-True ($invalidSnapshot.ExitCode -eq 1) "rejects frame-rate-driven control snapshots"
    Assert-True ($invalidSnapshot.Output -match "validated 20 Hz input snapshot") "reports the control snapshot contract"
    [IO.File]::WriteAllText($snapshotPath, $snapshotText, (New-Object Text.UTF8Encoding($false)))

    $runtimeStatePath = Join-Path $fixtureMod "script\ship\common\server\state\runtime_state.lua"
    $runtimeStateText = [IO.File]::ReadAllText($runtimeStatePath)
    [IO.File]::WriteAllText(
        $runtimeStatePath,
        $runtimeStateText.Replace(
            '_normalizeMode(mainWeapon.current, definition)',
            '_normalizeMode(mainWeapon.current)'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidMainWeaponSync = Invoke-Checker
    Assert-True ($invalidMainWeaponSync.ExitCode -eq 1) "rejects main weapon sync without its ship definition"
    Assert-True ($invalidMainWeaponSync.Output -match "normalize against the active ship definition") "reports the Q-toggle synchronization contract"
    [IO.File]::WriteAllText(
        $runtimeStatePath,
        $runtimeStateText,
        (New-Object Text.UTF8Encoding($false))
    )

    $entryWithMissingSound = $entryText + "`r`nLoadSound(`"MOD/sound/missing_runtime_asset.ogg`")`r`n"
    [IO.File]::WriteAllText(
        $entryPath,
        $entryWithMissingSound,
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidStaticSound = Invoke-Checker
    Assert-True ($invalidStaticSound.ExitCode -eq 1) "rejects a static LoadSound reference to a missing file"
    Assert-True ($invalidStaticSound.Output -match "missing sound asset") "reports the missing runtime sound reference"
    [IO.File]::WriteAllText($entryPath, $entryText, (New-Object Text.UTF8Encoding($false)))

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
