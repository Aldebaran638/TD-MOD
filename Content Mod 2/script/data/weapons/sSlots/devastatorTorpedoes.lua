---@diagnostic disable: undefined-global

sSlotWeaponRegistryData = sSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local devastatorTorpedoesData = {
    weaponType = "devastatorTorpedoes",
    cooldown = 18.0,
    prefabPath = "MOD/prefabs/devastatorTorpedoes.xml",
    spawnForwardOffset = 2.0,
    muzzleSpeed = 8.5,
    cruiseSpeed = 28.0,
    maxSpeed = 34.0,
    acceleration = 6.8,
    lifetime = 22.0,
    maxRange = 1200.0,
    turnBlendRate = 0.85,
    turnRate = 4.2,
    turnImpulse = 120.0,
    damage = 700.0,
    armorFix = 1.0,
    bodyFix = 1.0,
}

sSlotWeaponRegistryData.devastatorTorpedoes = devastatorTorpedoesData
weaponData.devastatorTorpedoes = devastatorTorpedoesData
