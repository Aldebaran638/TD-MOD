---@diagnostic disable: undefined-global

xSlotWeaponRegistryData = xSlotWeaponRegistryData or {}

-- xSlots 武器类型定义：tachyonLance
-- 说明：这里是“武器类型层”参数，不包含具体飞船某个槽位的挂载位置/方向。
xSlotWeaponRegistryData.tachyonLance = {
    weaponType = "tachyonLance",
    maxRange = 2000,
    damageMin = 780,
    damageMax = 1950,
    shieldFix = 0.5,
    armorFix = 2,
    bodyFix = 1.5,
    cooldown = 1.5,
    chargeDuration = 0.5,
    launchDuration = 0.2,
    -- 随机弹道：实际发射方向与理论瞄准方向的最大夹角（角度制，单位：度）
    randomTrajectoryAngle = 0,
}
