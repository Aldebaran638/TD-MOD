---@diagnostic disable: undefined-global

sSlotWeaponRegistryData = sSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local swarmerMissileData = {
    weaponType = "swarmerMissile",
    cooldown = 0.6,
    prefabPath = "MOD/prefabs/swarmerMissile.xml",
    spawnForwardOffset = 1.8,
    muzzleSpeed = 4.8,
    cruiseSpeed = 19.5,
    maxSpeed = 25.5,
    acceleration = 27.0,
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
