---@diagnostic disable: undefined-global

lSlotWeaponRegistryData = lSlotWeaponRegistryData or {}

local kineticArtilleryMaxRange = 750.0
local kineticArtilleryProjectileSpeed = 240.0

lSlotWeaponRegistryData.kineticArtillery = {
    weaponType = "kineticArtillery",
    cooldown = 0.1,
    maxRange = kineticArtilleryMaxRange,
    projectileSpeed = kineticArtilleryProjectileSpeed,
    projectileLifetime = kineticArtilleryMaxRange / kineticArtilleryProjectileSpeed,
    projectileRadius = 1.0,
    projectileGravityScale = 0.0,
    damage = 200.0,
    shieldFix = 2.0,
    armorFix = 0.5,
    bodyFix = 1.0,
    explosionRadius = 2.0,
    explosionStrength = 1.0,
    heatPerShot = 18.0,
    heatDissipationPerSecond = 14.0,
    overheatThreshold = 100.0,
    recoverThreshold = 60.0,
}
