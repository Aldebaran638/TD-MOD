---@diagnostic disable: undefined-global

shipTypeRegistryData = shipTypeRegistryData or {}

shipTypeRegistryData.riddle_escort = {
    shipType = "riddle_escort",
    maxShieldHP = 2800,
    maxArmorHP = 1600,
    maxBodyHP = 1000,
    shieldRadius = 7,
    regen = {
        tickInterval = 0.1,
        shieldPerSecond = 70.0,
        armorPerSecond = 50.0,
        bodyPerSecond = 10.0,
        shieldNoDamageDelay = 2.0,
        armorNoDamageDelay = 4.0,
        bodyNoDamageDelay = 6.0,
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
    sSlots = {
        {
            weaponType = "gammaLaser",
            firePosOffset = { x = 2.2, y = 0.6, z = -4.1 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "gammaLaser",
            firePosOffset = { x = -2.2, y = 0.6, z = -4.1 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "gammaLaser",
            firePosOffset = { x = 2.2, y = -0.6, z = -4.1 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "gammaLaser",
            firePosOffset = { x = -2.2, y = -0.6, z = -4.1 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            aimMode = "forwardConvergeByRange",
        },
    },
    pSlots = {
        {
            weaponType = "naniteFlakBattery",
            groupIndex = 1,
            firePosOffset = { x = 3.0, y = 1.0, z = -3.2 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 0.2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "naniteFlakBattery",
            groupIndex = 1,
            firePosOffset = { x = -3.0, y = 1.0, z = -3.2 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 0.2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "naniteFlakBattery",
            groupIndex = 2,
            firePosOffset = { x = 3.0, y = -1.0, z = -3.2 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 0.2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "naniteFlakBattery",
            groupIndex = 2,
            firePosOffset = { x = -3.0, y = -1.0, z = -3.2 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 0.2,
            aimMode = "forwardConvergeByRange",
        },
    },
    gSlots = {
        {
            weaponType = "devastatorTorpedoes",
            firePosOffset = { x = 0.0, y = 0.0, z = -3 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
        {
            weaponType = "devastatorTorpedoes",
            firePosOffset = { x = 0, y = 0.0, z = -3 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
        {
            weaponType = "devastatorTorpedoes",
            firePosOffset = { x = 0 , y = 0.0, z = -3 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
    },
}
