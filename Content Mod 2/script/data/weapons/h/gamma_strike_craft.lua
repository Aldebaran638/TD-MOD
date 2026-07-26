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
    cruiseSpeed = 82.0,
    attackSpeed = 102.0,
    breakSpeed = 88.0,
    returnSpeed = 74.0,
    dockSpeed = 18.0,
    emergencySpeed = 30.0,
    launchSpeedFactor = 0.86,
    minimumControlFactor = 0.64,
    maxAcceleration = 310.0,
    maxDeceleration = 390.0,
    maxAngularVelocity = 20.0,
    maxAngularImpulse = 9000.0,
    craftRadius = 1.60,
    farProbeDistance = 70.0,
    nearSweepLookahead = 0.18,
    emergencyDuration = 0.70,
    recoverRadius = 14.0,

    fireInterval = 0.16,
    maxRange = 280.0,
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
