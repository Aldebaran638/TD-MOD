---@diagnostic disable: undefined-global

weaponData = weaponData or {}
weaponBehaviorProfiles = weaponBehaviorProfiles or {
    raycast = true,
    projectile = true,
    rocketProjectile = true,
    guidedProjectile = true,
    strikeCraft = true,
}
weaponFxProfiles = weaponFxProfiles or {
    tachyonLance = true,
    gammaBeam = true,
    energyBeam = true,
    focusedArcBeam = true,
    arcBeam = true,
    kineticProjectile = true,
    plasmaProjectile = true,
    autocannonProjectile = true,
    gigaCannonProjectile = true,
    neutronProjectile = true,
    guidedMissile = true,
    energyTorpedo = true,
    strikeCraft = true,
}

local function _copyMissing(target, defaults)
    local result = target or {}
    for key, value in pairs(defaults or {}) do
        if result[key] == nil then result[key] = value end
    end
    return result
end

local function _register(definition)
    local id = tostring(definition.weaponType or "")
    if id == "" then return end
    weaponData[id] = _copyMissing(weaponData[id] or {}, definition)
end

local function _ray(id, name, englishName, slots, damage, cooldown, range, shieldFix, armorFix, bodyFix, fx, charge)
    _register({
        weaponType = id, displayName = name, englishName = englishName, slotTypes = slots,
        behaviorType = "raycast", targetingMode = "camera_limited",
        fireProfile = {
            mode = charge and "charged" or "instant",
            chargeDuration = charge or 0.0,
            launchDuration = charge and 0.20 or 0.10,
            rayStyle = (fx == "arcBeam" or fx == "focusedArcBeam") and "arc" or "beam",
        },
        projectileProfile = { mode = "none" }, fxProfile = fx,
        damage = damage, damageMin = damage, damageMax = damage,
        cooldown = cooldown, CD = cooldown, maxRange = range,
        shieldFix = shieldFix, armorFix = armorFix, bodyFix = bodyFix,
        aimControlMode = "camera_limited", aimLimitDeg = 70.0,
        aimPitchOffsetDeg = 6.0, environmentExplosionSize = 0.35,
    })
end

local function _projectile(id, name, englishName, slots, damage, cooldown, range, speed, shieldFix, armorFix, bodyFix, fx, burst)
    _register({
        weaponType = id, displayName = name, englishName = englishName, slotTypes = slots,
        behaviorType = "projectile", targetingMode = "camera_limited",
        fireProfile = {
            mode = burst and "burst" or "single",
            burstCount = burst or 1,
            burstInterval = burst and 0.055 or 0.0,
        },
        projectileProfile = {
            mode = fx == "plasmaProjectile" and "energy" or "ballistic",
            speed = speed, radius = fx == "plasmaProjectile" and 0.55 or 0.35,
            gravityScale = 0.0,
        },
        fxProfile = fx, damage = damage, cooldown = cooldown, maxRange = range,
        projectileSpeed = speed, projectileLifetime = range / speed,
        projectileRadius = fx == "plasmaProjectile" and 0.55 or 0.35,
        projectileGravityScale = 0.0, shieldFix = shieldFix,
        armorFix = armorFix, bodyFix = bodyFix,
        explosionRadius = fx == "plasmaProjectile" and 1.4 or 0.8,
        explosionStrength = fx == "plasmaProjectile" and 0.8 or 0.35,
        aimControlMode = "camera_limited", aimLimitDeg = 70.0,
        aimPitchOffsetDeg = 6.0,
    })
end

local function _guided(id, name, englishName, slots, damage, cooldown, range, speed, shieldFix, armorFix, bodyFix, prefab, fx)
    _register({
        weaponType = id, displayName = name, englishName = englishName, slotTypes = slots,
        behaviorType = "guidedProjectile", targetingMode = "target_lock",
        fireProfile = { mode = "single" },
        projectileProfile = { mode = "guided", speed = speed }, fxProfile = fx,
        damage = damage, cooldown = cooldown, maxRange = range, prefabPath = prefab,
        spawnForwardOffset = 2.0, muzzleSpeed = math.max(7.0, speed * 0.22),
        cruiseSpeed = speed, maxSpeed = speed * 1.25,
        acceleration = speed * 0.22,
        lifetime = math.max(12.0, range / math.max(1.0, speed) * 1.4),
        turnBlendRate = 1.2, turnRate = 7.0, turnImpulse = 165.0,
        shieldFix = shieldFix, armorFix = armorFix, bodyFix = bodyFix,
    })
end

local function _rocket(id, name, englishName, slots, damage, cooldown, range, speed, shieldFix, armorFix, bodyFix, prefab, fx)
    _register({
        weaponType = id, displayName = name, englishName = englishName, slotTypes = slots,
        behaviorType = "rocketProjectile", targetingMode = "forward",
        fireProfile = { mode = "single" },
        projectileProfile = { mode = "unguided_rocket", speed = speed }, fxProfile = fx,
        damage = damage, cooldown = cooldown, maxRange = range, prefabPath = prefab,
        spawnForwardOffset = 2.0, muzzleSpeed = math.max(7.0, speed * 0.22),
        cruiseSpeed = speed, maxSpeed = speed * 1.25,
        acceleration = speed * 0.22,
        lifetime = math.max(12.0, range / math.max(1.0, speed) * 1.4),
        turnBlendRate = 0.0, turnRate = 7.0, turnImpulse = 165.0,
        shieldFix = shieldFix, armorFix = armorFix, bodyFix = bodyFix,
        aimControlMode = "fixed", forceForward = true,
    })
end

-- X
_ray("tachyonLance", "快子光矛", "Tachyon Lance", { "X" }, 2115, 6.0, 500.0, 0.5, 2.0, 1.5, "tachyonLance", 0.50)
_ray("focusedArcEmitter", "聚能电弧发射器", "Focused Arc Emitter", { "X" }, 1680, 6.0, 520.0, 0.0, 0.0, 2.3, "focusedArcBeam", 0.50)
_projectile("gigaCannon", "千兆级加农炮", "Giga Cannon", { "X" }, 2350, 3.5, 750.0, 560.0, 2.0, 0.5, 1.0, "gigaCannonProjectile")

-- L
_ray("largeGammaLaser", "伽马激光", "Large Gamma Laser", { "L" }, 185, 1.45, 560.0, 0.5, 1.5, 1.25, "gammaBeam")
_projectile("largePlasmaCannon", "等离子加农炮", "Large Plasma Cannon", { "L" }, 235, 2.0, 430.0, 115.0, 0.5, 2.0, 1.5, "plasmaProjectile")
_projectile("largeGaussCannon", "高斯炮", "Large Gauss Cannon", { "L" }, 205, 1.65, 610.0, 155.0, 1.5, 0.75, 1.0, "kineticProjectile")
_projectile("kineticArtillery", "先进动能火炮", "Kinetic Artillery", { "L" }, 200, 0.1, 750.0, 150.0, 2.0, 0.5, 1.0, "kineticProjectile")
_projectile("largeStormfireAutocannon", "火风暴机关炮", "Large Stormfire Autocannon", { "L" }, 56, 0.65, 220.0, 235.0, 1.5, 0.75, 1.0, "autocannonProjectile", 5)
weaponData.largeStormfireAutocannon.fireProfile.mode = "single"
weaponData.largeStormfireAutocannon.fireProfile.burstCount = 1
weaponData.largeStormfireAutocannon.fireProfile.burstInterval = 0.0
weaponData.largeStormfireAutocannon.cooldown = 0.0
weaponData.largeStormfireAutocannon.CD = 0.0

-- M
_ray("mediumGammaLaser", "伽马激光", "Medium Gamma Laser", { "M" }, 92, 1.1, 390.0, 0.5, 1.5, 1.25, "gammaBeam")
_projectile("mediumPlasmaCannon", "等离子加农炮", "Medium Plasma Cannon", { "M" }, 118, 1.5, 330.0, 105.0, 0.5, 2.0, 1.5, "plasmaProjectile")
_ray("phaseDisruptor", "相位裂解炮", "Phase Disruptor", { "M" }, 82, 1.25, 340.0, 0.0, 0.0, 2.0, "arcBeam")
weaponData.phaseDisruptor.suppressShipExplosion = true
_projectile("mediumGaussCannon", "高斯炮", "Medium Gauss Cannon", { "M" }, 104, 1.25, 430.0, 145.0, 1.5, 0.75, 1.0, "kineticProjectile")
_projectile("mediumStormfireAutocannon", "火风暴机关炮", "Medium Stormfire Autocannon", { "M" }, 28, 0.55, 180.0, 225.0, 1.5, 0.75, 1.0, "autocannonProjectile", 4)
weaponData.mediumStormfireAutocannon.fireProfile.mode = "single"
weaponData.mediumStormfireAutocannon.fireProfile.burstCount = 1
weaponData.mediumStormfireAutocannon.fireProfile.burstInterval = 0.0
weaponData.mediumStormfireAutocannon.cooldown = 0.0
weaponData.mediumStormfireAutocannon.CD = 0.0
_guided("swarmerMissile", "旋风导弹", "Whirlwind Missiles", { "M" }, 210, 10.0, 975.0, 43.875, 1.0, 1.2, 1.8, "MOD/prefabs/swarmerMissile.xml", "guidedMissile")

-- G
_rocket("devastatorTorpedoes", "毁灭者鱼雷", "Devastator Torpedoes", { "G" }, 700, 18.0, 1200.0, 30.8, 1.0, 1.0, 1.0, "MOD/prefabs/devastatorTorpedoes.xml", "guidedMissile")
_projectile("neutronLauncher", "中子发射器", "Neutron Launchers", { "G" }, 610, 4.5, 1150.0, 420.0, 0.5, 2.0, 1.75, "neutronProjectile")
weaponData.neutronLauncher.targetingMode = "forward"
weaponData.neutronLauncher.aimControlMode = "fixed"
weaponData.neutronLauncher.forceForward = true
weaponData.neutronLauncher.projectileProfile.mode = "energy"

-- H
_register({
    weaponType = "gammaStrikeCraft", displayName = "先进型舰载机", englishName = "Advanced Strike Craft",
    slotTypes = { "H" }, behaviorType = "strikeCraft",
    targetingMode = "target_lock", fireProfile = { mode = "launch_recover" },
    projectileProfile = { mode = "craft" }, fxProfile = "strikeCraft",
})

-- Compatibility registries retained for the mature legacy implementations.
xSlotWeaponRegistryData = xSlotWeaponRegistryData or {}
lSlotWeaponRegistryData = lSlotWeaponRegistryData or {}
hSlotWeaponRegistryData = hSlotWeaponRegistryData or {}
xSlotWeaponRegistryData.tachyonLance = weaponData.tachyonLance
xSlotWeaponRegistryData.focusedArcEmitter = weaponData.focusedArcEmitter
lSlotWeaponRegistryData.kineticArtillery = weaponData.kineticArtillery
hSlotWeaponRegistryData.gammaStrikeCraft = weaponData.gammaStrikeCraft

weaponData.tachyonLance.legacyController = "xSlot"
weaponData.focusedArcEmitter.legacyController = "xSlot"
weaponData.focusedArcEmitter.chargeDuration = weaponData.focusedArcEmitter.fireProfile.chargeDuration
weaponData.focusedArcEmitter.launchDuration = weaponData.focusedArcEmitter.fireProfile.launchDuration

-- X-slot super-weapons use Teardown's maximum physical environment explosion.
-- Registered ships continue to use the authoritative shield/armor/body damage path.
weaponData.tachyonLance.environmentExplosionSize = 4.0
weaponData.focusedArcEmitter.environmentExplosionSize = 4.0
weaponData.gigaCannon.explosionRadius = 4.0
weaponData.kineticArtillery.legacyController = "lSlot"
weaponData.swarmerMissile.legacyController = "mSlot"
weaponData.gammaStrikeCraft.legacyController = "hSlot"

-- Slot size controls compatibility; mountProfile and salvoProfile control how a
-- particular ship installs and fires the weapon.
local _runtimeProfiles = {
    tachyonLance = { "xSpinal", 1, "sequential" },
    focusedArcEmitter = { "xSpinal", 1, "sequential" },
    gigaCannon = { "xSpinal", 1, "sequential" },
    largeGammaLaser = { "lLaser", 1, "sequential" },
    largePlasmaCannon = { "lEnergy", 2, "grouped" },
    largeGaussCannon = { "lKinetic", 2, "grouped" },
    kineticArtillery = { "lKinetic", 2, "grouped" },
    largeStormfireAutocannon = { "lAutocannon", 2, "grouped" },
    mediumGammaLaser = { "mLaser", 1, "sequential" },
    mediumPlasmaCannon = { "mEnergy", 2, "grouped" },
    phaseDisruptor = { "mEnergy", 1, "sequential" },
    mediumGaussCannon = { "mKinetic", 2, "grouped" },
    mediumStormfireAutocannon = { "mAutocannon", 4, "grouped" },
    swarmerMissile = { "mSwarmer", 1, "sequential" },
    devastatorTorpedoes = { "gRocket", 1, "sequential" },
    neutronLauncher = { "gNeutron", 1, "sequential" },
    gammaStrikeCraft = { "hHangar", 1, "sequential" },
}

for weaponType, profile in pairs(_runtimeProfiles) do
    local definition = weaponData[weaponType]
    definition.mountProfile = profile[1]
    definition.salvoProfile = {
        groupSize = profile[2],
        sequence = profile[3],
    }
    definition.continuousFire = true
end

for _, weaponType in ipairs({
    "largeStormfireAutocannon",
    "mediumStormfireAutocannon",
}) do
    local definition = weaponData[weaponType]
    definition.heatPerShot = 4.0
    definition.heatDissipationPerSecond = 32.0
    definition.overheatThreshold = 100.0
    definition.recoverThreshold = 45.0
end

for _, weaponType in ipairs({
    "largePlasmaCannon",
    "mediumPlasmaCannon",
    "largeGaussCannon",
    "mediumGaussCannon",
}) do
    local definition = weaponData[weaponType]
    definition.cooldown = 0.0
    definition.CD = 0.0
    definition.heatPerShot = 12.0
    definition.heatDissipationPerSecond = 10.0
    definition.overheatThreshold = 100.0
    definition.recoverThreshold = 60.0
end

local _salvoIntervals = {
    tachyonLance = 0.05,
    focusedArcEmitter = 0.05,
    gigaCannon = 0.18,
    largeGammaLaser = 0.14,
    largePlasmaCannon = 0.10,
    largeGaussCannon = 0.10,
    kineticArtillery = 0.05,
    largeStormfireAutocannon = 0.06,
    mediumGammaLaser = 0.10,
    mediumPlasmaCannon = 0.10,
    phaseDisruptor = 0.09,
    mediumGaussCannon = 0.10,
    mediumStormfireAutocannon = 0.06,
    swarmerMissile = 0.18,
    devastatorTorpedoes = 0.20,
    neutronLauncher = 0.16,
    gammaStrikeCraft = 0.25,
}
for weaponType, interval in pairs(_salvoIntervals) do
    weaponData[weaponType].salvoProfile.interval = interval
end

for _, weaponType in ipairs({
    "gigaCannon",
    "largeGammaLaser", "largePlasmaCannon", "largeGaussCannon",
    "largeStormfireAutocannon",
    "mediumGammaLaser", "mediumPlasmaCannon", "phaseDisruptor",
    "mediumGaussCannon", "mediumStormfireAutocannon",
}) do
    weaponData[weaponType].targetingMode = "forward"
    weaponData[weaponType].aimControlMode = "forward_converge"
end

weaponData.devastatorTorpedoes.ignoreGravity = true
weaponData.devastatorTorpedoes.projectileProfile.ignoreGravity = true

local _officialMetadata = {
    tachyonLance = { "ENERGY_LANCE_2", "energy_lance" },
    focusedArcEmitter = { "ARC_EMITTER_2", "arc_emitter" },
    gigaCannon = { "MASS_ACCELERATOR_2", "mass_accelerator" },
    largeGammaLaser = { "LARGE_GAMMA_LASER", "laser" },
    largePlasmaCannon = { "LARGE_PLASMA_3", "plasma" },
    largeGaussCannon = { "LARGE_MASS_DRIVER_5", "mass_driver" },
    kineticArtillery = { "KINETIC_ARTILLERY_2", "kinetic_artillery" },
    largeStormfireAutocannon = { "LARGE_AUTOCANNON_3", "autocannon" },
    mediumGammaLaser = { "MEDIUM_GAMMA_LASER", "laser" },
    mediumPlasmaCannon = { "MEDIUM_PLASMA_3", "plasma" },
    phaseDisruptor = { "MEDIUM_DISRUPTOR_3", "disruptor" },
    mediumGaussCannon = { "MEDIUM_MASS_DRIVER_5", "mass_driver" },
    mediumStormfireAutocannon = { "MEDIUM_AUTOCANNON_3", "autocannon" },
    swarmerMissile = { "SWARMER_MISSILE_2", "swarmer_missile" },
    devastatorTorpedoes = { "TORPEDO_3", "torpedo" },
    neutronLauncher = { "ENERGY_TORPEDO_2", "energy_torpedo" },
    gammaStrikeCraft = { "STRIKE_CRAFT_HANGAR_3", "strike_craft" },
}

for weaponType, metadata in pairs(_officialMetadata) do
    local definition = weaponData[weaponType]
    definition.officialComponentId = metadata[1]
    definition.family = metadata[2]
    definition.catalogTier = "highest"
    definition.runtimeReady = true
    definition.iconPath = "MOD/gfx/ui/weapon_icons/" .. weaponType .. ".png"
    definition.officialSourceVersion = "4.2.4"
end

-- Qualitative behavior metadata from the 4.2.4 component templates.
-- CM2 intentionally does not implement Stellaris minimum-range restrictions.
weaponData.gigaCannon.officialProjectileGfx = "adv_kinetic_artillery"
weaponData.gigaCannon.officialCombatRole = "artillery"
weaponData.largePlasmaCannon.officialProjectileGfx = "plasma_cannon_l"
weaponData.largePlasmaCannon.officialCombatRole = "anti_armor"
weaponData.mediumPlasmaCannon.officialProjectileGfx = "plasma_cannon_m"
weaponData.mediumPlasmaCannon.officialCombatRole = "anti_armor"
weaponData.neutronLauncher.officialProjectileGfx = "neutron_torpedoes"
weaponData.neutronLauncher.officialCombatRole = "artillery"
weaponData.neutronLauncher.officialFiringArcDeg = 25.0
weaponData.largeStormfireAutocannon.officialProjectileGfx = "stormfire_auto_cannons_l"
weaponData.largeStormfireAutocannon.officialCombatRole = "brawler"
weaponData.mediumStormfireAutocannon.officialProjectileGfx = "stormfire_auto_cannons_m"
weaponData.mediumStormfireAutocannon.officialCombatRole = "brawler"
