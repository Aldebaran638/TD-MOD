---@diagnostic disable: undefined-global

shipTypeRegistryData = shipTypeRegistryData or {}

-- 飞船类型定义：enigmaticCruiser
-- 说明：这里是“类型定义层”，用于注册到 Registry 的 definitions 区域。
shipTypeRegistryData.enigmaticCruiser = {
    shipType = "enigmaticCruiser",
    maxShieldHP = 5000,
    maxArmorHP = 3000,
    maxBodyHP = 2000,
    shieldRadius = 7,
    xSlotCount = 2,
    fx = {
        shieldHit = {
            ringParticleRadius = 0.1,
            ringRadiusStep = 1.0,
            ringRoundCount = 3,
            roundTime = 0.14,
            centerSpawnRadius = 0.5,
            centerSpawnCount = 20,
            baseParticleCount = 18,
        },
    },
    xSlots = {
        {
            weaponType = "tachyonLance",
            firePosOffset = { x = 0, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
        {
            weaponType = "tachyonLance",
            firePosOffset = { x = 0, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
        
    },
}
