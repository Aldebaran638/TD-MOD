---@diagnostic disable: undefined-global

weaponData = weaponData or {}
weaponBehaviorProfiles = weaponBehaviorProfiles or {
    raycast = true,
    infernoRaycast = true,
    projectile = true,
    rocketProjectile = true,
    guidedProjectile = true,
    strikeCraft = true,
}
weaponFxProfiles = weaponFxProfiles or {
    tachyonLance = true,
    perditionBeam = true,
    gammaBeam = true,
    redBeam = true,
    blueBeam = true,
    uvBeam = true,
    xrayBeam = true,
    energyBeam = true,
    focusedArcBeam = true,
    arcBeam = true,
    psionicArcBeam = true,
    kineticProjectile = true,
    plasmaProjectile = true,
    autocannonProjectile = true,
    gigaCannonProjectile = true,
    neutronProjectile = true,
    guidedMissile = true,
    energyTorpedo = true,
    strikeCraft = true,
}
weaponMuzzleFxProfiles = weaponMuzzleFxProfiles or {
    none = true,
    gammaLarge = true,
    gammaMedium = true,
    disruptor = true,
    focusedArcDischarge = true,
    gaussLarge = true,
    gaussMedium = true,
    kineticArtillery = true,
    autocannonLarge = true,
    autocannonMedium = true,
    plasmaLarge = true,
    plasmaMedium = true,
    gigaMagneticLaunch = true,
    neutronCompression = true,
    swarmerLaunch = true,
    torpedoLaunch = true,
}
weaponChargeFxProfiles = weaponChargeFxProfiles or {
    none = true,
    tachyonLance = true,
    focusedArcEmitter = true,
    perditionBeam = true,
}
weaponImpactFxProfiles = weaponImpactFxProfiles or {
    none = true,
    kineticArtillery = true,
    gaussLarge = true,
    gaussMedium = true,
    autocannonLarge = true,
    autocannonMedium = true,
    plasmaLarge = true,
    plasmaMedium = true,
    gigaPenetration = true,
    neutronImpact = true,
    gammaLarge = true,
    gammaMedium = true,
    disruptorImplosion = true,
    tachyonLance = true,
    focusedArcImpact = true,
    perditionImpact = true,
}
weaponSoundProfiles = weaponSoundProfiles or {
    none = true,
    laser = true,
    largeGammaLaser = true,
    mediumGammaLaser = true,
    tachyonLance = true,
    focusedArcEmitter = true,
    phaseDisruptor = true,
    perditionBeam = true,
    gammaStrikeCraft = true,
    largePlasmaCannon = true,
    mediumPlasmaCannon = true,
    largeGaussCannon = true,
    mediumGaussCannon = true,
    kineticArtillery = true,
    gigaCannon = true,
    largeStormfireAutocannon = true,
    mediumStormfireAutocannon = true,
    swarmerMissile = true,
    devastatorTorpedoes = true,
    neutronLauncher = true,
}

local function _fillMissing(target, defaults)
    for key, value in pairs(defaults or {}) do
        if target[key] == nil then target[key] = value end
    end
end

local function _defaultShieldImpactStrength(definition)
    local damage = tonumber(definition.damage)
    if damage == nil then
        local minimum = tonumber(definition.damageMin) or 0.0
        local maximum = tonumber(definition.damageMax) or minimum
        damage = (minimum + maximum) * 0.5
    end

    local effectiveDamage = math.max(
        0.0,
        damage * math.max(0.0, tonumber(definition.shieldFix) or 1.0)
    )
    if effectiveDamage <= 0.0 then return 0 end
    if effectiveDamage <= 50.0 then return 1 end

    local doubledSteps = math.ceil(
        math.log(effectiveDamage / 50.0) / math.log(2.0)
    )
    return math.max(1, math.min(7, 1 + doubledSteps))
end

local function _finish(definition)
    local id = tostring((definition or {}).weaponType or "")
    if id == "" then error("weapon definition is missing weaponType") end
    if weaponData[id] ~= nil then error("duplicate weapon definition " .. id) end
    _fillMissing(definition, {
        catalogTier = "highest",
        runtimeReady = true,
        iconPath = "MOD/gfx/ui/weapon_icons/" .. id .. ".png",
        officialSourceVersion = "4.4.6",
        continuousFire = true,
        shieldPenetration = 0.0,
        armorPenetration = 0.0,
        powerUse = 0.0,
    })
    if definition.requiresTargetLock == nil then
        definition.requiresTargetLock = tostring(definition.targetingMode or "")
            == "target_lock"
    else
        definition.requiresTargetLock = definition.requiresTargetLock == true
    end
    definition.salvoProfile = definition.salvoProfile or {
        groupSize = 1,
        sequence = "sequential",
        interval = 0.0,
    }
    definition.shieldImpactStrength = math.max(
        0,
        math.min(
            7,
            math.floor(
                tonumber(definition.shieldImpactStrength)
                    or _defaultShieldImpactStrength(definition)
            )
        )
    )
    weaponData[id] = definition
    return definition
end

function weaponDefineRay(definition)
    local chargeDuration = math.max(0.0, tonumber(definition.chargeDuration) or 0.0)
    _fillMissing(definition, {
        behaviorType = "raycast",
        targetingMode = "camera_limited",
        projectileProfile = { mode = "none" },
        environmentExplosionSize = 0.35,
    })
    if tostring(definition.controllerType or "") == "chargedRay"
        and definition.muzzleLightProfile == nil then
        definition.muzzleLightProfile = "tachyon"
    end
    definition.fireProfile = definition.fireProfile or {
        mode = chargeDuration > 0.0 and "charged_release" or "instant",
        chargeDuration = chargeDuration,
        launchDuration = tonumber(definition.launchDuration)
            or (chargeDuration > 0.0 and 0.20 or 0.10),
        rayStyle = (definition.fxProfile == "arcBeam"
            or definition.fxProfile == "focusedArcBeam"
            or definition.fxProfile == "psionicArcBeam") and "arc" or "beam",
    }
    local isChargedRay = tostring(definition.controllerType or "") == "chargedRay"
    local isProfiledRay = tostring(definition.behaviorType or "") == "raycast"
        and tostring(definition.fxProfile or "") ~= ""
    if isChargedRay or isProfiledRay then
        local chargeFxProfile = tostring(definition.chargeFxProfile or "")
        local soundProfileId = tostring(definition.soundProfileId or "")
        local beamFxProfile = tostring(definition.fxProfile or "")
        local muzzleFxProfile = tostring(definition.muzzleFxProfile or "")
        local impactFxProfile = tostring(definition.impactFxProfile or "")
        if isChargedRay and (chargeFxProfile == "" or not weaponChargeFxProfiles[chargeFxProfile]) then
            error("charged ray " .. tostring(definition.weaponType) .. " has invalid chargeFxProfile")
        end
        if soundProfileId == "" or not weaponSoundProfiles[soundProfileId] then
            error("ray " .. tostring(definition.weaponType) .. " has invalid soundProfileId")
        end
        if beamFxProfile == "" or not weaponFxProfiles[beamFxProfile] then
            error("ray " .. tostring(definition.weaponType) .. " has invalid fxProfile")
        end
        if not isChargedRay and (muzzleFxProfile == "" or not weaponMuzzleFxProfiles[muzzleFxProfile]) then
            error("ray " .. tostring(definition.weaponType) .. " has invalid muzzleFxProfile")
        end
        if impactFxProfile == "" or not weaponImpactFxProfiles[impactFxProfile] then
            error("ray " .. tostring(definition.weaponType) .. " has invalid impactFxProfile")
        end
    end
    definition.damageMin = definition.damageMin or definition.damage
    definition.damageMax = definition.damageMax or definition.damage
    definition.CD = definition.CD or definition.cooldown
    return _finish(definition)
end

function weaponDefineProjectile(definition)
    local speed = math.max(0.001, tonumber(definition.projectileSpeed) or 1.0)
    _fillMissing(definition, {
        behaviorType = "projectile",
        targetingMode = "camera_limited",
        fireProfile = { mode = "single", burstCount = 1, burstInterval = 0.0 },
        projectileLifetime = (tonumber(definition.maxRange) or 0.0) / speed,
    })
    local fxProfile = tostring(definition.fxProfile or "")
    local muzzleFxProfile = tostring(definition.muzzleFxProfile or "")
    local impactFxProfile = tostring(definition.impactFxProfile or "")
    local soundProfileId = tostring(definition.soundProfileId or "")
    if not weaponFxProfiles[fxProfile] then
        error("projectile " .. tostring(definition.weaponType) .. " has invalid fxProfile")
    end
    if not weaponMuzzleFxProfiles[muzzleFxProfile] then
        error("projectile " .. tostring(definition.weaponType) .. " has invalid muzzleFxProfile")
    end
    if not weaponImpactFxProfiles[impactFxProfile] then
        error("projectile " .. tostring(definition.weaponType) .. " has invalid impactFxProfile")
    end
    if not weaponSoundProfiles[soundProfileId] then
        error("projectile " .. tostring(definition.weaponType) .. " has invalid soundProfileId")
    end
    if definition.projectileSpeed == nil or definition.projectileRadius == nil then
        error("projectile " .. tostring(definition.weaponType) .. " requires projectileSpeed and projectileRadius")
    end
    definition.CD = definition.CD or definition.cooldown
    return _finish(definition)
end

function weaponDefineGuided(definition)
    _fillMissing(definition, {
        behaviorType = "guidedProjectile",
        targetingMode = "target_lock",
        fireProfile = { mode = "single" },
        destroyedExplosionSize = 0.5,
    })
    definition.projectileProfile = definition.projectileProfile or {
        mode = "guided",
        speed = definition.cruiseSpeed,
    }
    return _finish(definition)
end

function weaponDefineRocket(definition)
    _fillMissing(definition, {
        behaviorType = "rocketProjectile",
        targetingMode = "forward",
        fireProfile = { mode = "single" },
        aimControlMode = "fixed",
        forceForward = true,
        destroyedExplosionSize = 0.5,
    })
    definition.projectileProfile = definition.projectileProfile or {
        mode = "unguided_rocket",
        speed = definition.cruiseSpeed,
    }
    return _finish(definition)
end

function weaponDefineStrikeCraft(definition)
    _fillMissing(definition, {
        behaviorType = "strikeCraft",
        targetingMode = "target_lock",
        fireProfile = { mode = "launch_recover" },
        projectileProfile = { mode = "craft" },
        fxProfile = "strikeCraft",
    })
    return _finish(definition)
end
