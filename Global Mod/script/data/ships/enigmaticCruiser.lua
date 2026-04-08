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
    slotWeaponPools = {
        X = { "tachyonLance" },
        L = { "kineticArtillery" },
        M = { "swarmerMissile" },
        G = { "devastatorTorpedoes" },
        H = { "gammaStrikeCraft" },
    },
    defaultSlotConfigurationId = "battleline_2x2l4m",
    slotConfigurations = {
        {
            configurationId = "battleline_2x2l4m",
            label = "2X 2L 4M",
            slotGroups = {
                { slotType = "X", count = 2, mountCollection = "xSlots" },
                { slotType = "L", count = 2, mountCollection = "lSlots" },
                { slotType = "M", count = 4, mountCollection = "sSlots" },
                { slotType = "H", count = 2, mountCollection = "hSlots" },
            },
            defaultLoadout = {
                X = "tachyonLance",
                L = "kineticArtillery",
                M = "swarmerMissile",
                H = "gammaStrikeCraft",
            },
            mounts = {
                xSlots = {
                    {
                        firePosOffset = { x = 0, y = 0, z = -4 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                    {
                        firePosOffset = { x = 0, y = 0, z = -4 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                },
                lSlots = {
                    {
                        firePosOffset = { x = 6, y = 0, z = -4 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                        fireDeviationAngle = 1,
                        aimMode = "forwardConvergeByRange",
                    },
                    {
                        firePosOffset = { x = -6, y = 0, z = -4 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                        fireDeviationAngle = 1,
                        aimMode = "forwardConvergeByRange",
                    },
                },
                sSlots = {
                    {
                        firePosOffset = { x = 0.3, y = 5, z = 2 },
                        fireDirRelative = { x = 600, y = 300, z = 0 },
                    },
                    {
                        firePosOffset = { x = -0.3, y = 5, z = 2 },
                        fireDirRelative = { x = -600, y = 300, z = 0 },
                    },
                    {
                        firePosOffset = { x = 0.3, y = -5, z = 2 },
                        fireDirRelative = { x = 600, y = -300, z = 0 },
                    },
                    {
                        firePosOffset = { x = -0.3, y = -5, z = 2 },
                        fireDirRelative = { x = -600, y = -300, z = 0 },
                    },
                },
                gSlots = {},
                hSlots = {
                    {
                        firePosOffset = { x = 2.8, y = 1.2, z = -1.0 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                    {
                        firePosOffset = { x = -2.8, y = 1.2, z = -1.0 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                },
            },
        },
        {
            configurationId = "siege_2x4g2m",
            label = "2X 4G 2M",
            slotGroups = {
                { slotType = "X", count = 2, mountCollection = "xSlots" },
                { slotType = "G", count = 4, mountCollection = "gSlots" },
                { slotType = "M", count = 2, mountCollection = "sSlots" },
                { slotType = "H", count = 2, mountCollection = "hSlots" },
            },
            defaultLoadout = {
                X = "tachyonLance",
                G = "devastatorTorpedoes",
                M = "swarmerMissile",
                H = "gammaStrikeCraft",
            },
            mounts = {
                xSlots = {
                    {
                        firePosOffset = { x = 0, y = 0, z = -4 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                    {
                        firePosOffset = { x = 0, y = 0, z = -4 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                },
                sSlots = {
                    {
                        firePosOffset = { x = 0.3, y = 5, z = 2 },
                        fireDirRelative = { x = 600, y = 300, z = 0 },
                    },
                    {
                        firePosOffset = { x = -0.3, y = 5, z = 2 },
                        fireDirRelative = { x = -600, y = 300, z = 0 },
                    },
                },
                gSlots = {
                    {
                        firePosOffset = { x = 6, y = 0, z = -4 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                    {
                        firePosOffset = { x = -6, y = 0, z = -4 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                    {
                        firePosOffset = { x = 0.3, y = -5, z = 2 },
                        fireDirRelative = { x = 600, y = -300, z = 0 },
                    },
                    {
                        firePosOffset = { x = -0.3, y = -5, z = 2 },
                        fireDirRelative = { x = -600, y = -300, z = 0 },
                    },
                },
                lSlots = {},
                hSlots = {
                    {
                        firePosOffset = { x = 2.8, y = 1.2, z = -1.0 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                    {
                        firePosOffset = { x = -2.8, y = 1.2, z = -1.0 },
                        fireDirRelative = { x = 0, y = 0, z = -1 },
                    },
                },
            },
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
    lSlots = {
        {
            weaponType = "kineticArtillery",
            firePosOffset = { x = 6, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 1,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            firePosOffset = { x = -6, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 1,
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
    hSlots = {
        {
            weaponType = "gammaStrikeCraft",
            firePosOffset = { x = 2.8, y = 1.2, z = -1.0 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
        {
            weaponType = "gammaStrikeCraft",
            firePosOffset = { x = -2.8, y = 1.2, z = -1.0 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
    },
}
