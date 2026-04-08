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
    craftSpeed = 60.0,
    turnLerp = 12.0,
    turnRate = 18.0,
    turnImpulse = 420.0,
    approachDistance = 30.0,
    orbitRadius = 26.0,
    orbitEntryThreshold = 5.0,
    orbitLeaveThreshold = 12.0,
    orbitRadialGain = 0.24,
    avoidProbeDistance = 16.0,
    avoidProbeDistanceFar = 26.0,
    collisionProbeRadius = 0.2,
    collisionStartOffset = 1.2,
    recoverRadius = 14.0,

    fireInterval = 0.24,
    maxRange = 160.0,
    damageMin = 10,
    damageMax = 16,
    shieldFix = 0.5,
    armorFix = 1.5,
    bodyFix = 1.25,

    collisionExplosionSize = 0.1,
    environmentExplosionSize = 1,
    beamImpactExplosionSize = 3.5,
    beamImpactExplosionImpulse = 1.2,
    beamImpactExplosionMinDistance = 2.2,
    beamLife = 0.14,
    beamWidth = 0.24,
}

hSlotWeaponRegistryData.gammaStrikeCraft = gammaStrikeCraftData
weaponData.gammaStrikeCraft = gammaStrikeCraftData
