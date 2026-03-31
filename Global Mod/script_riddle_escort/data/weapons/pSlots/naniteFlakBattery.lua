---@diagnostic disable: undefined-global

escortPSlotWeaponRegistryData = escortPSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local naniteFlakBatteryData = {
    weaponType = "naniteFlakBattery",
    displayName = "Nanite Flak Battery",
    cooldown = 0.06,
    maxRange = 80.0,
    projectileSpeed = 240.0,
    projectileLifetime = 420.0 / 240.0,
    projectileRadius = 0.18,
    projectileGravityScale = 0.0,
    damage = 22.0,
    shieldFix = 2.0,
    armorFix = 0.25,
    bodyFix = 1,
    explosionRadius = 1.2,
    explosionStrength = 1.5,
    heatPerShot = 4.0,
    heatDissipationPerSecond = 32.0,
    overheatThreshold = 100.0,
    recoverThreshold = 45.0,
    projectileColorA = { 0.42, 1.0, 0.55 },
    projectileColorB = { 0.08, 0.88, 0.22 },
    fireSound = "kinectic_artillery_fire_01.ogg",
    hitSound = "kinectic_artillery_hit_01.ogg",
}

escortPSlotWeaponRegistryData.naniteFlakBattery = naniteFlakBatteryData
weaponData.naniteFlakBattery = naniteFlakBatteryData
