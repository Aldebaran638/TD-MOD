---@diagnostic disable: undefined-global

hSlotWeaponRegistryData = hSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local gammaStrikeCraftData = {
    weaponType = "gammaStrikeCraft",
    cooldown = 20.0,
    prefabPath = "MOD/prefabs/gammaStrikeCraft.xml",
    spawnForwardOffset = 2.5,

    attackDuration = 10.0,
    craftLifetime = 26.0,
    returnTimeout = 10.0,
    craftSpeed = 56.0,
    turnLerp = 20.0,
    turnRate = 32.0,
    turnImpulse = 900.0,
    approachDistance = 30.0,
    orbitRadius = 26.0,
    orbitEntryThreshold = 5.0,
    orbitLeaveThreshold = 12.0,
    orbitRadialGain = 0.32,
    avoidProbeDistance = 24.0,
    avoidProbeDistanceFar = 40.0,
    collisionProbeRadius = 0.28,
    collisionStartOffset = 0.8,
    recoverRadius = 14.0,

    fireInterval = 0.24,
    maxRange = 160.0,
    damageMin = 45,
    damageMax = 75,
    shieldFix = 0.5,
    armorFix = 1.5,
    bodyFix = 1.25,

    collisionExplosionSize = 0.03,
    environmentExplosionSize = 0.3,
    beamImpactExplosionSize = 1.05,
    beamImpactExplosionImpulse = 0.36,
    beamImpactExplosionMinDistance = 0.6,
    beamLife = 0.14,
    beamWidth = 0.24,
}

hSlotWeaponRegistryData.gammaStrikeCraft = gammaStrikeCraftData
weaponData.gammaStrikeCraft = gammaStrikeCraftData
