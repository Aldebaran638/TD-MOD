---@diagnostic disable: undefined-global

sSlotWeaponRegistryData = sSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local swarmerMissileData = {
    weaponType = "swarmerMissile",
    cooldown = 0.6,
    prefabPath = "MOD/prefabs/swarmerMissile.xml",
    spawnForwardOffset = 1.8,
    muzzleSpeed = 7.2,
    cruiseSpeed = 29.25,
    maxSpeed = 38.25,
    acceleration = 6.21,
    lifetime = 9.0,
    maxRange = 650.0,
    turnBlendRate = 5.0,
    turnRate = 25.0,
    turnImpulse = 140.0,
    damage = 420.0,
    armorFix = 1.2,
    bodyFix = 1.8,
}

sSlotWeaponRegistryData.swarmerMissile = swarmerMissileData
weaponData.swarmerMissile = swarmerMissileData
