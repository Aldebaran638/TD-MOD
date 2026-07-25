---@diagnostic disable: undefined-global

xSlotWeaponRegistryData = xSlotWeaponRegistryData or {}
weaponData = weaponData or {}

local tachyonLanceData = {
    weaponType = "tachyonLance",
    maxRange = 500,
    damageMin = 1580,
    damageMax = 2650,
    shieldFix = 0.5,
    armorFix = 2,
    bodyFix = 1.5,
    cooldown = 6.0,
    CD = 6.0,
    chargeDuration = 0.5,
    launchDuration = 0.2,
    randomTrajectoryAngle = 0,
    aimControlMode = "camera_limited",
    aimLimitDeg = 70.0,
    aimPitchOffsetDeg = 6.0,
}

xSlotWeaponRegistryData.tachyonLance = tachyonLanceData
weaponData.tachyonLance = tachyonLanceData
