---@diagnostic disable: undefined-global

escortGSlotWeaponRegistryData = escortGSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local devastatorTorpedoesData = {
    weaponType = "devastatorTorpedoes",
    displayName = "Devastator Torpedoes",
    fireInterval = 0.28,
    reloadTime = 5.0,
    prefabPath = "MOD/prefabs/swarmerMissile.xml",
    spawnForwardOffset = 1.6,
    muzzleSpeed = 22.0,
    cruiseSpeed = 48.0,
    maxSpeed = 48.0,
    acceleration = 0.0,
    lifetime = 14.0,
    maxRange = 650.0,
    damage = 420.0,
    shieldFix = 0.0,
    armorFix = 1.0,
    bodyFix = 1.0,
    environmentExplosionRadius = 4.0,
    environmentExplosionStrength = 1.0,
    targetShipTypeDamageMultiplier = {
        enigmaticCruiser = 2.0,
        titan = 5.0,
    },
    rocketColor = { 0.72, 0.25, 1.0 },
    fireSound = "missile_fire_01.ogg",
    hitSound = "distance_missile_fire_01.ogg",
}

escortGSlotWeaponRegistryData.devastatorTorpedoes = devastatorTorpedoesData
weaponData.devastatorTorpedoes = devastatorTorpedoesData
