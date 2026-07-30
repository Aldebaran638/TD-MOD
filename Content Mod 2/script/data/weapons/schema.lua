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
    })
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
    definition.fireProfile = definition.fireProfile or {
        mode = chargeDuration > 0.0 and "charged" or "instant",
        chargeDuration = chargeDuration,
        launchDuration = tonumber(definition.launchDuration)
            or (chargeDuration > 0.0 and 0.20 or 0.10),
        rayStyle = (definition.fxProfile == "arcBeam"
            or definition.fxProfile == "focusedArcBeam") and "arc" or "beam",
    }
    definition.damageMin = definition.damageMin or definition.damage
    definition.damageMax = definition.damageMax or definition.damage
    definition.CD = definition.CD or definition.cooldown
    return _finish(definition)
end

function weaponDefineProjectile(definition)
    local speed = math.max(0.001, tonumber(definition.projectileSpeed) or 1.0)
    local isPlasma = tostring(definition.fxProfile or "") == "plasmaProjectile"
    _fillMissing(definition, {
        behaviorType = "projectile",
        targetingMode = "camera_limited",
        fireProfile = { mode = "single", burstCount = 1, burstInterval = 0.0 },
        projectileLifetime = (tonumber(definition.maxRange) or 0.0) / speed,
        projectileRadius = isPlasma and 0.55 or 0.35,
        projectileGravityScale = 0.0,
        explosionRadius = isPlasma and 1.4 or 0.8,
        explosionStrength = isPlasma and 0.8 or 0.35,
    })
    definition.projectileProfile = definition.projectileProfile or {
        mode = isPlasma and "energy" or "ballistic",
        speed = speed,
        radius = isPlasma and 0.55 or 0.35,
        gravityScale = 0.0,
    }
    definition.CD = definition.CD or definition.cooldown
    return _finish(definition)
end

function weaponDefineGuided(definition)
    _fillMissing(definition, {
        behaviorType = "guidedProjectile",
        targetingMode = "target_lock",
        fireProfile = { mode = "single" },
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
