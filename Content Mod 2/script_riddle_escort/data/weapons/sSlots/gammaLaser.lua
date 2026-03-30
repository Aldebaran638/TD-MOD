---@diagnostic disable: undefined-global

escortSSlotWeaponRegistryData = escortSSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local gammaLaserData = {
    weaponType = "gammaLaser",
    displayName = "Gamma Lasers",
    maxRange = 450,
    damageMin = 120,
    damageMax = 180,
    shieldFix = 1.35,
    armorFix = 0.95,
    bodyFix = 1.0,
    cooldown = 0.24,
    launchDuration = 0.08,
    randomTrajectoryAngle = 0.0,
    beamColorA = { 1.0, 0.95, 0.62 },
    beamColorB = { 1.0, 0.80, 0.28 },
    fireSound = "tachyon_lance_fire_01.ogg",
    hitSound = "tachyon_lance_hit_01.ogg",
}

escortSSlotWeaponRegistryData.gammaLaser = gammaLaserData
weaponData.gammaLaser = gammaLaserData
