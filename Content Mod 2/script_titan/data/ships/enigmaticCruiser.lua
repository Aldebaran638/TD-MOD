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
    tSlotCount = 2,
    regen = {
        tickInterval = 0.1,        -- 固定恢复步长（秒）
        shieldPerSecond = 70.0,    -- 护盾每秒恢复
        armorPerSecond = 50.0,      -- 装甲每秒恢复
        bodyPerSecond = 10.0,       -- 船体每秒恢复
        shieldNoDamageDelay = 2.0, -- 护盾脱战恢复等待时间（秒）
        armorNoDamageDelay = 4.0,  -- 装甲脱战恢复等待时间（秒）
        bodyNoDamageDelay = 6.0,   -- 船体脱战恢复等待时间（秒）
    },
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
    tSlots = {
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
    lSlots = {
        {
            weaponType = "kineticArtillery",
            firePosOffset = { x = 6, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            firePosOffset = { x = -6, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            aimMode = "forwardConvergeByRange",
        },
    },
    sSlots = {
        {
            weaponType = "swarmerMissile",
            firePosOffset = { x = 0.3, y = 5, z = 2 },
            fireDirRelative = { x = 600, y = 300, z = 0 },
        },
        {
            weaponType = "swarmerMissile",
            firePosOffset = { x = -0.3, y = 5, z = 2 },
            fireDirRelative = { x = -600, y = 300, z = 0 },
        },
        {
            weaponType = "swarmerMissile",
            firePosOffset = { x = 0.3, y = -5, z = 2 },
            fireDirRelative = { x = 600, y = -300, z = 0 },
        },
        {
            weaponType = "swarmerMissile",
            firePosOffset = { x = -0.3, y = -5, z = 2 },
            fireDirRelative = { x = -600, y = -300, z = 0 },
        },
    },
}
