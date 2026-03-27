---@diagnostic disable: undefined-global

xSlotWeaponRegistryData = xSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local tachyonLanceData = {
    weaponType = "tachyonLance",
    maxRange = 2000,
    damageMin = 780,
    damageMax = 1950,
    shieldFix = 0.5,
    armorFix = 2,
    bodyFix = 1.5,
    cooldown = 7.0,
    CD = 7.0,
    chargeDuration = 0.5,
    launchDuration = 0.2,
    randomTrajectoryAngle = 0,
}

xSlotWeaponRegistryData.tachyonLance = tachyonLanceData
weaponData.tachyonLance = tachyonLanceData
