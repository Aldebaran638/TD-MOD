---@diagnostic disable: undefined-global

hSlotWeaponRegistryData = hSlotWeaponRegistryData or {}
weaponData = weaponData or {}
shipTypeRegistryData = shipTypeRegistryData or {}

-- Strike craft participate in the shared ship damage registry, but use a compact
-- no-regeneration durability profile rather than capital-ship defenses.
shipTypeRegistryData.gammaStrikeCraft = shipTypeRegistryData.gammaStrikeCraft or {
    shipType = "gammaStrikeCraft",
    displayName = "Gamma Strike Craft",
    maxShieldHP = 0,
    maxArmorHP = 55,
    maxBodyHP = 145,
    shieldRadius = 1.15,
    regen = {
        tickInterval = 0.1,
        shieldPerSecond = 0.0,
        armorPerSecond = 0.0,
        bodyPerSecond = 0.0,
        shieldNoDamageDelay = 999.0,
        armorNoDamageDelay = 999.0,
        bodyNoDamageDelay = 999.0,
    },
}

local gammaStrikeCraftData = {
    weaponType = "gammaStrikeCraft",
    craftShipType = "gammaStrikeCraft",
    cooldown = 20.0,
    prefabPath = "MOD/prefabs/gammaStrikeCraft.xml",
    spawnForwardOffset = 2.5,

    attackDuration = 10.0,
    craftLifetime = 26.0,
    returnTimeout = 10.0,
    craftSpeed = 56.0,
    damagedSpeedFactor = 0.68,
    dockingSpeedFactor = 0.28,
    blockedSpeedFactor = 0.22,
    turnLerp = 20.0,
    turnRate = 32.0,
    turnImpulse = 900.0,

    -- Repeated attack-run profile: line up, fire during the pass, then break
    -- away before establishing the next run.
    approachDistance = 72.0,
    attackRunStartDistance = 86.0,
    attackRunBreakDistance = 19.0,
    attackRunDuration = 2.4,
    disengageDuration = 1.15,
    disengageDistance = 58.0,
    disengageClimb = 0.28,

    -- Legacy orbit values remain available for compatibility/debug displays,
    -- but the controller now uses attack runs instead of continuous circling.
    orbitRadius = 26.0,
    orbitEntryThreshold = 5.0,
    orbitLeaveThreshold = 12.0,
    orbitRadialGain = 0.32,

    -- Avoidance runs on demand and caches a chosen escape direction.
    avoidProbeDistance = 24.0,
    avoidProbeDistanceFar = 40.0,
    avoidProbeRadius = 0.82,
    avoidCheckInterval = 0.10,
    avoidHoldDuration = 0.42,
    collisionProbeRadius = 0.9,
    collisionStartOffset = 0.0,

    -- Two-stage recovery: reach a point outside the hangar, then dock slowly.
    recoveryApproachDistance = 24.0,
    recoveryApproachRadius = 7.0,
    recoverRadius = 3.2,

    damagedThreshold = 0.60,
    disabledThreshold = 0.24,
    healthCheckInterval = 0.10,
    muzzleForwardOffset = 1.80,
    fireAlignmentDot = 0.90,
    beamSelfSafeDistance = 3.0,

    fireInterval = 0.24,
    maxRange = 160.0,
    damageMin = 45,
    damageMax = 75,
    shieldFix = 0.5,
    armorFix = 1.5,
    bodyFix = 1.25,

    collisionExplosionSize = 0.03,
    environmentExplosionSize = 0.3,
    beamImpactExplosionSize = 1.05,
    beamImpactExplosionImpulse = 0.36,
    beamImpactExplosionMinDistance = 0.6,
    beamLife = 0.14,
    beamWidth = 0.24,
}

hSlotWeaponRegistryData.gammaStrikeCraft = gammaStrikeCraftData
weaponData.gammaStrikeCraft = gammaStrikeCraftData
