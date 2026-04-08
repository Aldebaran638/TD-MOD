---@diagnostic disable: undefined-global

hSlotWeaponRegistryData = hSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local gammaStrikeCraftData = {
    weaponType = "gammaStrikeCraft",
    cooldown = 20.0,

    craftLifetime = 26.0,
    returnTimeout = 6.0,
    craftSpeed = 34.0,
    turnLerp = 4.0,
    approachDistance = 14.0,
    orbitRadius = 10.0,
    orbitEntryThreshold = 11.5,
    orbitLeaveThreshold = 18.0,
    avoidProbeDistance = 7.5,

    fireInterval = 0.22,
    maxRange = 160.0,
    damageMin = 75,
    damageMax = 120,
    shieldFix = 0.8,
    armorFix = 1.0,
    bodyFix = 1.15,

    collisionExplosionSize = 0.1,
    environmentExplosionSize = 0.1,
}

hSlotWeaponRegistryData.gammaStrikeCraft = gammaStrikeCraftData
weaponData.gammaStrikeCraft = gammaStrikeCraftData
