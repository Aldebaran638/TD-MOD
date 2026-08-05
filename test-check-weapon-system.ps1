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

    $radialWeaponWheelPath = Join-Path $fixtureMod "script\weapon\client\common\hud\radial_weapon_wheel.lua"
    $radialWeaponWheelText = [IO.File]::ReadAllText($radialWeaponWheelPath)
    [IO.File]::WriteAllText(
        $radialWeaponWheelPath,
        $radialWeaponWheelText.Replace(
            'function client.radialWeaponWheelDraw(',
            'function client.radialWeaponWheelDrawBroken('
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidRadialWeaponWheel = Invoke-Checker
    Assert-True ($invalidRadialWeaponWheel.ExitCode -eq 1) "rejects a HUD without the shared radial weapon wheel"
    Assert-True ($invalidRadialWeaponWheel.Output -match "radial weapon wheel") "reports the shared radial weapon wheel contract"
    [IO.File]::WriteAllText(
        $radialWeaponWheelPath,
        $radialWeaponWheelText,
        (New-Object Text.UTF8Encoding($false))
    )

    $perditionBeamPath = Join-Path $fixtureMod "script\data\weapons\t\perdition_beam.lua"
    $perditionBeamText = [IO.File]::ReadAllText($perditionBeamPath)
    [IO.File]::WriteAllText(
        $perditionBeamPath,
        $perditionBeamText.Replace(
            'perdition_beam.png',
            'tachyonLance.png'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidPerditionIcon = Invoke-Checker
    Assert-True ($invalidPerditionIcon.ExitCode -eq 1) "rejects a Perdition Beam using the Tachyon Lance icon"
    Assert-True ($invalidPerditionIcon.Output -match "official Stellaris Perdition icon") "reports the Stellaris Perdition Beam icon contract"
    [IO.File]::WriteAllText(
        $perditionBeamPath,
        $perditionBeamText,
        (New-Object Text.UTF8Encoding($false))
    )

    [IO.File]::WriteAllText(
        $radialWeaponWheelPath,
        $radialWeaponWheelText.Replace(
            'UiColor(1.0, 1.0, 1.0, alpha)',
            'UiColor(0.8, 0.8, 0.8, alpha)'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidTintedRadialWeaponWheel = Invoke-Checker
    Assert-True ($invalidTintedRadialWeaponWheel.ExitCode -eq 1) "rejects a radial wheel that tints source weapon icons"
    Assert-True ($invalidTintedRadialWeaponWheel.Output -match "radial weapon wheel") "reports the icon color preservation contract"
    [IO.File]::WriteAllText(
        $radialWeaponWheelPath,
        $radialWeaponWheelText,
        (New-Object Text.UTF8Encoding($false))
    )

    $targetingPolicyPath = Join-Path $fixtureMod "script\weapon\common\targeting_policy.lua"
    $targetingPolicyText = [IO.File]::ReadAllText($targetingPolicyPath)
    [IO.File]::WriteAllText(
        $targetingPolicyPath,
        $targetingPolicyText.Replace(
            'if weapon.requiresTargetLock ~= nil then',
            'if weapon.requiresTargetLock == true then'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidTargetingPolicy = Invoke-Checker
    Assert-True ($invalidTargetingPolicy.ExitCode -eq 1) "rejects a targeting policy without an explicit override"
    Assert-True ($invalidTargetingPolicy.Output -match "lock policy") "reports the shared targeting policy contract"
    [IO.File]::WriteAllText(
        $targetingPolicyPath,
        $targetingPolicyText,
        (New-Object Text.UTF8Encoding($false))
    )

    $groupRuntimePath = Join-Path $fixtureMod "script\weapon\server\common\runtime\weapon_group.lua"
    $groupRuntimeText = [IO.File]::ReadAllText($groupRuntimePath)
    [IO.File]::WriteAllText(
        $groupRuntimePath,
        $groupRuntimeText.Replace(
            'local function _weaponGroupValidateRequest(',
            'local function _weaponGroupValidateRequestBroken('
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidRequestBoundary = Invoke-Checker
    Assert-True ($invalidRequestBoundary.ExitCode -eq 1) "rejects weapon hold/fire paths without a shared request validator"
    Assert-True ($invalidRequestBoundary.Output -match "shared server validation boundary") "reports the shared request validation contract"
    [IO.File]::WriteAllText(
        $groupRuntimePath,
        $groupRuntimeText,
        (New-Object Text.UTF8Encoding($false))
    )

    $shipSchemaPath = Join-Path $fixtureMod "script\data\ships\schema.lua"
    $shipSchemaText = [IO.File]::ReadAllText($shipSchemaPath)
    [IO.File]::WriteAllText(
        $shipSchemaPath,
        $shipSchemaText.Replace(
            'function shipDefinitionNormalizeSalvoGroupSize(value, count)',
            'function shipDefinitionNormalizeSalvoGroupSizeBroken(value, count)'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidSalvoNormalization = Invoke-Checker
    Assert-True ($invalidSalvoNormalization.ExitCode -eq 1) "rejects Titan salvo configuration without schema normalization"
    Assert-True ($invalidSalvoNormalization.Output -match "Titan L batteries") "reports the canonical salvo normalization contract"
    [IO.File]::WriteAllText(
        $shipSchemaPath,
        $shipSchemaText,
        (New-Object Text.UTF8Encoding($false))
    )

    $generatedCatalogPath = Join-Path $fixtureMod "script\data\weapons\stellaris_generated_4_4_6.lua"
    $generatedCatalogText = [IO.File]::ReadAllText($generatedCatalogPath)
    [IO.File]::WriteAllText(
        $generatedCatalogPath,
        $generatedCatalogText.Replace('local _generatedSizes = {', 'local _sizes = {'),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidGeneratedScope = Invoke-Checker
    Assert-True ($invalidGeneratedScope.ExitCode -eq 1) "rejects generated catalogs that depend on parent include locals"
    Assert-True ($invalidGeneratedScope.Output -match "self-contained across Teardown include scopes") "reports the generated include scope contract"
    [IO.File]::WriteAllText(
        $generatedCatalogPath,
        $generatedCatalogText,
        (New-Object Text.UTF8Encoding($false))
    )

    $tachyonPowerPath = Join-Path $fixtureMod "script\data\weapons\x\tachyon_lance.lua"
    $tachyonPowerText = [IO.File]::ReadAllText($tachyonPowerPath)
    [IO.File]::WriteAllText(
        $tachyonPowerPath,
        $tachyonPowerText.Replace('powerUse = 260.0', 'powerUse = 261.0'),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidOfficialPower = Invoke-Checker
    Assert-True ($invalidOfficialPower.ExitCode -eq 1) "rejects a non-official Stellaris weapon power value"
    Assert-True ($invalidOfficialPower.Output -match "tachyonLance.*power") "reports the official Stellaris power contract"
    [IO.File]::WriteAllText(
        $tachyonPowerPath,
        $tachyonPowerText,
        (New-Object Text.UTF8Encoding($false))
    )

    $shipCatalogPath = Join-Path $fixtureMod "script\data\ships\ship_catalog.lua"
    $shipCatalogText = [IO.File]::ReadAllText($shipCatalogPath)
    [IO.File]::WriteAllText(
        $shipCatalogPath,
        $shipCatalogText.Replace(
            "#include `"schema.lua`"`r`n#include `"advanced_strike_craft.lua`"`r`n#include `"interceptor_projectiles.lua`"`r`n#include `"battlecruiser.lua`"",
            "#include `"advanced_strike_craft.lua`"`r`n#include `"interceptor_projectiles.lua`"`r`n#include `"battlecruiser.lua`"`r`n#include `"schema.lua`""
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

    $strikeCraftPath = Join-Path $fixtureMod "script\data\ships\advanced_strike_craft.lua"
    $strikeCraftText = [IO.File]::ReadAllText($strikeCraftPath)
    [IO.File]::WriteAllText(
        $strikeCraftPath,
        $strikeCraftText.Replace('playerConfigurable = false', 'playerConfigurable = true'),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidStrikeCraft = Invoke-Checker
    Assert-True ($invalidStrikeCraft.ExitCode -eq 1) "rejects a player-configurable strike craft"
    Assert-True ($invalidStrikeCraft.Output -match "fixed, AI-controlled") "reports the fixed strike-craft contract"
    [IO.File]::WriteAllText(
        $strikeCraftPath,
        $strikeCraftText,
        (New-Object Text.UTF8Encoding($false))
    )

    $guidedRuntimePath = Join-Path $fixtureMod "script\weapon\server\guided\runtime.lua"
    $guidedRuntimeText = [IO.File]::ReadAllText($guidedRuntimePath)
    [IO.File]::WriteAllText(
        $guidedRuntimePath,
        $guidedRuntimeText.Replace(
            'function server.guidedProjectileDestroyIfDeadAt(index)',
            'function server.guidedProjectileIgnoreDestroyedAt(index)'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidDestroyedMissile = Invoke-Checker
    Assert-True ($invalidDestroyedMissile.ExitCode -eq 1) "rejects guided projectiles that ignore zero hull"
    Assert-True ($invalidDestroyedMissile.Output -match "stop tracking, explode") "reports the destroyed interceptor lifecycle contract"
    [IO.File]::WriteAllText(
        $guidedRuntimePath,
        $guidedRuntimeText,
        (New-Object Text.UTF8Encoding($false))
    )

    [IO.File]::WriteAllText(
        $entryPath,
        $entryText.Replace(
            'server.weaponRuntimeDeactivate()',
            '-- destroyed controls were not deactivated'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidDestroyedShip = Invoke-Checker
    Assert-True ($invalidDestroyedShip.ExitCode -eq 1) "rejects destroyed ships that keep their weapon runtime active"
    Assert-True ($invalidDestroyedShip.Output -match "retaining client UI") "reports the destroyed ship control boundary"
    [IO.File]::WriteAllText(
        $entryPath,
        $entryText,
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

    [IO.File]::WriteAllText(
        $configUiPath,
        $configUiText.Replace(
            'local function _drawFooter(configuration)',
            'local function _drawFooterBroken(configuration)'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidConfigFooter = Invoke-Checker
    Assert-True ($invalidConfigFooter.ExitCode -eq 1) "rejects configuration UI without shared footer actions"
    Assert-True ($invalidConfigFooter.Output -match "shared footer actions") "reports the configuration footer contract"
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

    $tachyonPath = Join-Path $fixtureMod "script\data\weapons\x\tachyon_lance.lua"
    $tachyonText = [IO.File]::ReadAllText($tachyonPath)
    [IO.File]::WriteAllText(
        $tachyonPath,
        $tachyonText.Replace('damageMin = 780', 'damageMin = 781'),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidOfficialDamage = Invoke-Checker
    Assert-True ($invalidOfficialDamage.ExitCode -eq 1) "rejects a non-official Stellaris damage value"
    Assert-True ($invalidOfficialDamage.Output -match "tachyonLance.*damageMin") "reports the official Stellaris damage contract"
    [IO.File]::WriteAllText($tachyonPath, $tachyonText, (New-Object Text.UTF8Encoding($false)))

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
    Assert-True ($invalidSnapshot.Output -match "validated 20 Hz reacquirable input snapshot") "reports the control snapshot contract"
    [IO.File]::WriteAllText($snapshotPath, $snapshotText, (New-Object Text.UTF8Encoding($false)))

    [IO.File]::WriteAllText(
        $snapshotPath,
        $snapshotText.Replace(
            'local configuredBody = math.floor(client.shipContextGetBody() or 0)',
            'local configuredBody = math.floor((client.shipControlSnapshot or {}).shipBody or 0)'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidSnapshotReacquire = Invoke-Checker
    Assert-True ($invalidSnapshotReacquire.ExitCode -eq 1) "rejects control snapshots that cannot reacquire a newly entered ship"
    Assert-True ($invalidSnapshotReacquire.Output -match "reacquirable input snapshot") "reports the control snapshot reacquisition contract"
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

    [IO.File]::WriteAllText(
        $runtimeStatePath,
        $runtimeStateText.Replace(
            'server.shipSlotLoadoutResolveShipDefinition(requestedShipType)',
            'shipDefinitionGet(requestedShipType)'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidActiveFrameSync = Invoke-Checker
    Assert-True ($invalidActiveFrameSync.ExitCode -eq 1) "rejects Q-toggle normalization against the default frame"
    Assert-True ($invalidActiveFrameSync.Output -match "normalize against the active ship definition") "reports the active frame Q-toggle contract"
    [IO.File]::WriteAllText(
        $runtimeStatePath,
        $runtimeStateText,
        (New-Object Text.UTF8Encoding($false))
    )

    [IO.File]::WriteAllText(
        $runtimeStatePath,
        $runtimeStateText.Replace(
            'local activeGroups = (definition or {}).weaponGroups or {}',
            'local activeGroups = {}'
        ),
        (New-Object Text.UTF8Encoding($false))
    )
    $invalidResolvedGroups = Invoke-Checker
    Assert-True ($invalidResolvedGroups.ExitCode -eq 1) "rejects Q-toggle normalization that ignores resolved weapon groups"
    Assert-True ($invalidResolvedGroups.Output -match "normalize against the active ship definition") "reports the resolved weapon group contract"
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
