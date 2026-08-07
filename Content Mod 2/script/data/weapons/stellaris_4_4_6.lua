---@diagnostic disable: undefined-global

-- Mechanical ship weapons from Stellaris Pegasus 4.4.6. Existing hand-tuned
-- definitions win so their Teardown cooldowns and controller behavior stay stable.

local _sizes = {
    S = {
        id = "small", official = "SMALL", zh = "小型", en = "Small",
        laserRange = 280.0, kineticRange = 320.0, plasmaRange = 240.0,
        disruptorRange = 210.0, autocannonRange = 150.0,
        laserCooldown = 0.85, mountLaser = "mLaser", mountEnergy = "mEnergy",
        mountKinetic = "mKinetic", mountAutocannon = "mAutocannon",
    },
    M = {
        id = "medium", official = "MEDIUM", zh = "中型", en = "Medium",
        laserRange = 390.0, kineticRange = 430.0, plasmaRange = 330.0,
        disruptorRange = 340.0, autocannonRange = 180.0,
        laserCooldown = 1.10, mountLaser = "mLaser", mountEnergy = "mEnergy",
        mountKinetic = "mKinetic", mountAutocannon = "mAutocannon",
    },
    L = {
        id = "large", official = "LARGE", zh = "大型", en = "Large",
        laserRange = 560.0, kineticRange = 610.0, plasmaRange = 430.0,
        autocannonRange = 220.0,
        laserCooldown = 1.45, mountLaser = "lLaser", mountEnergy = "lEnergy",
        mountKinetic = "lKinetic", mountAutocannon = "lAutocannon",
    },
}

local _sizeOrder = { "S", "M", "L" }

local function _icon(name)
    return "MOD/gfx/ui/weapon_icons/" .. tostring(name) .. ".png"
end

local function _defineRay(definition)
    if weaponData[definition.weaponType] == nil then weaponDefineRay(definition) end
end

local function _defineProjectile(definition)
    if weaponData[definition.weaponType] == nil then weaponDefineProjectile(definition) end
end

local function _defineGuided(definition)
    if weaponData[definition.weaponType] == nil then weaponDefineGuided(definition) end
end

local function _defineCraft(definition)
    if weaponData[definition.weaponType] == nil then weaponDefineStrikeCraft(definition) end
end

local function _sizedId(size, suffix, explicitIds)
    return tostring((explicitIds or {})[size] or (_sizes[size].id .. suffix))
end

local _laserTiers = {
    {
        suffix = "RedLaser", component = "RED_LASER", zh = "红色激光", en = "Red Laser",
        icon = "laser_1", fx = "redBeam",
        power = { S = 5, M = 13, L = 30 },
        damage = { S = { 6, 16 }, M = { 15, 40 }, L = { 36, 96 } },
    },
    {
        suffix = "BlueLaser", component = "BLUE_LASER", zh = "蓝色激光", en = "Blue Laser",
        icon = "laser_2", fx = "blueBeam",
        power = { S = 7, M = 17, L = 39 },
        damage = { S = { 8, 21 }, M = { 20, 53 }, L = { 48, 126 } },
    },
    {
        suffix = "UvLaser", component = "UV_LASER", zh = "紫外激光", en = "UV Laser",
        icon = "laser_3", fx = "uvBeam",
        power = { S = 10, M = 23, L = 51 },
        damage = { S = { 10, 27 }, M = { 25, 68 }, L = { 60, 162 } },
    },
    {
        suffix = "XrayLaser", component = "XRAY_LASER", zh = "X射线激光", en = "X-Ray Laser",
        icon = "laser_4", fx = "xrayBeam",
        power = { S = 13, M = 30, L = 67 },
        damage = { S = { 13, 35 }, M = { 33, 88 }, L = { 78, 210 } },
    },
    {
        suffix = "GammaLaser", component = "GAMMA_LASER", zh = "伽马激光", en = "Gamma Laser",
        icon = "laser_5", fx = "gammaBeam",
        ids = { M = "mediumGammaLaser", L = "largeGammaLaser" },
        power = { S = 17, M = 39, L = 88 },
        damage = { S = { 17, 46 }, M = { 43, 115 }, L = { 102, 276 } },
    },
}

for tierIndex, tier in ipairs(_laserTiers) do
    for _, slot in ipairs(_sizeOrder) do
        local size, damage = _sizes[slot], tier.damage[slot]
        _defineRay({
            weaponType = _sizedId(slot, tier.suffix, tier.ids),
            displayName = size.zh .. tier.zh,
            englishName = size.en .. " " .. tier.en,
            slotTypes = { slot },
            behaviorType = "raycast",
            fxProfile = tier.fx,
            muzzleFxProfile = tier.fx == "gammaBeam"
                and (slot == "L" and "gammaLarge" or "gammaMedium") or "none",
            impactFxProfile = tier.fx == "gammaBeam"
                and (slot == "L" and "gammaLarge" or "gammaMedium") or "none",
            soundProfileId = tier.fx == "gammaBeam"
                and (slot == "L" and "largeGammaLaser" or "mediumGammaLaser") or "laser",
            iconPath = _icon(tier.icon),
            damageMin = damage[1], damageMax = damage[2], powerUse = tier.power[slot],
            cooldown = size.laserCooldown, maxRange = size.laserRange,
            shieldFix = 0.5, armorFix = 1.5, bodyFix = 1.25,
            mountProfile = size.mountLaser,
            salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.10 },
            aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
            officialComponentId = size.official .. "_" .. tier.component,
            catalogTier = tierIndex,
        })
    end
end

local _kineticTiers = {
    { suffix = "MassDriver", component = "MASS_DRIVER_1", zh = "物质投射炮", en = "Mass Driver", icon = "mass_driver_1", power = { 5, 13, 30 }, damage = { { 5, 16 }, { 13, 40 }, { 30, 96 } } },
    { suffix = "Coilgun", component = "MASS_DRIVER_2", zh = "磁轨炮", en = "Coilgun", icon = "mass_driver_2", power = { 7, 17, 39 }, damage = { { 7, 21 }, { 18, 53 }, { 42, 126 } } },
    { suffix = "Railgun", component = "MASS_DRIVER_3", zh = "轨道炮", en = "Railgun", icon = "mass_driver_3", power = { 10, 23, 51 }, damage = { { 9, 27 }, { 23, 68 }, { 54, 162 } } },
    { suffix = "AdvancedRailgun", component = "MASS_DRIVER_4", zh = "改良轨道炮", en = "Advanced Railgun", icon = "mass_driver_4", power = { 13, 30, 67 }, damage = { { 12, 35 }, { 30, 88 }, { 72, 210 } } },
    { suffix = "GaussCannon", component = "MASS_DRIVER_5", zh = "高斯炮", en = "Gauss Cannon", icon = "mass_driver_5", ids = { M = "mediumGaussCannon", L = "largeGaussCannon" }, power = { 17, 39, 88 }, damage = { { 16, 46 }, { 40, 115 }, { 96, 276 } } },
}

for tierIndex, tier in ipairs(_kineticTiers) do
    for sizeIndex, slot in ipairs(_sizeOrder) do
        local size, damage = _sizes[slot], tier.damage[sizeIndex]
        local isGauss = tier.component == "MASS_DRIVER_5"
        _defineProjectile({
            weaponType = _sizedId(slot, tier.suffix, tier.ids),
            displayName = size.zh .. tier.zh,
            englishName = size.en .. " " .. tier.en,
            slotTypes = { slot }, behaviorType = "projectile", fxProfile = "kineticProjectile",
            muzzleFxProfile = isGauss and (slot == "L" and "gaussLarge" or "gaussMedium") or "kineticArtillery",
            impactFxProfile = isGauss and (slot == "L" and "gaussLarge" or "gaussMedium") or "kineticArtillery",
            projectileFxVariant = isGauss and (slot == "L" and "gaussLarge" or "gaussMedium") or "kineticArtillery",
            soundProfileId = isGauss and (slot == "L" and "largeGaussCannon" or "mediumGaussCannon") or "kineticArtillery",
            iconPath = _icon(tier.icon),
            damageMin = damage[1], damageMax = damage[2], powerUse = tier.power[sizeIndex],
            cooldown = 0.0, maxRange = size.kineticRange,
            projectileSpeed = slot == "L" and 155.0 or (slot == "M" and 170.0 or 190.0),
            projectileRadius = 0.35,
            shieldFix = 1.5, armorFix = 0.5, bodyFix = 1.0,
            heatPerShot = 12.0, heatDissipationPerSecond = 10.0,
            overheatThreshold = 100.0, recoverThreshold = 60.0,
            mountProfile = size.mountKinetic,
            salvoProfile = { groupSize = slot == "S" and 1 or 2, sequence = slot == "S" and "sequential" or "grouped", interval = 0.10 },
            aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
            officialComponentId = size.official .. "_" .. tier.component,
            catalogTier = tierIndex,
        })
    end
end

local _plasmaTiers = {
    { suffix = "PlasmaThrower", component = "PLASMA_1", zh = "等离子喷射炮", en = "Plasma Thrower", icon = "plasma_1", color = { 1.0, 0.12, 0.03 }, power = { 13, 27, 63 }, damage = { { 12, 33 }, { 30, 83 }, { 72, 198 } } },
    { suffix = "PlasmaAccelerator", component = "PLASMA_2", zh = "等离子加速炮", en = "Plasma Accelerator", icon = "plasma_2", color = { 0.20, 0.55, 1.0 }, power = { 17, 36, 82 }, damage = { { 16, 43 }, { 40, 108 }, { 96, 258 } } },
    { suffix = "PlasmaCannon", component = "PLASMA_3", zh = "等离子加农炮", en = "Plasma Cannon", icon = "plasma_3", color = { 0.18, 1.0, 0.30 }, ids = { M = "mediumPlasmaCannon", L = "largePlasmaCannon" }, power = { 23, 47, 107 }, damage = { { 21, 56 }, { 53, 140 }, { 126, 336 } } },
}

for tierIndex, tier in ipairs(_plasmaTiers) do
    for sizeIndex, slot in ipairs(_sizeOrder) do
        local size, damage = _sizes[slot], tier.damage[sizeIndex]
        _defineProjectile({
            weaponType = _sizedId(slot, tier.suffix, tier.ids),
            displayName = size.zh .. tier.zh,
            englishName = size.en .. " " .. tier.en,
            slotTypes = { slot }, behaviorType = "projectile", fxProfile = "plasmaProjectile", fxColor = tier.color,
            muzzleFxProfile = slot == "L" and "plasmaLarge" or "plasmaMedium",
            impactFxProfile = slot == "L" and "plasmaLarge" or "plasmaMedium",
            projectileFxVariant = "plasma" .. size.en,
            soundProfileId = slot == "L" and "largePlasmaCannon" or "mediumPlasmaCannon",
            iconPath = _icon(tier.icon),
            damageMin = damage[1], damageMax = damage[2], powerUse = tier.power[sizeIndex],
            cooldown = 0.0, maxRange = size.plasmaRange, projectileSpeed = 115.0,
            projectileRadius = 0.55,
            shieldFix = 0.25, armorFix = 2.0, bodyFix = 1.5,
            heatPerShot = 12.0, heatDissipationPerSecond = 10.0,
            overheatThreshold = 100.0, recoverThreshold = 60.0,
            mountProfile = size.mountEnergy,
            salvoProfile = { groupSize = slot == "S" and 1 or 2, sequence = slot == "S" and "sequential" or "grouped", interval = 0.10 },
            aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
            officialComponentId = size.official .. "_" .. tier.component,
            catalogTier = tierIndex,
        })
    end
end

local _disruptorTiers = {
    { suffix = "Disruptor", component = "DISRUPTOR_1", zh = "裂解炮", en = "Disruptor", icon = "disruptor_1", power = { 10, 23 }, maximum = { 11.2, 28 }, penetration = 0.50 },
    { suffix = "IonDisruptor", component = "DISRUPTOR_2", zh = "离子裂解炮", en = "Ion Disruptor", icon = "disruptor_2", power = { 13, 30 }, maximum = { 14.7, 37 }, penetration = 0.60 },
    { suffix = "PhaseDisruptor", component = "DISRUPTOR_3", zh = "相位裂解炮", en = "Phase Disruptor", icon = "disruptor_3", ids = { M = "phaseDisruptor" }, power = { 17, 39 }, maximum = { 19, 48 }, penetration = 0.70 },
}

for tierIndex, tier in ipairs(_disruptorTiers) do
    for sizeIndex, slot in ipairs({ "S", "M" }) do
        local size = _sizes[slot]
        _defineRay({
            weaponType = _sizedId(slot, tier.suffix, tier.ids),
            displayName = size.zh .. tier.zh,
            englishName = size.en .. " " .. tier.en,
            slotTypes = { slot }, fxProfile = "arcBeam",
            behaviorType = "raycast",
            muzzleFxProfile = "disruptor", impactFxProfile = "disruptorImplosion",
            soundProfileId = "phaseDisruptor", iconPath = _icon(tier.icon),
            damageMin = 1, damageMax = tier.maximum[sizeIndex], powerUse = tier.power[sizeIndex],
            cooldown = slot == "M" and 1.25 or 0.90, maxRange = size.disruptorRange,
            shieldFix = 1.25, armorFix = 1.0, bodyFix = 1.0,
            shieldPenetration = tier.penetration, armorPenetration = tier.penetration,
            suppressShipExplosion = true, mountProfile = size.mountEnergy,
            salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.09 },
            aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
            officialComponentId = size.official .. "_" .. tier.component,
            catalogTier = tierIndex,
        })
    end
end

local _autocannonTiers = {
    { suffix = "Autocannon", component = "AUTOCANNON_1", zh = "机关炮", en = "Autocannon", icon = "autocannon_1", power = { 13, 28, 66 }, damage = { { 8, 16 }, { 20, 40 }, { 48, 96 } } },
    { suffix = "RipperAutocannon", component = "AUTOCANNON_2", zh = "撕裂者机关炮", en = "Ripper Autocannon", icon = "autocannon_2", power = { 17, 37, 86 }, damage = { { 10, 21 }, { 25, 53 }, { 60, 126 } } },
    { suffix = "StormfireAutocannon", component = "AUTOCANNON_3", zh = "火风暴机关炮", en = "Stormfire Autocannon", icon = "autocannon_3", ids = { M = "mediumStormfireAutocannon", L = "largeStormfireAutocannon" }, power = { 23, 49, 112 }, damage = { { 13, 27 }, { 33, 68 }, { 78, 162 } } },
    { suffix = "NaniteAutocannon", component = "AUTOCANNON_4", zh = "纳米机关炮", en = "Nanite Autocannon", icon = "autocannon_4", power = { 30, 64, 146 }, damage = { { 17, 35 }, { 43, 88 }, { 102, 210 } } },
}

for tierIndex, tier in ipairs(_autocannonTiers) do
    for sizeIndex, slot in ipairs(_sizeOrder) do
        local size, damage = _sizes[slot], tier.damage[sizeIndex]
        _defineProjectile({
            weaponType = _sizedId(slot, tier.suffix, tier.ids),
            displayName = size.zh .. tier.zh,
            englishName = size.en .. " " .. tier.en,
            slotTypes = { slot }, behaviorType = "projectile", fxProfile = "autocannonProjectile",
            muzzleFxProfile = slot == "L" and "autocannonLarge" or "autocannonMedium",
            impactFxProfile = slot == "L" and "autocannonLarge" or "autocannonMedium",
            projectileFxVariant = slot == "L" and "autocannonLarge" or "autocannonMedium",
            soundProfileId = slot == "L" and "largeStormfireAutocannon" or "mediumStormfireAutocannon",
            iconPath = _icon(tier.icon),
            damageMin = damage[1], damageMax = damage[2], powerUse = tier.power[sizeIndex],
            cooldown = 0.0, maxRange = size.autocannonRange, projectileSpeed = 240.0,
            projectileRadius = 0.35,
            shieldFix = 1.5, armorFix = 0.25, bodyFix = 1.25,
            heatPerShot = 4.0, heatDissipationPerSecond = 32.0,
            overheatThreshold = 100.0, recoverThreshold = 45.0,
            mountProfile = size.mountAutocannon,
            salvoProfile = { groupSize = slot == "S" and 1 or 2, sequence = slot == "S" and "sequential" or "grouped", interval = 0.04 },
            aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
            officialComponentId = size.official .. "_" .. tier.component,
            catalogTier = tierIndex,
        })
    end
end

_defineProjectile({
    weaponType = "kineticBattery", displayName = "动能火炮", englishName = "Kinetic Battery",
    slotTypes = { "L" }, behaviorType = "projectile", fxProfile = "kineticProjectile", muzzleFxProfile = "kineticArtillery",
    impactFxProfile = "kineticArtillery", projectileFxVariant = "kineticArtillery", soundProfileId = "kineticArtillery",
    iconPath = _icon("kinetic_artillery_1"), damageMin = 150, damageMax = 450,
    powerUse = 70.0, cooldown = 0.1, maxRange = 750.0, projectileSpeed = 450.0, projectileRadius = 0.35,
    shieldFix = 2.0, armorFix = 0.5, bodyFix = 1.0,
    mountProfile = "lKinetic", salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.18 },
    aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
    officialComponentId = "KINETIC_ARTILLERY_1", catalogTier = 1,
})

_defineRay({
    weaponType = "particleLance", displayName = "粒子光矛", englishName = "Particle Lance",
    slotTypes = { "X" }, chargeFxProfile = "tachyonLance", fxProfile = "tachyonLance", fxPalette = "particleLance",
    impactFxProfile = "tachyonLance",
    soundProfileId = "tachyonLance", iconPath = _icon("energy_lance_1"),
    damageMin = 600, damageMax = 1500, powerUse = 200.0, cooldown = 6.0, maxRange = 500.0,
    shieldFix = 0.5, armorFix = 2.0, bodyFix = 1.5,
        chargeDuration = 0.50, launchDuration = 0.20, controllerType = "chargedRay", targetingMode = "camera_limited",
    environmentExplosionSize = 4.0, physicalExplosionCount = 2,
    mountProfile = "xSpinal", salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.05 },
    aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
    officialComponentId = "ENERGY_LANCE_1", catalogTier = 1,
})

_defineRay({
    weaponType = "arcEmitter", displayName = "电弧发射器", englishName = "Arc Emitter",
    slotTypes = { "X" }, chargeFxProfile = "focusedArcEmitter", fxProfile = "arcBeam", muzzleFxProfile = "focusedArcDischarge",
    impactFxProfile = "focusedArcImpact", soundProfileId = "focusedArcEmitter",
    iconPath = _icon("arc_emitter_1"), damageMin = 1, damageMax = 1300,
    powerUse = 200.0, cooldown = 6.0, maxRange = 520.0,
    shieldFix = 1.0, armorFix = 1.0, bodyFix = 1.0,
    shieldPenetration = 1.0, armorPenetration = 1.0,
        chargeDuration = 0.50, launchDuration = 0.20, controllerType = "chargedRay", targetingMode = "camera_limited",
    environmentExplosionSize = 4.0, physicalExplosionCount = 2,
    mountProfile = "xSpinal", salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.05 },
    aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
    officialComponentId = "ARC_EMITTER_1", catalogTier = 1,
})

_defineProjectile({
    weaponType = "megaCannon", displayName = "兆级加农炮", englishName = "Mega Cannon",
    slotTypes = { "X" }, behaviorType = "projectile", fxProfile = "gigaCannonProjectile", fxColor = { 0.95, 0.25, 0.12 },
    muzzleFxProfile = "gigaMagneticLaunch", impactFxProfile = "gigaPenetration", projectileFxVariant = "megaCannon",
    soundProfileId = "gigaCannon", iconPath = _icon("mass_accelerator_1"),
    damageMin = 700, damageMax = 2000, powerUse = 200.0, cooldown = 3.5,
    maxRange = 750.0, projectileSpeed = 520.0, projectileRadius = 0.35,
    shieldFix = 1.5, armorFix = 0.75, bodyFix = 1.0,
    explosionRadius = 4.0, physicalExplosionCount = 2,
    mountProfile = "xSpinal", salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.18 },
    aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
    officialComponentId = "MASS_ACCELERATOR_1", catalogTier = 1,
})

local _missiles = {
    { id = "nuclearMissile", zh = "核导弹", en = "Nuclear Missiles", component = "MISSILE_1", icon = "missile_1", power = 5, damage = { 16, 24 }, color = { 0.25, 0.62, 1.0 }, tier = 1 },
    { id = "fusionMissile", zh = "聚变核导弹", en = "Fusion Missiles", component = "MISSILE_2", icon = "missile_2", power = 7, damage = { 21, 32 }, color = { 0.32, 0.72, 1.0 }, tier = 2 },
    { id = "antimatterMissile", zh = "反物质导弹", en = "Antimatter Missiles", component = "MISSILE_3", icon = "missile_3", power = 10, damage = { 28, 42 }, color = { 0.50, 0.82, 1.0 }, tier = 3 },
    { id = "quantumMissile", zh = "量子导弹", en = "Quantum Missiles", component = "MISSILE_4", icon = "missile_4", power = 13, damage = { 37, 55 }, color = { 0.68, 0.90, 1.0 }, tier = 4 },
    { id = "marauderMissile", zh = "掠夺者导弹", en = "Marauder Missiles", component = "MISSILE_5", icon = "missile_5", power = 17, damage = { 49, 72 }, color = { 0.92, 0.96, 1.0 }, tier = 5 },
    { id = "swarmerMissiles", zh = "蜂群导弹", en = "Swarmer Missiles", component = "SWARMER_MISSILE_1", icon = "swarmer_missile_1", power = 10, damage = { 36, 50 }, color = { 0.25, 0.72, 1.0 }, tier = 3 },
}

for _, item in ipairs(_missiles) do
    _defineGuided({
        weaponType = item.id, displayName = item.zh, englishName = item.en,
        slotTypes = { item.component == "SWARMER_MISSILE_1" and "M" or "G" },
        fxProfile = "guidedMissile", projectileFxVariant = "swarmerMissile", fxColor = item.color,
        soundProfileId = "swarmerMissile", iconPath = _icon(item.icon),
        damageMin = item.damage[1], damageMax = item.damage[2], powerUse = item.power,
        cooldown = item.component == "SWARMER_MISSILE_1" and 10.0 or 8.0,
        maxRange = item.component == "SWARMER_MISSILE_1" and 975.0 or 850.0,
        cruiseSpeed = 115.0, turnRate = 3.0, shieldFix = 1.0, armorFix = 1.0,
        shieldPenetration = 1.0, bodyFix = 1.0,
        prefabPath = "MOD/prefabs/swarmerMissile.xml",
        mountProfile = item.component == "SWARMER_MISSILE_1" and "mSwarmer" or "gRocket",
        salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.18 },
        aimControlMode = "fixed", aimLimitDeg = 360.0, aimPitchOffsetDeg = 0.0,
        officialComponentId = item.component, catalogTier = item.tier,
        family = item.component == "SWARMER_MISSILE_1" and "swarmer_missile" or "missile",
    })
end

local _torpedoes = {
    { id = "spaceTorpedoes", zh = "太空鱼雷", en = "Space Torpedoes", component = "TORPEDO_1", icon = "torpedo_1", power = 40, damage = { 100, 150 }, speed = 95.0, tier = 1 },
    { id = "armoredTorpedoes", zh = "装甲鱼雷", en = "Armored Torpedoes", component = "TORPEDO_2", icon = "torpedo_2", power = 52, damage = { 130, 195 }, speed = 105.0, tier = 2 },
}

for _, item in ipairs(_torpedoes) do
    _defineGuided({
        weaponType = item.id, displayName = item.zh, englishName = item.en,
        slotTypes = { "G" }, fxProfile = "guidedMissile", projectileFxVariant = "devastatorTorpedo",
        soundProfileId = "devastatorTorpedoes", iconPath = _icon(item.icon), fxColor = { 1.0, 0.28, 0.06 },
        damageMin = item.damage[1], damageMax = item.damage[2], powerUse = item.power,
        cooldown = 18.0, maxRange = 1200.0, cruiseSpeed = item.speed,
        shieldFix = 1.0, armorFix = 1.5, shieldPenetration = 1.0, bodyFix = 1.0,
        prefabPath = "MOD/prefabs/devastatorTorpedoes.xml",
        mountProfile = "gRocket", salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.22 },
        aimControlMode = "fixed", aimLimitDeg = 360.0, aimPitchOffsetDeg = 0.0,
        officialComponentId = item.component, catalogTier = item.tier, family = "torpedo",
    })
end

local function _defineEnergyLauncher(id, zh, en, component, iconName, power, minimum, maximum, color, tier)
    _defineProjectile({
        weaponType = id, displayName = zh, englishName = en,
        slotTypes = { "G" }, behaviorType = "projectile", fxProfile = "neutronProjectile", fxColor = color,
        muzzleFxProfile = "neutronCompression", impactFxProfile = "neutronImpact", projectileFxVariant = "neutron",
        soundProfileId = "neutronLauncher", iconPath = _icon(iconName),
        damageMin = minimum, damageMax = maximum, powerUse = power,
        cooldown = 4.5, maxRange = 1150.0, projectileSpeed = 420.0, projectileRadius = 0.35,
        shieldFix = 0.5, armorFix = 1.5, bodyFix = 1.75,
        mountProfile = "gNeutron", salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.16 },
        aimControlMode = "camera_limited", aimLimitDeg = 360.0, aimPitchOffsetDeg = 6.0,
        officialComponentId = component, catalogTier = tier,
    })
end

_defineEnergyLauncher("protonLauncher", "质子发射器", "Proton Launchers", "ENERGY_TORPEDO_1", "energy_torpedo_1", 118, 47, 101, { 1.0, 0.16, 0.04 }, 1)
_defineEnergyLauncher("zroLauncher", "泽珞发射器", "Zro Launchers", "PSIONIC_TORPEDO", "zro_launchers", 118, 130, 280, { 0.72, 0.18, 1.0 }, 3)
weaponData.zroLauncher.shieldPenetration = 0.50
weaponData.zroLauncher.armorPenetration = 0.50

for _, item in ipairs({
    { slot = "S", id = "smallPsionicDisruptor", component = "SMALL_PSIONIC_DISRUPTOR", zh = "小型灵能裂解炮", en = "Small Psionic Disruptor", power = 23, maximum = 25 },
    { slot = "M", id = "mediumPsionicDisruptor", component = "MEDIUM_PSIONIC_DISRUPTOR", zh = "中型灵能裂解炮", en = "Medium Psionic Disruptor", power = 47, maximum = 62 },
}) do
    local size = _sizes[item.slot]
    _defineRay({
        weaponType = item.id, displayName = item.zh, englishName = item.en,
        slotTypes = { item.slot }, behaviorType = "raycast", fxProfile = "psionicArcBeam",
        muzzleFxProfile = "none", impactFxProfile = "focusedArcImpact", soundProfileId = "phaseDisruptor",
        iconPath = _icon("psionic_disruptor"), damageMin = 1, damageMax = item.maximum,
        powerUse = item.power, cooldown = item.slot == "M" and 1.25 or 0.90,
        maxRange = size.disruptorRange, shieldFix = 1.25, armorFix = 1.0, bodyFix = 1.0,
        shieldPenetration = 0.80, armorPenetration = 0.80, suppressShipExplosion = true,
        mountProfile = size.mountEnergy, salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.09 },
        aimControlMode = "camera_limited", aimLimitDeg = 70.0, aimPitchOffsetDeg = 6.0,
        officialComponentId = item.component,
        catalogTier = 4,
    })
end

local _crafts = {
    { id = "scoutWing", zh = "侦察机中队", en = "Scout Wing", component = "LARGE_SCOUT_HANGAR_1", icon = "strike_craft_scout_1", power = 20, damage = { 4, 8 }, speed = 110.0, tier = 0 },
    { id = "basicStrikeCraft", zh = "基础舰载机", en = "Basic Strike Craft", component = "STRIKE_CRAFT_HANGAR_1", icon = "strike_craft_fighter_1", power = 34, damage = { 4, 10 }, speed = 115.0, tier = 1 },
    { id = "improvedStrikeCraft", zh = "改良型舰载机", en = "Improved Strike Craft", component = "STRIKE_CRAFT_HANGAR_2", icon = "strike_craft_fighter_2", power = 45, damage = { 5, 13 }, speed = 122.0, tier = 2 },
    { id = "skrandStrikeCraft", zh = "斯克兰德舰载机", en = "Skrand Strike Craft", component = "STRIKE_CRAFT_SKRAND", icon = "strike_craft_skrand", power = 73, damage = { 8, 18 }, speed = 138.0, tier = 4 },
    { id = "psionicStrikeCraft", zh = "灵能轰炸机", en = "Psionic Bombers", component = "PSIONIC_STRIKE_CRAFT", icon = "psionic_bombers", power = 73, damage = { 5, 13 }, speed = 145.0, tier = 5 },
}

for _, item in ipairs(_crafts) do
    _defineCraft({
        weaponType = item.id, displayName = item.zh, englishName = item.en,
        slotTypes = { "H" }, iconPath = _icon(item.icon), soundProfileId = "gammaStrikeCraft",
        cooldown = 20.0, prefabPath = "MOD/prefabs/gammaStrikeCraft.xml",
        spawnForwardOffset = 5.0, attackDuration = 10.0, craftLifetime = 26.0,
        returnTimeout = 10.0, cruiseSpeed = item.speed, attackSpeed = item.speed + 25.0,
        breakSpeed = item.speed + 10.0, returnSpeed = item.speed - 15.0,
        dockSpeed = 18.0, emergencySpeed = 80.0, launchSpeedFactor = 0.86,
        minimumControlFactor = 0.82, maxAcceleration = 700.0, maxDeceleration = 850.0,
        turnBlendRate = 2.70, maxAngularVelocity = 28.0, maxAngularImpulse = 5000.0,
        craftRadius = 1.60, farProbeDistance = 120.0, nearSweepLookahead = 0.42,
        emergencyDuration = 0.65, recoverRadius = 35.0, fireInterval = 0.16,
        maxRange = 280.0, damageMin = item.damage[1], damageMax = item.damage[2],
        powerUse = item.power, shieldFix = 1.0, armorFix = 1.5,
        shieldPenetration = 1.0, bodyFix = 1.0,
        collisionExplosionSize = 0.03, environmentExplosionSize = 0.3,
        beamImpactExplosionSize = 1.05, beamImpactExplosionImpulse = 0.36,
        beamImpactExplosionMinDistance = 0.6, beamLife = 0.14, beamWidth = 0.24,
        controllerType = "strikeCraft", mountProfile = "hHangar",
        salvoProfile = { groupSize = 1, sequence = "sequential", interval = 0.25 },
        aimControlMode = "fixed", aimLimitDeg = 0.0, aimPitchOffsetDeg = 0.0,
        officialComponentId = item.component, catalogTier = item.tier, family = "strike_craft",
    })
end

#include "stellaris_generated_4_4_6.lua"
