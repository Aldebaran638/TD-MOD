---@diagnostic disable: undefined-global

-- Stellaris 4.4.6: PERDITION_BEAM_TITAN. It remains a charged release weapon
-- while using its own bounded inferno impact behaviour.
weaponDefineRay({
    weaponType = "perditionBeam",
    displayName = "炼狱射线",
    englishName = "Perdition Beam",
    slotTypes = { "T" },
    fxProfile = "perditionBeam",
    soundProfileId = "perditionBeam",
    iconPath = "MOD/gfx/ui/weapon_icons/tachyonLance.png",
    damageMin = 5000,
    damageMax = 10000,
    powerUse = 500.0,
    cooldown = 3.0,
    maxRange = 1000.0,
    shieldFix = 0.75,
    armorFix = 1.5,
    bodyFix = 1.25,
    controllerType = "chargedRay",
    weaponClass = "chargedRay",
    behaviorType = "infernoRaycast",
    targetingMode = "camera_limited",
    chargeDuration = 1.50,
    launchDuration = 2.00,
    fireProfile = {
        mode = "charged_release",
        chargeDuration = 1.50,
        launchDuration = 2.00,
    },
    -- World damage is resolved by infernoRaycast; registered ships receive only
    -- the shared Stellaris damage path and are never passed to physical APIs.
    infernoPulseCoreRadius = 24.0,
    infernoPulseMaxRadius = 60.0,
    infernoPulseCoreScale = 0.33,
    infernoPulseEdgeScale = 0.05,
    infernoAftershockDelay = 0.25,
    infernoAftershockScale = 0.16,
    -- World-only impact policy. A tagged dragon is a scenery target rather
    -- than a registered ship, so it receives the stronger physical burst.
    infernoWorldExplosionCount = 5,
    infernoDragonTargetTag = "dragon",
    infernoDragonExplosionCount = 10,
    mountProfile = "tTitanic",
    salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.0 },
    aimControlMode = "camera_limited",
    aimLimitDeg = 35.0,
    aimPitchOffsetDeg = 4.0,
    officialComponentId = "PERDITION_BEAM_TITAN",
    family = "perdition_beam",
})
