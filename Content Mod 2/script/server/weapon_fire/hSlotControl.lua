---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.hSlotState = server.hSlotState or {
    fireRequested = false,
    launchers = {},
    activeCrafts = {},
}

server.hSlotDebugState = server.hSlotDebugState or {
    enabled = true,
    lastReason = "none",
    fireFlag = 0,
    requestHas = 0,
    requestTarget = 0,
    stage = "boot",
    spawnSeq = 0,
    lastSpawnBody = 0,
    lastCollisionBody = 0,
    lastCollisionDist = -1.0,
}

local function _hSlotSetDebugReason(slotIndex, reason, craft)
    local d = server.hSlotDebugState or {}
    if not d.enabled then
        return
    end

    local slot = math.floor(slotIndex or 0)
    local body = craft ~= nil and math.floor(craft.bodyId or 0) or 0
    local life = craft ~= nil and (tonumber(craft.lifeRemain) or 0.0) or 0.0
    local ret = craft ~= nil and (tonumber(craft.returnRemain) or 0.0) or 0.0
    local stateName = craft ~= nil and tostring(craft.state or "nil") or "nil"
    d.lastReason = string.format("slot=%d reason=%s body=%d state=%s life=%.2f return=%.2f", slot, tostring(reason or "unknown"), body, stateName, life, ret)
    server.hSlotDebugState = d
end

local function _hSlotSetDebugStage(stage)
    local d = server.hSlotDebugState or {}
    d.stage = tostring(stage or "unknown")
    server.hSlotDebugState = d
end

local function _hSlotSetCollisionDebug(hitBody, hitDist)
    local d = server.hSlotDebugState or {}
    d.lastCollisionBody = math.floor(hitBody or 0)
    d.lastCollisionDist = tonumber(hitDist) or -1.0
    server.hSlotDebugState = d
end

local function _hSlotSafeDebugWatch(label, value)
    local _ = label
    local __ = value
end

local function _hSlotDebugWatchTick(state)
    local _ = state
end

local function _hSlotCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = tonumber(t.x) or defaultX or 0.0,
        y = tonumber(t.y) or defaultY or 0.0,
        z = tonumber(t.z) or defaultZ or 0.0,
    }
end

local function _hSlotNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _hSlotResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    return defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

local function _hSlotResolveWeaponDefinition(weaponType)
    local defs = hSlotWeaponRegistryData or {}
    local requested = weaponType or "gammaStrikeCraft"
    return defs[requested] or defs.gammaStrikeCraft or {}
end

local function _hSlotGetBodyCenterWorld(bodyId)
    if bodyId == nil or bodyId == 0 or not IsHandleValid(bodyId) then
        return nil
    end
    local bodyT = GetBodyTransform(bodyId)
    local centerLocal = GetBodyCenterOfMass(bodyId)
    return TransformToParentPoint(bodyT, centerLocal)
end

local function _hSlotResolveRecoveryPoint(shipBody, launcherConfig)
    local shipCenter = _hSlotGetBodyCenterWorld(shipBody)
    if shipCenter ~= nil then
        return shipCenter
    end

    local shipT = GetBodyTransform(shipBody)
    local localPos = Vec(
        tonumber((launcherConfig.firePosOffset or {}).x) or 0.0,
        tonumber((launcherConfig.firePosOffset or {}).y) or 0.0,
        tonumber((launcherConfig.firePosOffset or {}).z) or 0.0
    )
    return TransformToParentPoint(shipT, localPos)
end

local function _hSlotBuildBodyTransform(spawnPos, forwardDir)
    local eye = spawnPos or Vec(0, 0, 0)
    local target = VecAdd(eye, _hSlotNormalize(forwardDir, Vec(0, 0, -1)))
    return Transform(eye, QuatLookAt(eye, target))
end

local function _hSlotSpawnCraftBody(prefabPath, spawnPos, forwardDir)
    if prefabPath == nil or prefabPath == "" then
        return 0
    end

    local entities = Spawn(prefabPath, _hSlotBuildBodyTransform(spawnPos, forwardDir), true, false) or {}
    for i = 1, #entities do
        local entityId = entities[i]
        if entityId ~= nil and entityId ~= 0 and GetEntityType(entityId) == "body" then
            return entityId
        end
    end
    return 0
end

local function _hSlotDeleteCraftBody(bodyId)
    if bodyId ~= nil and bodyId ~= 0 and IsHandleValid(bodyId) then
        Delete(bodyId)
    end
end

local function _hSlotBuildLauncherConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "gammaStrikeCraft")
    local weaponDef = _hSlotResolveWeaponDefinition(weaponType)

    return {
        weaponType = weaponType,
        firePosOffset = _hSlotCloneVec3(slotDef and slotDef.firePosOffset, 0.0, 0.0, -1.0),
        fireDirRelative = _hSlotCloneVec3(slotDef and slotDef.fireDirRelative, 0.0, 0.0, -1.0),
        cooldown = tonumber(weaponDef.cooldown) or 20.0,
        craftLifetime = tonumber(weaponDef.craftLifetime) or 24.0,
        returnTimeout = tonumber(weaponDef.returnTimeout) or 6.0,
        craftSpeed = tonumber(weaponDef.craftSpeed) or 30.0,
        turnLerp = tonumber(weaponDef.turnLerp) or 4.0,
        approachDistance = tonumber(weaponDef.approachDistance) or 14.0,
        orbitRadius = tonumber(weaponDef.orbitRadius) or 10.0,
        orbitEntryThreshold = tonumber(weaponDef.orbitEntryThreshold) or 11.0,
        orbitLeaveThreshold = tonumber(weaponDef.orbitLeaveThreshold) or 18.0,
        avoidProbeDistance = tonumber(weaponDef.avoidProbeDistance) or 7.0,
        avoidProbeDistanceFar = tonumber(weaponDef.avoidProbeDistanceFar) or tonumber(weaponDef.avoidProbeDistance) or 7.0,
        collisionProbeRadius = tonumber(weaponDef.collisionProbeRadius) or 0.2,
        collisionStartOffset = tonumber(weaponDef.collisionStartOffset) or 1.2,
        recoverRadius = tonumber(weaponDef.recoverRadius) or 10.0,
        fireInterval = tonumber(weaponDef.fireInterval) or 0.25,
        attackDuration = tonumber(weaponDef.attackDuration) or 10.0,
        maxRange = tonumber(weaponDef.maxRange) or 160.0,
        prefabPath = tostring(weaponDef.prefabPath or ""),
        spawnForwardOffset = tonumber(weaponDef.spawnForwardOffset) or 0.0,
        turnRate = tonumber(weaponDef.turnRate) or 0.0,
        turnImpulse = tonumber(weaponDef.turnImpulse) or 0.0,
        damageMin = tonumber(weaponDef.damageMin) or 50.0,
        damageMax = tonumber(weaponDef.damageMax) or tonumber(weaponDef.damageMin) or 50.0,
        shieldFix = tonumber(weaponDef.shieldFix) or 1.0,
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
        collisionExplosionSize = tonumber(weaponDef.collisionExplosionSize) or 0.1,
        environmentExplosionSize = tonumber(weaponDef.environmentExplosionSize) or 0.1,
    }
end

local function _hSlotBuildLauncherRuntime()
    return {
        cooldownRemain = 0.0,
    }
end

function server.hSlotControlSetFireRequested(active)
    local state = server.hSlotState or {}
    state.fireRequested = active and true or false
    server.hSlotState = state

    local d = server.hSlotDebugState or {}
    d.fireFlag = active and 1 or 0
    d.stage = active and "fire_requested" or "idle"
    server.hSlotDebugState = d
end

local function _hSlotConsumeFireRequested()
    local state = server.hSlotState or {}
    local requested = state.fireRequested and true or false
    state.fireRequested = false
    server.hSlotState = state
    return requested
end

local function _hSlotPickReadyLauncher(state)
    local launchers = state.launchers or {}
    local activeCrafts = state.activeCrafts or {}

    for i = 1, #launchers do
        local launcher = launchers[i]
        local runtime = launcher and launcher.runtime or nil
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) <= 0.0 and activeCrafts[i] == nil then
            return i, launcher
        end
    end

    return nil, nil
end

local function _hSlotTryDirection(shipBody, rejectBody, fromPos, dir, dist)
    QueryRequire("physical")
    QueryRejectBody(shipBody)
    if rejectBody ~= nil and rejectBody ~= 0 then
        QueryRejectBody(rejectBody)
    end
    local hit = QueryRaycast(fromPos, dir, dist, 0.2)
    return not hit
end

local function _hSlotRotateToward(baseDir, axis, angleDeg, fallback)
    local axisNorm = _hSlotNormalize(axis, fallback or Vec(0, 1, 0))
    local rad = math.rad(angleDeg or 0.0)
    local cosA = math.cos(rad)
    local sinA = math.sin(rad)
    local term1 = VecScale(baseDir, cosA)
    local term2 = VecScale(VecCross(axisNorm, baseDir), sinA)
    local term3 = VecScale(axisNorm, VecDot(axisNorm, baseDir) * (1.0 - cosA))
    return _hSlotNormalize(VecAdd(term1, VecAdd(term2, term3)), fallback or baseDir)
end

local function _hSlotResolveAvoidDir(shipBody, rejectBody, pos, desiredDir, forwardDir, probeDistance)
    local forward = _hSlotNormalize(desiredDir, forwardDir)
    local worldUp = Vec(0, 1, 0)
    local right = _hSlotNormalize(VecCross(forward, worldUp), Vec(1, 0, 0))
    local pitchAxis = _hSlotNormalize(VecCross(right, forward), worldUp)
    local nearDist = math.max(1.0, tonumber(probeDistance) or 7.0)
    local farDist = math.max(nearDist, nearDist * 1.6)

    local candidates = {
        { dir = forward, near = nearDist, far = farDist },
        { dir = _hSlotRotateToward(forward, worldUp, 35.0, forward), near = nearDist, far = farDist },
        { dir = _hSlotRotateToward(forward, worldUp, -35.0, forward), near = nearDist, far = farDist },
        { dir = _hSlotRotateToward(forward, worldUp, 60.0, forward), near = nearDist * 0.9, far = farDist * 0.9 },
        { dir = _hSlotRotateToward(forward, worldUp, -60.0, forward), near = nearDist * 0.9, far = farDist * 0.9 },
        { dir = _hSlotRotateToward(forward, right, -25.0, forward), near = nearDist, far = farDist },
        { dir = _hSlotRotateToward(forward, right, -45.0, forward), near = nearDist * 0.9, far = farDist * 0.9 },
        { dir = _hSlotRotateToward(forward, right, 20.0, forward), near = nearDist * 0.75, far = farDist * 0.75 },
        { dir = _hSlotRotateToward(forward, pitchAxis, 30.0, forward), near = nearDist * 0.85, far = farDist * 0.85 },
        { dir = _hSlotRotateToward(forward, pitchAxis, -30.0, forward), near = nearDist * 0.85, far = farDist * 0.85 },
    }

    for i = 1, #candidates do
        local candidate = candidates[i]
        if _hSlotTryDirection(shipBody, rejectBody, pos, candidate.dir, candidate.near)
            and _hSlotTryDirection(shipBody, rejectBody, pos, candidate.dir, candidate.far) then
            return candidate.dir
        end
    end

    for i = 1, #candidates do
        local candidate = candidates[i]
        if _hSlotTryDirection(shipBody, rejectBody, pos, candidate.dir, candidate.near * 0.55) then
            return candidate.dir
        end
    end

    return nil
end

local function _hSlotApplyBeamDamage(hitPos, hitBody, weaponType, environmentExplosionSize)
    local didHitShield = false
    local impactLayer = "none"

    if hitBody ~= nil and hitBody ~= 0 and server.registryShipExists(hitBody) then
        local resolvedDefaultShipType = server.defaultShipType or "enigmaticCruiser"
        if not server.registryShipEnsure(hitBody, resolvedDefaultShipType, resolvedDefaultShipType) then
            return false, hitPos, "none"
        end

        if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(hitBody) then
            return false, hitPos, "environment"
        end

        local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(hitBody) or resolvedDefaultShipType
        local targetShieldHP, targetArmorHP, targetBodyHP = server.registryShipGetHP(hitBody)
        if targetShieldHP == nil or targetArmorHP == nil or targetBodyHP == nil then
            return
        end

        local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[resolvedDefaultShipType]) or {}
        local weapon = (weaponData and weaponData[weaponType]) or (weaponData and weaponData.gammaStrikeCraft) or {}
        local damageMin = tonumber(weapon.damageMin) or 0.0
        local damageMax = tonumber(weapon.damageMax) or damageMin
        if damageMax < damageMin then
            damageMax = damageMin
        end

        local rolledDamage = damageMin
        if damageMax > damageMin then
            rolledDamage = damageMin + (damageMax - damageMin) * math.random()
        end

        local rawRemain = rolledDamage
        local function _applyLayer(layerName, currentHp, damageFix)
            local hp = currentHp or 0.0
            local fix = tonumber(damageFix) or 1.0
            if hp <= 0.0 or rawRemain <= 0.0 or fix <= 0.0 then
                return hp
            end

            local potential = rawRemain * fix
            if potential < hp then
                hp = hp - potential
                rawRemain = 0.0
            else
                rawRemain = rawRemain - (hp / fix)
                hp = 0.0
            end

            if rawRemain < 0.0 then
                rawRemain = 0.0
            end

            if impactLayer == "none" then
                impactLayer = layerName
            end
            return hp
        end

        local function _applyShieldLayer(currentHp, damageFix)
            local before = currentHp or 0.0
            local after = _applyLayer("shield", before, damageFix)
            if after < before then
                didHitShield = true
            end
            return after
        end

        targetShieldHP = _applyShieldLayer(targetShieldHP, weapon.shieldFix)
        targetArmorHP = _applyLayer("armor", targetArmorHP, weapon.armorFix)
        targetBodyHP = _applyLayer("body", targetBodyHP, weapon.bodyFix)

        local maxShield = tonumber(targetShipData.maxShieldHP) or targetShieldHP or 0.0
        local maxArmor = tonumber(targetShipData.maxArmorHP) or targetArmorHP or 0.0
        local maxBody = tonumber(targetShipData.maxBodyHP) or targetBodyHP or 0.0
        if targetShieldHP > maxShield then targetShieldHP = maxShield end
        if targetArmorHP > maxArmor then targetArmorHP = maxArmor end
        if targetBodyHP > maxBody then targetBodyHP = maxBody end

        server.registryShipSetHP(hitBody, targetShieldHP, targetArmorHP, targetBodyHP)
        return didHitShield, hitPos, impactLayer
    end

    return false, hitPos, "environment"
end

local function _hSlotResolveTargetShieldRadius(targetBody, defaultShipType)
    if targetBody == nil or targetBody == 0 then
        return 5.0
    end

    local resolvedDefaultShipType = defaultShipType or server.defaultShipType or "enigmaticCruiser"
    local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(targetBody) or resolvedDefaultShipType
    local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[resolvedDefaultShipType]) or {}
    return math.max(0.1, tonumber(targetShipData.shieldRadius) or 5.0)
end

local function _hSlotRaySphereEntryT(origin, dir, center, radius)
    local oc = VecSub(origin, center)
    local b = 2.0 * VecDot(oc, dir)
    local c = VecDot(oc, oc) - radius * radius
    local disc = b * b - 4.0 * c
    if disc < 0.0 then
        return nil
    end

    local s = math.sqrt(disc)
    local t1 = (-b - s) * 0.5
    local t2 = (-b + s) * 0.5
    if t1 >= 0.0 then
        return t1
    end
    if t2 >= 0.0 then
        return t2
    end
    return nil
end

local function _hSlotFireGammaBeam(shipBody, craft, targetCenter, weaponConfig)
    local origin = craft.pos or targetCenter
    local toTarget = VecSub(targetCenter, origin)
    local dir = _hSlotNormalize(toTarget, craft.forward or Vec(0, 0, -1))
    local maxRange = math.max(1.0, tonumber(weaponConfig.maxRange) or 160.0)

    QueryRequire("physical")
    QueryRejectBody(shipBody)
    local hit, dist, normal, shape = QueryRaycast(origin, dir, maxRange, 0.05)
    if not hit then
        local endPos = VecAdd(origin, VecScale(dir, maxRange))
        ClientCall(
            0,
            "client.spawnHSlotBeamFx",
            origin[1], origin[2], origin[3],
            endPos[1], endPos[2], endPos[3],
            0,
            weaponConfig.beamLife or 0.08,
            weaponConfig.beamWidth or 0.16
        )
        return
    end

    local hitPos = VecAdd(origin, VecScale(dir, dist))
    local hitBody = shape ~= nil and shape ~= 0 and GetShapeBody(shape) or 0

    if hitBody ~= 0 and server.registryShipExists(hitBody) then
        local targetBodyT = GetBodyTransform(hitBody)
        local targetCenterPos = TransformToParentPoint(targetBodyT, GetBodyCenterOfMass(hitBody))
        local shieldRadius = _hSlotResolveTargetShieldRadius(hitBody, server.defaultShipType or "enigmaticCruiser")
        local entryT = _hSlotRaySphereEntryT(origin, dir, targetCenterPos, shieldRadius)
        if entryT ~= nil and entryT <= maxRange then
            hitPos = VecAdd(origin, VecScale(dir, entryT))
        end
    end

    local didHitShield = _hSlotApplyBeamDamage(hitPos, hitBody, craft.weaponType, tonumber(weaponConfig.environmentExplosionSize) or 0.1)
    ClientCall(
        0,
        "client.spawnHSlotBeamFx",
        origin[1], origin[2], origin[3],
        hitPos[1], hitPos[2], hitPos[3],
        didHitShield and 1 or 0,
        weaponConfig.beamLife or 0.08,
        weaponConfig.beamWidth or 0.16
    )

    if didHitShield and hitBody ~= nil and hitBody ~= 0 then
        ClientCall(0, "client.playProjectileShieldImpactFx", hitBody, hitPos[1], hitPos[2], hitPos[3])
    end

    if normal ~= nil and normal[2] ~= nil then
        local _ = normal
    end
end

local function _hSlotUpdateBeamFire(shipBody, craft, targetCenter, weaponConfig, dt)
    if craft == nil or craft.bodyId == nil or craft.bodyId == 0 or not IsHandleValid(craft.bodyId) then
        return
    end
    if targetCenter == nil then
        return
    end

    local dist = VecLength(VecSub(targetCenter, craft.pos or targetCenter))
    local maxRange = math.max(1.0, tonumber(weaponConfig.maxRange) or 160.0)
    craft.fireRemain = (craft.fireRemain or 0.0) - (dt or 0.0)
    if dist <= maxRange and craft.fireRemain <= 0.0 then
        _hSlotFireGammaBeam(shipBody, craft, targetCenter, weaponConfig)
        craft.fireRemain = math.max(0.02, tonumber(weaponConfig.fireInterval) or 0.22)
    end
end

local function _hSlotCraftExplode(craft, weaponConfig)
    local pos = craft and craft.pos or nil
    if pos ~= nil then
        Explosion(pos, tonumber(weaponConfig.collisionExplosionSize) or 0.1)
    end
    _hSlotDeleteCraftBody(craft and craft.bodyId or 0)
end

local function _hSlotFinishCraft(state, slotIndex, cooldownMode)
    local launchers = state.launchers or {}
    local launcher = launchers[slotIndex]
    local runtime = launcher and launcher.runtime or nil
    local config = launcher and launcher.config or {}

    if runtime ~= nil then
        if cooldownMode == "ready" then
            runtime.cooldownRemain = 0.0
        else
            runtime.cooldownRemain = math.max(0.0, tonumber(config.cooldown) or 0.0)
        end
    end

    local active = state.activeCrafts or {}
    _hSlotDeleteCraftBody((active[slotIndex] or {}).bodyId or 0)
    active[slotIndex] = nil
    state.activeCrafts = active
end

function server.hSlotStateInit(shipType)
    local shipDef = _hSlotResolveShipDefinition(shipType)
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        shipDef = server.shipSlotLoadoutResolveShipDefinition(shipType) or shipDef
    end

    local state = {
        fireRequested = false,
        launchers = {},
        activeCrafts = {},
    }

    local slotDefs = shipDef.hSlots or {}
    for i = 1, #slotDefs do
        state.launchers[i] = {
            config = _hSlotBuildLauncherConfig(slotDefs[i]),
            runtime = _hSlotBuildLauncherRuntime(),
        }
    end

    server.hSlotState = state
    server.hSlotLastFireRequest = nil
    return state
end

function server.hSlotStateResetRuntime()
    local state = server.hSlotState or {}
    _hSlotSetDebugReason(0, "runtime_reset", nil)
    state.fireRequested = false

    local launchers = state.launchers or {}
    local active = state.activeCrafts or {}
    for slotIndex, craft in pairs(active) do
        local _ = slotIndex
        _hSlotDeleteCraftBody((craft or {}).bodyId or 0)
    end
    state.activeCrafts = {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil then
            runtime.cooldownRemain = 0.0
        end
    end

    server.hSlotLastFireRequest = nil
    server.hSlotState = state
end

function server.hSlotControlSyncHud()
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    local state = server.hSlotState or {}
    local launchers = state.launchers or {}
    local activeCrafts = state.activeCrafts or {}

    local cd1 = ((launchers[1] or {}).runtime or {}).cooldownRemain or 0.0
    local cd2 = ((launchers[2] or {}).runtime or {}).cooldownRemain or 0.0
    local max1 = ((launchers[1] or {}).config or {}).cooldown or 1.0
    local max2 = ((launchers[2] or {}).config or {}).cooldown or 1.0
    local active1 = activeCrafts[1] ~= nil and 1 or 0
    local active2 = activeCrafts[2] ~= nil and 1 or 0

    local d = server.hSlotDebugState or {}
    local c1 = activeCrafts[1]
    local c2 = activeCrafts[2]
    local dbgReason = tostring(d.lastReason or "none")
    local dbgS1State = c1 ~= nil and tostring(c1.state or "none") or "none"
    local dbgS1Attack = c1 ~= nil and (tonumber(c1.attackRemain) or 0.0) or -1.0
    local dbgS1Life = c1 ~= nil and (tonumber(c1.lifeRemain) or 0.0) or -1.0
    local dbgS1Return = c1 ~= nil and (tonumber(c1.returnRemain) or 0.0) or -1.0
    local dbgS1Fire = c1 ~= nil and (tonumber(c1.fireRemain) or 0.0) or -1.0
    local dbgS2State = c2 ~= nil and tostring(c2.state or "none") or "none"
    local dbgS2Attack = c2 ~= nil and (tonumber(c2.attackRemain) or 0.0) or -1.0
    local dbgS2Life = c2 ~= nil and (tonumber(c2.lifeRemain) or 0.0) or -1.0
    local dbgS2Return = c2 ~= nil and (tonumber(c2.returnRemain) or 0.0) or -1.0
    local dbgS2Fire = c2 ~= nil and (tonumber(c2.fireRemain) or 0.0) or -1.0

    -- 全局调试键：用于绕过 ClientCall 链路，直接验证服务端调度层状态
    local dbgRoot = "StellarisShips/debug/hslot"
    local shipKey = tostring(math.floor(shipBody or 0))
    local shipRoot = dbgRoot .. "/byShip/" .. shipKey

    local heartbeat = (GetInt(shipRoot .. "/heartbeat") or 0) + 1
    if heartbeat > 1000000000 then heartbeat = 1 end
    SetInt(shipRoot .. "/heartbeat", heartbeat)
    SetInt(shipRoot .. "/active", active1 + active2)
    SetString(shipRoot .. "/last_reason", dbgReason)
    SetString(shipRoot .. "/slot1/state", dbgS1State)
    SetFloat(shipRoot .. "/slot1/attack", dbgS1Attack)
    SetFloat(shipRoot .. "/slot1/life", dbgS1Life)
    SetFloat(shipRoot .. "/slot1/return", dbgS1Return)
    SetFloat(shipRoot .. "/slot1/fire", dbgS1Fire)
    SetString(shipRoot .. "/slot2/state", dbgS2State)
    SetFloat(shipRoot .. "/slot2/attack", dbgS2Attack)
    SetFloat(shipRoot .. "/slot2/life", dbgS2Life)
    SetFloat(shipRoot .. "/slot2/return", dbgS2Return)
    SetFloat(shipRoot .. "/slot2/fire", dbgS2Fire)

    -- 兼容观察：保留全局最近写入来源，便于确认是否被其他脚本实例覆盖
    SetInt(dbgRoot .. "/lastShipBody", math.floor(shipBody or 0))

    ClientCall(
        0,
        "client.updateHSlotHudState",
        shipBody,
        cd1,
        cd2,
        max1,
        max2,
        active1,
        active2,
        dbgReason,
        dbgS1State,
        dbgS1Life,
        dbgS1Return,
        dbgS2State,
        dbgS2Life,
        dbgS2Return
    )

    ClientCall(
        0,
        "client.receiveHSlotDebugState",
        active1 + active2,
        dbgReason,
        dbgS1State,
        dbgS1Life,
        dbgS1Return,
        dbgS2State,
        dbgS2Life,
        dbgS2Return
    )
end

function server.hSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end

    local state = server.hSlotState
    if state == nil then
        return
    end

    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        _hSlotSetDebugReason(0, "owner_ship_dead", nil)
        server.hSlotStateResetRuntime()
        return
    end

    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) > 0.0 then
            runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - (dt or 0.0))
        end
    end

    local activeCrafts = state.activeCrafts or {}
    for slotIndex = 1, #launchers do
        local craft = activeCrafts[slotIndex]
        if craft ~= nil then
        local launcher = launchers[slotIndex]
        local weaponConfig = launcher and launcher.config or {}
        local keepUpdating = true

        if craft.bodyId == nil or craft.bodyId == 0 or not IsHandleValid(craft.bodyId) then
            _hSlotSetDebugReason(slotIndex, "craft_invalid_handle", craft)
            _hSlotFinishCraft(state, slotIndex)
            keepUpdating = false
        end

        if keepUpdating then
            local bodyT = GetBodyTransform(craft.bodyId)
            craft.pos = bodyT.pos
            local currentVel = GetBodyVelocity(craft.bodyId)
            local fallbackDir = _hSlotNormalize(TransformToParentVec(bodyT, Vec(0, 0, -1)), craft.forward or Vec(0, 0, -1))
            craft.forward = _hSlotNormalize(currentVel, fallbackDir)
        end

        craft.lifeRemain = (craft.lifeRemain or 0.0) - (dt or 0.0)
        if keepUpdating and craft.lifeRemain <= 0.0 then
            _hSlotSetDebugReason(slotIndex, "life_timeout_explode", craft)
            _hSlotCraftExplode(craft, weaponConfig)
            _hSlotFinishCraft(state, slotIndex)
            keepUpdating = false
        end

        if keepUpdating then
            if craft.state ~= "returning" then
                craft.attackRemain = (craft.attackRemain or (weaponConfig.attackDuration or 10.0)) - (dt or 0.0)
                if craft.attackRemain <= 0.0 then
                    craft.state = "returning"
                    _hSlotSetDebugReason(slotIndex, "attack_window_elapsed_return", craft)
                end
            end

            local targetCenter = _hSlotGetBodyCenterWorld(craft.targetBodyId or 0)
            local targetBodyId = math.floor(craft.targetBodyId or 0)
            local targetIsStellaris = targetBodyId ~= 0 and server.registryShipExists(targetBodyId)
            local targetIsDead = false

            if targetIsStellaris and server.registryShipIsBodyDead ~= nil then
                targetIsDead = server.registryShipIsBodyDead(targetBodyId)
            end

            if targetIsDead then
                targetCenter = nil
            end

            if targetCenter ~= nil then
                craft.lastTargetCenter = targetCenter
            elseif not targetIsStellaris then
                targetCenter = craft.lastTargetCenter
            end

            if targetIsStellaris and (targetIsDead or targetCenter == nil) then
                craft.state = "returning"
            end

            if craft.state == "approach" and targetCenter ~= nil then
                local currentDist = VecLength(VecSub(craft.pos, targetCenter))
                local orbitRadius = math.max(2.0, tonumber(weaponConfig.orbitRadius) or 10.0)
                local entryBand = math.max(1.0, tonumber(weaponConfig.orbitEntryThreshold) or 4.0)
                if math.abs(currentDist - orbitRadius) <= entryBand then
                    craft.state = "orbit"
                end
            end

            if craft.state == "orbit" and targetCenter ~= nil then
                local dist = VecLength(VecSub(targetCenter, craft.pos))
                local orbitRadius = math.max(2.0, tonumber(weaponConfig.orbitRadius) or 10.0)
                local leaveBand = math.max(2.0, tonumber(weaponConfig.orbitLeaveThreshold) or 8.0)
                if math.abs(dist - orbitRadius) > leaveBand then
                    craft.state = "approach"
                end
            end

            if craft.state ~= "returning" and targetCenter == nil and targetIsStellaris then
                craft.state = "returning"
            end

            if craft.state == "returning" then
                craft.returnRemain = (craft.returnRemain or (weaponConfig.returnTimeout or 6.0)) - (dt or 0.0)
                if craft.returnRemain <= 0.0 then
                    _hSlotSetDebugReason(slotIndex, "return_timeout_explode", craft)
                    _hSlotCraftExplode(craft, weaponConfig)
                    _hSlotFinishCraft(state, slotIndex)
                    keepUpdating = false
                end
            end

            local desiredDir = craft.forward or Vec(0, 0, -1)

            if keepUpdating and craft.state == "returning" then
                local recovery = _hSlotResolveRecoveryPoint(shipBody, weaponConfig)
                local toRecovery = VecSub(recovery, craft.pos)
                if VecLength(toRecovery) <= math.max(1.0, tonumber(weaponConfig.recoverRadius) or 10.0) then
                    _hSlotSetDebugReason(slotIndex, "return_recovered_finish", craft)
                    _hSlotFinishCraft(state, slotIndex, "ready")
                    keepUpdating = false
                end
                if keepUpdating then
                    desiredDir = _hSlotNormalize(toRecovery, desiredDir)
                end
            elseif keepUpdating and craft.state == "orbit" and targetCenter ~= nil then
                craft.orbitAngle = (craft.orbitAngle or 0.0) + (dt or 0.0) * 1.2
                local radial = _hSlotNormalize(VecSub(craft.pos, targetCenter), Vec(1, 0, 0))
                local tangent = _hSlotNormalize(VecCross(Vec(0, 1, 0), radial), Vec(0, 0, -1))
                local dist = VecLength(VecSub(craft.pos, targetCenter))
                local radiusErr = ((weaponConfig.orbitRadius or 10.0) - dist)
                local radialGain = tonumber(weaponConfig.orbitRadialGain) or 0.10
                desiredDir = _hSlotNormalize(VecAdd(tangent, VecScale(radial, -radiusErr * radialGain)), tangent)
            elseif keepUpdating then
                local approachTarget = nil
                if targetCenter ~= nil then
                    local shipCenter = _hSlotGetBodyCenterWorld(shipBody) or craft.pos
                    local radialDir = _hSlotNormalize(VecSub(shipCenter, targetCenter), Vec(1, 0, 0))
                    local tangentDir = _hSlotNormalize(VecCross(Vec(0, 1, 0), radialDir), Vec(0, 0, -1))
                    local orbitRadius = math.max(2.0, tonumber(weaponConfig.orbitRadius) or 10.0)
                    local ahead = math.max(0.0, tonumber(weaponConfig.approachDistance) or 14.0)
                    approachTarget = VecAdd(
                        VecAdd(targetCenter, VecScale(radialDir, orbitRadius)),
                        VecScale(tangentDir, ahead)
                    )
                else
                    approachTarget = VecAdd(craft.pos, VecScale(craft.forward or desiredDir, math.max(8.0, tonumber(weaponConfig.approachDistance) or 14.0)))
                end
                desiredDir = _hSlotNormalize(VecSub(approachTarget, craft.pos), desiredDir)
            end

            if keepUpdating then
                local avoidDir = _hSlotResolveAvoidDir(shipBody, craft.bodyId or 0, craft.pos, desiredDir, craft.forward or desiredDir, weaponConfig.avoidProbeDistance or 7.0)
                if avoidDir == nil then
                    avoidDir = _hSlotNormalize(desiredDir, craft.forward or Vec(0, 0, -1))
                end

                if keepUpdating then
                    local turnLerp = math.max(0.0, tonumber(weaponConfig.turnLerp) or 4.0)
                    local blend = math.min(1.0, turnLerp * (dt or 0.0))
                    local blended = _hSlotNormalize(
                        VecAdd(VecScale(craft.forward or avoidDir, 1.0 - blend), VecScale(avoidDir, blend)),
                        avoidDir
                    )
                    local speed = math.max(4.0, tonumber(weaponConfig.craftSpeed) or 30.0)
                    local nextPos = VecAdd(craft.pos, VecScale(blended, speed * (dt or 0.0)))

                    local step = VecSub(nextPos, craft.pos)
                    local stepLen = VecLength(step)
                    if stepLen > 0.0001 then
                        local sweepDir = VecScale(step, 1.0 / stepLen)
                        local startOffset = math.max(0.0, tonumber(weaponConfig.collisionStartOffset) or 1.2)
                        local sweepStart = craft.pos
                        local sweepLen = stepLen
                        if startOffset > 0.0 then
                            local clampedOffset = math.min(stepLen * 0.8, startOffset)
                            sweepStart = VecAdd(craft.pos, VecScale(sweepDir, clampedOffset))
                            sweepLen = math.max(0.0, stepLen - clampedOffset)
                        end

                        if sweepLen > 0.0001 then
                        QueryRequire("physical")
                        QueryRejectBody(shipBody)
                        QueryRejectBody(craft.bodyId)
                        local hit, hitDist, hitNormal, hitShape = QueryRaycast(sweepStart, sweepDir, sweepLen, weaponConfig.collisionProbeRadius or 0.2)
                        if hit then
                            local hitBody = hitShape ~= nil and hitShape ~= 0 and GetShapeBody(hitShape) or 0
                            _hSlotSetCollisionDebug(hitBody, hitDist)

                            local ignoreDegenerateHit = false
                            if hitShape == nil or hitShape == 0 then
                                ignoreDegenerateHit = (tonumber(hitDist) or 0.0) <= 0.05
                            end
                            if hitBody == nil or hitBody == 0 or (IsHandleValid ~= nil and not IsHandleValid(hitBody)) then
                                ignoreDegenerateHit = ignoreDegenerateHit or ((tonumber(hitDist) or 0.0) <= 0.05)
                            end

                            local ignoreTargetSweep = false
                            if hitBody ~= 0 and hitBody == math.floor(craft.targetBodyId or 0) then
                                local targetCenter = _hSlotGetBodyCenterWorld(hitBody)
                                local targetShieldRadius = _hSlotResolveTargetShieldRadius(hitBody, server.defaultShipType or "enigmaticCruiser")
                                local targetContactRadius = math.max(2.0, targetShieldRadius + 1.0)
                                if targetCenter ~= nil then
                                    local distToCenter = VecLength(VecSub(craft.pos, targetCenter))
                                    if distToCenter > targetContactRadius then
                                        ignoreTargetSweep = true
                                    end
                                end
                            end

                            if not ignoreDegenerateHit and not ignoreTargetSweep then
                                _hSlotSetDebugReason(slotIndex, "step_collision_explode", craft)
                                _hSlotCraftExplode(craft, weaponConfig)
                                _hSlotFinishCraft(state, slotIndex)
                                keepUpdating = false
                            end
                        end
                        end
                    end

                    if keepUpdating then
                        craft.forward = blended
                        craft.pos = nextPos
                        craft.desiredRot = QuatLookAt(craft.pos, VecAdd(craft.pos, blended))
                        SetBodyActive(craft.bodyId, true)
                        SetBodyVelocity(craft.bodyId, VecScale(blended, math.max(4.0, tonumber(weaponConfig.craftSpeed) or 30.0)))
                        ConstrainOrientation(
                            craft.bodyId,
                            0,
                            GetBodyTransform(craft.bodyId).rot,
                            craft.desiredRot,
                            weaponConfig.turnRate or 0.0,
                            weaponConfig.turnImpulse or 0.0
                        )

                        if craft.state ~= "returning" then
                            _hSlotUpdateBeamFire(shipBody, craft, targetCenter, weaponConfig, dt)
                        end
                    end
                end
            end
        end
        end
    end

    _hSlotDebugWatchTick(state)

    server.hSlotControlSyncHud()

    if not _hSlotConsumeFireRequested() then
        _hSlotSetDebugStage("tick_idle")
        return
    end

    local request = server.hSlotLastFireRequest
    server.hSlotLastFireRequest = nil
    do
        local d = server.hSlotDebugState or {}
        d.fireFlag = 0
        d.requestHas = request ~= nil and 1 or 0
        d.requestTarget = request ~= nil and math.floor(request.targetBodyId or 0) or 0
        d.stage = request ~= nil and "request_consumed" or "request_empty"
        server.hSlotDebugState = d
    end
    if request == nil then
        return
    end

    local targetBodyId = math.floor(request.targetBodyId or 0)
    if targetBodyId == 0 then
        _hSlotSetDebugReason(0, "request_target_missing", nil)
        return
    end

    local slotIndex, launcher = _hSlotPickReadyLauncher(state)
    if slotIndex == nil or launcher == nil then
        _hSlotSetDebugReason(0, "fire_requested_but_no_ready_launcher", nil)
        _hSlotSetDebugStage("no_ready_launcher")
        return
    end
    _hSlotSetDebugStage("launcher_picked_" .. tostring(slotIndex))

    local shipT = GetBodyTransform(shipBody)
    local firePos = TransformToParentPoint(shipT, Vec(
        tonumber((launcher.config.firePosOffset or {}).x) or 0.0,
        tonumber((launcher.config.firePosOffset or {}).y) or 0.0,
        tonumber((launcher.config.firePosOffset or {}).z) or -1.0
    ))
    local fireDir = _hSlotNormalize(TransformToParentVec(shipT, Vec(
        tonumber((launcher.config.fireDirRelative or {}).x) or 0.0,
        tonumber((launcher.config.fireDirRelative or {}).y) or 0.0,
        tonumber((launcher.config.fireDirRelative or {}).z) or -1.0
    )), Vec(0, 0, -1))

    firePos = VecAdd(firePos, VecScale(fireDir, launcher.config.spawnForwardOffset or 0.0))
    _hSlotSetDebugStage("spawn_attempt")
    local craftBody = _hSlotSpawnCraftBody(launcher.config.prefabPath, firePos, fireDir)
    if craftBody == nil or craftBody == 0 then
        _hSlotSetDebugReason(slotIndex, "spawn_failed", nil)
        _hSlotSetDebugStage("spawn_failed")
        return
    end
    do
        local d = server.hSlotDebugState or {}
        d.spawnSeq = math.floor(d.spawnSeq or 0) + 1
        d.lastSpawnBody = math.floor(craftBody or 0)
        d.stage = "spawned_body"
        server.hSlotDebugState = d
    end
    SetBodyDynamic(craftBody, true)
    SetBodyActive(craftBody, true)
    SetBodyVelocity(craftBody, VecScale(fireDir, math.max(4.0, tonumber(launcher.config.craftSpeed) or 30.0)))

    state.activeCrafts[slotIndex] = {
        slotIndex = slotIndex,
        bodyId = craftBody,
        weaponType = tostring(launcher.config.weaponType or "gammaStrikeCraft"),
        targetBodyId = targetBodyId,
        pos = firePos,
        forward = fireDir,
        state = "approach",
        attackRemain = math.max(0.5, tonumber(launcher.config.attackDuration) or 10.0),
        lifeRemain = math.max(0.5, tonumber(launcher.config.craftLifetime) or 24.0),
        returnRemain = math.max(0.5, tonumber(launcher.config.returnTimeout) or 6.0),
        fireRemain = 0.0,
        orbitAngle = 0.0,
    }

    _hSlotSetDebugReason(slotIndex, "spawn_success", state.activeCrafts[slotIndex])
    _hSlotSetDebugStage("active_registered")
    server.hSlotControlSyncHud()
end
