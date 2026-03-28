---@diagnostic disable: undefined-global

sSlotWeaponRegistryData = sSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local swarmerMissileData = {
    weaponType = "swarmerMissile",
    cooldown = 10.0,
    prefabPath = "MOD/prefabs/swarmerMissile.xml",
    spawnForwardOffset = 1.8,
    muzzleSpeed = 10.8,
    cruiseSpeed = 43.875,
    maxSpeed = 57.375,
    acceleration = 9.315,
    lifetime = 18.0,
    maxRange = 975.0,
    turnBlendRate = 1.95,
    turnRate = 10.5,
    turnImpulse = 210.0,
    damage = 210.0,
    armorFix = 1.2,
    bodyFix = 1.8,
}

sSlotWeaponRegistryData.swarmerMissile = swarmerMissileData
weaponData.swarmerMissile = swarmerMissileData
