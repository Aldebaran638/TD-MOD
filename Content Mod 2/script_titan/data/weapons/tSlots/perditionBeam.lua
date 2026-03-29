---@diagnostic disable: undefined-global

tSlotWeaponRegistryData = tSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local perditionBeamData = {
    weaponType = "perditionBeam",
    displayName = "Perdition Beam",
    triggerMode = "hold_release",
    maxRange = 500,
    damageMin = 1560,
    damageMax = 3600,
    shieldFix = 0.75,
    armorFix = 1.5,
    bodyFix = 1.25,
    cooldown = 10,
    CD = 10,
    chargeDuration = 1.5,
    chargeDecayDuration = 1.35,
    launchDuration = 0.5,
    randomTrajectoryAngle = 0,
    aoeRadius = 5.0,
    aoeMinDamageFactor = 0.22,
    hitShakeDuration = 0.45,
    hitShakeAmplitude = 0.18,
    chargeFxBarrelLength = 7.0,
    chargeFxInnerLength = 2.1,
    chargeFxSideOffset = 1.15,
    chargeFxFrontOffset = 2.4,
    chargeFxVerticalSpread = 0.18,
    chargeFxOuterRadius = 1.0,
    chargeFxParticleScale = 2.6,
    chargeFxGlowScale = 2.4,
    launchFxVisualDuration = 0.72,
    launchFxCoreRadius = 0.42,
    launchFxCoreRadiusPeak = 0.82,
    launchFxShellRadius = 0.88,
    launchFxShellRadiusPeak = 1.65,
    launchFxMuzzleFlashRadius = 1.4,
    launchFxCoreStep = 1.2,
    launchFxShellStep = 1.0,
    launchFxCoreBurstPerStep = 3,
    launchFxShellBurstPerStep = 4,
}

tSlotWeaponRegistryData.perditionBeam = perditionBeamData
weaponData.perditionBeam = perditionBeamData
