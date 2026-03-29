---@diagnostic disable: undefined-global

shipTypeRegistryData = shipTypeRegistryData or {}

shipTypeRegistryData.titan = {
    shipType = "titan",
    maxShieldHP = 10000,
    maxArmorHP = 6000,
    maxBodyHP = 4000,
    shieldRadius = 10,
    tSlotCount = 2,
    regen = {
        tickInterval = 0.1,
        shieldPerSecond = 140.0,
        armorPerSecond = 100.0,
        bodyPerSecond = 20.0,
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
    tSlots = {
        {
            weaponType = "perditionBeam",
            firePosOffset = { x = 0, y = 0, z = -3.5 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
        {
            weaponType = "perditionBeam",
            firePosOffset = { x = 0, y = 0, z = -3.5 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
    },
    lSlots = {
        {
            weaponType = "kineticArtillery",
            groupIndex = 1,
            firePosOffset = { x = 6, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            groupIndex = 1,
            firePosOffset = { x = -6, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            groupIndex = 1,
            firePosOffset = { x = 0, y = 6, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            groupIndex = 1,
            firePosOffset = { x = 0, y = -6, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            groupIndex = 2,
            firePosOffset = { x = 6, y = 0, z = -1 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            groupIndex = 2,
            firePosOffset = { x = -6, y = 0, z = -1 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            groupIndex = 2,
            firePosOffset = { x = 0, y = 6, z = -1 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 2,
            aimMode = "forwardConvergeByRange",
        },
        {
            weaponType = "kineticArtillery",
            groupIndex = 2,
            firePosOffset = { x = 0, y = -6, z = -1 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
            fireDeviationAngle = 2,
            aimMode = "forwardConvergeByRange",
        },
    },
    mSlots = {
        {
            weaponType = "swarmerMissile",
            firePosOffset = { x = 0, y = 5, z = 3 },
            fireDirRelative = { x = 0, y = 600, z = 600 },
        },
        {
            weaponType = "swarmerMissile",
            firePosOffset = { x = 0, y = -5, z = 3 },
            fireDirRelative = { x = 0, y = 600, z = 600 },
        },
        {
            weaponType = "swarmerMissile",
            firePosOffset = { x = 5, y = 0, z = 3 },
            fireDirRelative = { x = 600, y = 0, z = 600 },
        },
        {
            weaponType = "swarmerMissile",
            firePosOffset = { x = -5, y = 0, z = 3 },
            fireDirRelative = { x = -600, y = 0, z = 600 },
        },
    },
}
