---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.hSlotV2Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function server.hSlotV2Normalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(value, 1.0 / length)
end

function server.hSlotV2SetDebugReason(slotIndex, reason, craft)
    local debugState = server.hSlotDebugState or {}
    if debugState.enabled == false then return end
    local bodyId = craft ~= nil and math.floor(craft.bodyId or 0) or 0
    local stateName = craft ~= nil and tostring(craft.state or "nil") or "nil"
    local life = craft ~= nil and (tonumber(craft.lifeRemain) or 0.0) or 0.0
    local returnRemain = craft ~= nil and (tonumber(craft.returnRemain) or 0.0) or 0.0
    debugState.lastReason = string.format(
        "slot=%d reason=%s body=%d state=%s life=%.2f return=%.2f",
        math.floor(slotIndex or 0), tostring(reason or "unknown"), bodyId,
        stateName, life, returnRemain
    )
    server.hSlotDebugState = debugState
end

function server.hSlotV2SetDebugStage(stage)
    local debugState = server.hSlotDebugState or {}
    debugState.stage = tostring(stage or "unknown")
    server.hSlotDebugState = debugState
end

function server.hSlotV2SetCollisionDebug(hitBody, hitDistance)
    local debugState = server.hSlotDebugState or {}
    debugState.lastCollisionBody = math.floor(hitBody or 0)
    debugState.lastCollisionDist = tonumber(hitDistance) or -1.0
    server.hSlotDebugState = debugState
end

function server.hSlotV2BumpCounter(shipBody, name)
    local ownerBody = math.floor(shipBody or 0)
    if ownerBody <= 0 then return end
    local key = "StellarisShips/debug/hslot/byShip/" .. tostring(ownerBody)
        .. "/counters/" .. tostring(name or "unknown")
    local value = (GetInt(key) or 0) + 1
    if value > 1000000000 then value = 1 end
    SetInt(key, value)
end

function server.hSlotV2GetBodyCenter(bodyId)
    if bodyId == nil or bodyId == 0 or not IsHandleValid(bodyId) then
        return nil
    end
    local bodyTransform = GetBodyTransform(bodyId)
    return TransformToParentPoint(bodyTransform, GetBodyCenterOfMass(bodyId))
end

function server.hSlotV2ResolveConfig(baseConfig)
    local config = baseConfig or {}
    if config.hSlotV2Resolved then return config end

    local weaponType = tostring(config.weaponType or "gammaStrikeCraft")
    local source = (hSlotWeaponRegistryData or {})[weaponType]
        or (hSlotWeaponRegistryData or {}).gammaStrikeCraft
        or {}
    local function number(name, fallback)
        return tonumber(source[name]) or tonumber(config[name]) or fallback
    end

    config.weaponType = weaponType
    config.craftShipType = tostring(source.craftShipType or "gammaStrikeCraft")
    config.craftLifetime = number("craftLifetime", 24.0)
    config.returnTimeout = number("returnTimeout", 6.0)
    config.craftSpeed = number("craftSpeed", 30.0)
    config.damagedSpeedFactor = number("damagedSpeedFactor", 0.68)
    config.dockingSpeedFactor = number("dockingSpeedFactor", 0.28)
    config.blockedSpeedFactor = number("blockedSpeedFactor", 0.22)
    config.turnLerp = number("turnLerp", 4.0)
    config.turnRate = number("turnRate", 0.0)
    config.turnImpulse = number("turnImpulse", 0.0)
    config.attackDuration = number("attackDuration", 10.0)
    config.attackRunStartDistance = number("attackRunStartDistance", 80.0)
    config.attackRunBreakDistance = number("attackRunBreakDistance", 18.0)
    config.attackRunDuration = number("attackRunDuration", 2.2)
    config.disengageDuration = number("disengageDuration", 1.1)
    config.disengageDistance = number("disengageDistance", 55.0)
    config.disengageClimb = number("disengageClimb", 0.25)
    config.avoidProbeDistance = number("avoidProbeDistance", 18.0)
    config.avoidProbeDistanceFar = number("avoidProbeDistanceFar", 30.0)
    config.avoidProbeRadius = number("avoidProbeRadius", 0.8)
    config.avoidCheckInterval = number("avoidCheckInterval", 0.1)
    config.avoidHoldDuration = number("avoidHoldDuration", 0.4)
    config.collisionProbeRadius = number("collisionProbeRadius", 0.9)
    config.collisionStartOffset = 0.0
    config.recoveryApproachDistance = number("recoveryApproachDistance", 24.0)
    config.recoveryApproachRadius = number("recoveryApproachRadius", 7.0)
    config.recoverRadius = number("recoverRadius", 3.2)
    config.damagedThreshold = number("damagedThreshold", 0.60)
    config.disabledThreshold = number("disabledThreshold", 0.24)
    config.healthCheckInterval = number("healthCheckInterval", 0.1)
    config.muzzleForwardOffset = number("muzzleForwardOffset", 1.2)
    config.fireInterval = number("fireInterval", 0.25)
    config.maxRange = number("maxRange", 160.0)
    config.spawnForwardOffset = number("spawnForwardOffset", 0.0)
    config.prefabPath = tostring(source.prefabPath or config.prefabPath or "")
    config.collisionExplosionSize = number("collisionExplosionSize", 0.1)
    config.environmentExplosionSize = number("environmentExplosionSize", 0.1)
    config.beamImpactExplosionSize = number("beamImpactExplosionSize", 0.0)
    config.beamImpactExplosionImpulse = number("beamImpactExplosionImpulse", 0.0)
    config.beamImpactExplosionMinDistance = number("beamImpactExplosionMinDistance", 0.0)
    config.beamLife = number("beamLife", 0.08)
    config.beamWidth = number("beamWidth", 0.16)
    config.hSlotV2Resolved = true
    return config
end

function server.hSlotV2ResolveRecoveryPoints(shipBody, config)
    local shipTransform = GetBodyTransform(shipBody)
    local firePos = config.firePosOffset or {}
    local fireDir = config.fireDirRelative or {}
    local localPosition = Vec(
        tonumber(firePos.x) or 0.0,
        tonumber(firePos.y) or 0.0,
        tonumber(firePos.z) or 0.0
    )
    local localDirection = Vec(
        tonumber(fireDir.x) or 0.0,
        tonumber(fireDir.y) or 0.0,
        tonumber(fireDir.z) or -1.0
    )
    local outward = server.hSlotV2Normalize(
        TransformToParentVec(shipTransform, localDirection), Vec(0, 0, -1)
    )
    local mountPoint = TransformToParentPoint(shipTransform, localPosition)
    local dockingPoint = VecAdd(
        mountPoint,
        VecScale(outward, math.max(1.0, tonumber(config.spawnForwardOffset) or 0.0) + 1.0)
    )
    local approachPoint = VecAdd(
        dockingPoint,
        VecScale(outward, math.max(6.0, tonumber(config.recoveryApproachDistance) or 24.0))
    )
    return approachPoint, dockingPoint
end

if server.registryShipUnregister == nil then
    function server.registryShipUnregister(shipBodyId)
        if shipBodyId == nil or shipBodyId == 0 then return end
        local prefix = "StellarisShips/server/ships/byId/" .. tostring(shipBodyId)
        SetBool(prefix .. "/exists", false, true)
        SetBool(prefix .. "/destroyed", true, true)
        SetString(prefix .. "/shipType", "", true)
        SetFloat(prefix .. "/shieldRadius", 0.0, true)
        SetFloat(prefix .. "/shieldHP", 0.0, true)
        SetFloat(prefix .. "/armorHP", 0.0, true)
        SetFloat(prefix .. "/bodyHP", 0.0, true)
    end
end

function server.hSlotV2DeleteCraftBody(bodyId)
    if bodyId == nil or bodyId == 0 then return end
    server.registryShipUnregister(bodyId)
    if IsHandleValid(bodyId) then Delete(bodyId) end
end

function server.hSlotV2FinishCraft(state, slotIndex, cooldownMode)
    local launchers = state.launchers or {}
    local launcher = launchers[slotIndex]
    local runtime = launcher and launcher.runtime or nil
    local config = launcher and server.hSlotV2ResolveConfig(launcher.config) or {}
    if runtime ~= nil then
        runtime.cooldownRemain = cooldownMode == "ready"
            and 0.0
            or math.max(0.0, tonumber(config.cooldown) or 0.0)
    end
    local active = state.activeCrafts or {}
    server.hSlotV2DeleteCraftBody((active[slotIndex] or {}).bodyId or 0)
    active[slotIndex] = nil
    state.activeCrafts = active
end

function server.hSlotV2CraftExplode(shipBody, craft, config)
    server.hSlotV2BumpCounter(shipBody, "craft_explode")
    local position = craft and craft.pos or nil
    if position ~= nil then
        Explosion(position, tonumber(config.collisionExplosionSize) or 0.1)
    end
    server.hSlotV2DeleteCraftBody(craft and craft.bodyId or 0)
end

function server.hSlotV2ResolveTargetShieldRadius(targetBody, defaultShipType)
    if targetBody == nil or targetBody == 0 then return 5.0 end
    if server.registryShipGetShieldRadius ~= nil then
        local radius = server.registryShipGetShieldRadius(targetBody, defaultShipType)
        if tonumber(radius) ~= nil and radius > 0 then return radius end
    end
    local shipType = server.registryShipGetShipType ~= nil
        and server.registryShipGetShipType(targetBody)
        or defaultShipType
    local definition = (shipTypeRegistryData or {})[shipType]
        or (shipData or {})[shipType]
        or (shipTypeRegistryData or {})[defaultShipType]
        or (shipData or {})[defaultShipType]
        or {}
    return math.max(0.1, tonumber(definition.shieldRadius) or 5.0)
end

function server.hSlotV2RaySphereEntry(origin, direction, center, radius)
    local offset = VecSub(origin, center)
    local b = 2.0 * VecDot(offset, direction)
    local c = VecDot(offset, offset) - radius * radius
    local discriminant = b * b - 4.0 * c
    if discriminant < 0.0 then return nil end
    local root = math.sqrt(discriminant)
    local first = (-b - root) * 0.5
    local second = (-b + root) * 0.5
    if first >= 0.0 then return first end
    if second >= 0.0 then return second end
    return nil
end

function server.hSlotV2ApplyBeamDamage(hitPos, hitBody, weaponType)
    local didHitShield = false
    if hitBody == nil or hitBody == 0 or not server.registryShipExists(hitBody) then
        return false
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(hitBody) then
        return false
    end

    local shieldHP, armorHP, bodyHP = server.registryShipGetHP(hitBody)
    if shieldHP == nil or armorHP == nil or bodyHP == nil then return false end
    local weapon = (weaponData or {})[weaponType]
        or (weaponData or {}).gammaStrikeCraft
        or {}
    local damageMin = tonumber(weapon.damageMin) or 0.0
    local damageMax = math.max(damageMin, tonumber(weapon.damageMax) or damageMin)
    local remaining = damageMin
    if damageMax > damageMin then
        remaining = damageMin + (damageMax - damageMin) * math.random()
    end

    local function applyLayer(currentHP, multiplier, isShield)
        local hp = tonumber(currentHP) or 0.0
        local fix = tonumber(multiplier) or 1.0
        if hp <= 0.0 or remaining <= 0.0 or fix <= 0.0 then return hp end
        local potential = remaining * fix
        if potential < hp then
            hp = hp - potential
            remaining = 0.0
        else
            remaining = math.max(0.0, remaining - hp / fix)
            hp = 0.0
        end
        if isShield and hp < currentHP then didHitShield = true end
        return hp
    end

    shieldHP = applyLayer(shieldHP, weapon.shieldFix, true)
    armorHP = applyLayer(armorHP, weapon.armorFix, false)
    bodyHP = applyLayer(bodyHP, weapon.bodyFix, false)
    server.registryShipSetHP(hitBody, shieldHP, armorHP, bodyHP)
    return didHitShield
end

function server.hSlotV2FireBeam(shipBody, craft, targetCenter, config)
    server.hSlotV2BumpCounter(shipBody, "beam_fire")
    local origin = VecAdd(
        craft.pos or targetCenter,
        VecScale(
            craft.forward or Vec(0, 0, -1),
            math.max(0.1, tonumber(config.muzzleForwardOffset) or 1.2)
        )
    )
    local direction = server.hSlotV2Normalize(
        VecSub(targetCenter, origin), craft.forward or Vec(0, 0, -1)
    )
    local maxRange = math.max(1.0, tonumber(config.maxRange) or 160.0)

    QueryRequire("physical")
    QueryRejectBody(shipBody)
    QueryRejectBody(craft.bodyId)
    local hit, distance, _, shape = QueryRaycast(origin, direction, maxRange, 0.05)
    local endPosition = hit
        and VecAdd(origin, VecScale(direction, distance))
        or VecAdd(origin, VecScale(direction, maxRange))
    local hitBody = hit and shape ~= nil and shape ~= 0 and GetShapeBody(shape) or 0
    if hit and hitBody ~= 0 and server.registryShipExists(hitBody) then
        local targetCenter = server.hSlotV2GetBodyCenter(hitBody)
        local shieldRadius = server.hSlotV2ResolveTargetShieldRadius(
            hitBody, server.defaultShipType or "enigmaticCruiser"
        )
        if targetCenter ~= nil then
            local entryDistance = server.hSlotV2RaySphereEntry(
                origin, direction, targetCenter, shieldRadius
            )
            if entryDistance ~= nil and entryDistance <= maxRange then
                endPosition = VecAdd(origin, VecScale(direction, entryDistance))
            end
        end
    end

    local didHitShield = false
    if hit then
        didHitShield = server.hSlotV2ApplyBeamDamage(
            endPosition, hitBody, craft.weaponType or "gammaStrikeCraft"
        )
        local explosionSize = math.max(0.0, tonumber(config.beamImpactExplosionSize) or 0.0)
        local minimumDistance = math.max(0.0, tonumber(config.beamImpactExplosionMinDistance) or 0.0)
        if explosionSize > 0.0 and VecLength(VecSub(endPosition, origin)) >= minimumDistance then
            local impulse = math.max(0.0, tonumber(config.beamImpactExplosionImpulse) or 0.0)
            if impulse > 0.0 then Explosion(endPosition, explosionSize, impulse)
            else Explosion(endPosition, explosionSize) end
        end
        ClientCall(
            0, "client.playWeaponSound",
            craft.weaponType or "gammaStrikeCraft", "hit",
            endPosition[1], endPosition[2], endPosition[3]
        )
    end

    ClientCall(0, "client.playHSlotGammaFireSound", origin[1], origin[2], origin[3])
    ClientCall(
        0, "client.spawnHSlotBeamFx",
        origin[1], origin[2], origin[3],
        endPosition[1], endPosition[2], endPosition[3],
        didHitShield and 1 or 0,
        config.beamLife or 0.08,
        config.beamWidth or 0.16
    )
    if didHitShield and hitBody ~= 0 then
        ClientCall(
            0, "client.playProjectileShieldImpactFx", hitBody,
            endPosition[1], endPosition[2], endPosition[3]
        )
    end
end

function server.hSlotV2UpdateBeam(shipBody, craft, targetCenter, config, dt)
    if craft == nil or craft.bodyId == nil or craft.bodyId == 0
        or not IsHandleValid(craft.bodyId) or targetCenter == nil then
        return
    end
    craft.fireRemain = (craft.fireRemain or 0.0) - (dt or 0.0)
    local distance = VecLength(VecSub(targetCenter, craft.pos or targetCenter))
    if distance <= math.max(1.0, tonumber(config.maxRange) or 160.0)
        and craft.fireRemain <= 0.0 then
        server.hSlotV2FireBeam(shipBody, craft, targetCenter, config)
        craft.fireRemain = math.max(0.02, tonumber(config.fireInterval) or 0.22)
    end
end
