---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.hSlotNetworkConfig = server.hSlotNetworkConfig or {
    hudInterval = 0.2,
    debugInterval = 1.0,
    debugEnabled = false,
}

server.hSlotEntityLimits = server.hSlotEntityLimits or {
    maxPerShip = 4,
    maxGlobal = 24,
}

local _hSlotGlobalCountKey =
    "StellarisShips/server/runtime/activeStrikeCraft"

local function _hSlotGetGlobalCraftCount()
    return math.max(0, GetInt(_hSlotGlobalCountKey) or 0)
end

local function _hSlotAdjustGlobalCraftCount(delta)
    local nextCount = math.max(
        0,
        _hSlotGetGlobalCraftCount() + math.floor(delta or 0)
    )
    SetInt(_hSlotGlobalCountKey, nextCount)
    return nextCount
end

server.hSlotState = server.hSlotState or {
    fireRequested = false,
    launchers = {},
    activeCrafts = {},
}

server.hSlotDebugState = server.hSlotDebugState or {
    enabled = false,
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
    if not server.hSlotNetworkConfig.debugEnabled then
        return
    end
    d.enabled = true

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
    if not server.hSlotNetworkConfig.debugEnabled then return end
    d.stage = tostring(stage or "unknown")
    server.hSlotDebugState = d
end

local function _hSlotSetCollisionDebug(hitBody, hitDist)
    local d = server.hSlotDebugState or {}
    if not server.hSlotNetworkConfig.debugEnabled then return end
    d.lastCollisionBody = math.floor(hitBody or 0)
    d.lastCollisionDist = tonumber(hitDist) or -1.0
    server.hSlotDebugState = d
end

local function _hSlotWriteExplosionDebug(shipBody, pos, size, impulse)
    if not server.hSlotNetworkConfig.debugEnabled then return end
    local ownerBody = math.floor(shipBody or 0)
    if ownerBody <= 0 or pos == nil then
        return
    end

    local dbgRoot = "StellarisShips/debug/hslot"
    local shipRoot = dbgRoot .. "/byShip/" .. tostring(ownerBody)
    local seq = (GetInt(shipRoot .. "/lastExplosion/seq") or 0) + 1
    if seq > 1000000000 then seq = 1 end

    SetInt(shipRoot .. "/lastExplosion/seq", seq)
    SetFloat(shipRoot .. "/lastExplosion/pos/x", pos[1] or 0.0)
    SetFloat(shipRoot .. "/lastExplosion/pos/y", pos[2] or 0.0)
    SetFloat(shipRoot .. "/lastExplosion/pos/z", pos[3] or 0.0)
    SetFloat(shipRoot .. "/lastExplosion/size", tonumber(size) or 0.0)
    SetFloat(shipRoot .. "/lastExplosion/impulse", tonumber(impulse) or 0.0)
end

local function _hSlotBumpDebugCounter(shipBody, keyName)
    if not server.hSlotNetworkConfig.debugEnabled then return end
    local ownerBody = math.floor(shipBody or 0)
    if ownerBody <= 0 then
        return
    end

    local safeKey = tostring(keyName or "unknown")
    local dbgRoot = "StellarisShips/debug/hslot"
    local shipRoot = dbgRoot .. "/byShip/" .. tostring(ownerBody)
    local fullKey = shipRoot .. "/counters/" .. safeKey
    local v = (GetInt(fullKey) or 0) + 1
    if v > 1000000000 then v = 1 end
    SetInt(fullKey, v)
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

-- 计算从点P到以center为中心、radius为半径的圆的最小转弯切入点
-- 返回：切入点和到达时的切线方向
local function _hSlotComputeOptimalEntryPoint(planePos, planeForward, targetCenter, orbitRadius)
    local toTarget = VecSub(targetCenter, planePos)
    local distToTarget = VecLength(toTarget)
    
    -- 如果已经在轨道内，直接飞向目标
    if distToTarget <= orbitRadius then
        return targetCenter, _hSlotNormalize(toTarget, Vec(0, 0, -1))
    end
    
    -- 归一化方向
    local toTargetDir = _hSlotNormalize(toTarget, Vec(0, 0, -1))
    local forwardDir = _hSlotNormalize(planeForward, Vec(0, 0, -1))
    
    -- 计算切点：在toTargetDir垂直方向上偏移
    -- 找到垂直于toTargetDir的平面内的两个切点
    local up = Vec(0, 1, 0)
    local right = _hSlotNormalize(VecCross(toTargetDir, up), Vec(1, 0, 0))
    up = _hSlotNormalize(VecCross(right, toTargetDir), Vec(0, 1, 0))
    
    -- 计算切线长度和角度
    -- 从点P到圆的距离为d，半径为r，则切线长度为sqrt(d^2 - r^2)
    -- 切点与圆心连线和toTargetDir的夹角为acos(r/d)
    local d = distToTarget
    local r = orbitRadius
    local cosTheta = r / d
    local sinTheta = math.sqrt(1.0 - cosTheta * cosTheta)
    
    -- 两个切点方向（相对目标中心）
    local tangentOffset = VecAdd(VecScale(toTargetDir, -cosTheta), VecScale(right, sinTheta))
    local leftTangentDir = _hSlotNormalize(tangentOffset, right)
    tangentOffset = VecAdd(VecScale(toTargetDir, -cosTheta), VecScale(right, -sinTheta))
    local rightTangentDir = _hSlotNormalize(tangentOffset, VecScale(right, -1))
    
    -- 两个切点位置
    local leftTangentPoint = VecAdd(targetCenter, VecScale(leftTangentDir, r))
    local rightTangentPoint = VecAdd(targetCenter, VecScale(rightTangentDir, r))
    
    -- 计算从当前位置到两个切点的方向
    local toLeft = _hSlotNormalize(VecSub(leftTangentPoint, planePos), leftTangentDir)
    local toRight = _hSlotNormalize(VecSub(rightTangentPoint, planePos), rightTangentDir)
    
    -- 计算当前朝向到两个切入方向的夹角（点积越大，角度越小）
    local dotLeft = VecDot(forwardDir, toLeft)
    local dotRight = VecDot(forwardDir, toRight)
    
    -- 选择夹角更小的（点积更大的）
    if dotLeft >= dotRight then
        -- 左转切入，返回切点和切线方向（切线方向垂直于半径方向）
        local tangentDir = _hSlotNormalize(VecCross(up, leftTangentDir), Vec(0, 0, -1))
        -- 确保切线方向是远离目标的方向（从目标中心向外看，切线方向应该是切线方向的反方向）
        local awayFromTarget = VecDot(tangentDir, toTargetDir)
        if awayFromTarget > 0 then
            tangentDir = VecScale(tangentDir, -1)
        end
        return leftTangentPoint, tangentDir, "counterclockwise"  -- 第三个返回值：方向选择
    else
        local tangentDir = _hSlotNormalize(VecCross(up, rightTangentDir), Vec(0, 0, -1))
        local awayFromTarget = VecDot(tangentDir, toTargetDir)
        if awayFromTarget > 0 then
            tangentDir = VecScale(tangentDir, -1)
        end
        return rightTangentPoint, tangentDir, "clockwise"  -- 第三个返回值：方向选择
    end
end

local function _hSlotResolveShipDefinition(shipType)
    local contextType = server.shipContextGetType()
    return shipDefinitionGet(shipType or contextType, contextType)
end

local function _hSlotResolveWeaponDefinition(weaponType)
    local defs = weaponData or {}
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
    local shipT = GetBodyTransform(shipBody)
    local localPos = Vec(
        tonumber((launcherConfig.firePosOffset or {}).x) or 0.0,
        tonumber((launcherConfig.firePosOffset or {}).y) or 0.0,
        tonumber((launcherConfig.firePosOffset or {}).z) or 0.0
    )
    local direction = _hSlotNormalize(TransformToParentVec(shipT, Vec(
        tonumber((launcherConfig.fireDirRelative or {}).x) or 0.0,
        tonumber((launcherConfig.fireDirRelative or {}).y) or 0.0,
        tonumber((launcherConfig.fireDirRelative or {}).z) or -1.0
    )), Vec(0, 0, -1))
    return VecAdd(
        TransformToParentPoint(shipT, localPos),
        VecScale(direction, launcherConfig.spawnForwardOffset or 0.0)
    )
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
    local bodyId, muzzle, engineLeft, engineRight = 0, 0, 0, 0
    for i = 1, #entities do
        local entityId = entities[i]
        if entityId ~= nil and entityId ~= 0 and GetEntityType(entityId) == "body" then
            bodyId = entityId
        elseif entityId ~= nil and entityId ~= 0
            and GetEntityType(entityId) == "location" then
            if HasTag(entityId, "strikeCraftMuzzle") then muzzle = entityId end
            if HasTag(entityId, "strikeCraftEngineLeft") then engineLeft = entityId end
            if HasTag(entityId, "strikeCraftEngineRight") then engineRight = entityId end
        end
    end
    return bodyId, muzzle, engineLeft, engineRight
end

local function _hSlotDeleteCraftBody(bodyId)
    if bodyId ~= nil and bodyId ~= 0 and IsHandleValid(bodyId) then
        if server.netClientCall ~= nil then
            server.netClientCall(
                "weapon.fireFx",
                0,
                "client.unregisterHSlotCraftFx",
                bodyId
            )
        end
        if server.registryShipUnregister ~= nil then
            server.registryShipUnregister(bodyId)
        end
        local vehicle = GetBodyVehicle(bodyId)
        Delete(vehicle ~= nil and vehicle ~= 0 and vehicle or bodyId)
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
        cruiseSpeed = tonumber(weaponDef.cruiseSpeed) or 82.0,
        attackSpeed = tonumber(weaponDef.attackSpeed) or 102.0,
        breakSpeed = tonumber(weaponDef.breakSpeed) or 88.0,
        returnSpeed = tonumber(weaponDef.returnSpeed) or 74.0,
        dockSpeed = tonumber(weaponDef.dockSpeed) or 18.0,
        emergencySpeed = tonumber(weaponDef.emergencySpeed) or 30.0,
        launchSpeedFactor = tonumber(weaponDef.launchSpeedFactor) or 0.86,
        minimumControlFactor = tonumber(weaponDef.minimumControlFactor) or 0.64,
        maxAcceleration = tonumber(weaponDef.maxAcceleration) or 310.0,
        maxDeceleration = tonumber(weaponDef.maxDeceleration) or 390.0,
        maxAngularVelocity = tonumber(weaponDef.maxAngularVelocity) or 20.0,
        maxAngularImpulse = tonumber(weaponDef.maxAngularImpulse) or 9000.0,
        turnBlendRate = tonumber(weaponDef.turnBlendRate) or 1.5,
        craftRadius = tonumber(weaponDef.craftRadius) or 1.60,
        farProbeDistance = tonumber(weaponDef.farProbeDistance) or 70.0,
        nearSweepLookahead = tonumber(weaponDef.nearSweepLookahead) or 0.18,
        emergencyDuration = tonumber(weaponDef.emergencyDuration) or 0.70,
        recoverRadius = tonumber(weaponDef.recoverRadius) or 10.0,
        fireInterval = tonumber(weaponDef.fireInterval) or 0.25,
        attackDuration = tonumber(weaponDef.attackDuration) or 10.0,
        maxRange = tonumber(weaponDef.maxRange) or 280.0,
        prefabPath = tostring(weaponDef.prefabPath or ""),
        spawnForwardOffset = tonumber(weaponDef.spawnForwardOffset) or 0.0,
        turnRate = tonumber(weaponDef.turnRate) or 0.0,
        turnImpulse = tonumber(weaponDef.turnImpulse) or 0.0,
        damageMin = tonumber(weaponDef.damageMin) or 50.0,
        damageMax = tonumber(weaponDef.damageMax) or tonumber(weaponDef.damageMin) or 50.0,
        shieldFix = tonumber(weaponDef.shieldFix) or 1.0,
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
        shieldPenetration = tonumber(weaponDef.shieldPenetration) or 0.0,
        armorPenetration = tonumber(weaponDef.armorPenetration) or 0.0,
        collisionExplosionSize = tonumber(weaponDef.collisionExplosionSize) or 0.1,
        environmentExplosionSize = tonumber(weaponDef.environmentExplosionSize) or 0.1,
        beamImpactExplosionSize = tonumber(weaponDef.beamImpactExplosionSize) or 0.0,
        beamImpactExplosionImpulse = tonumber(weaponDef.beamImpactExplosionImpulse) or 0.0,
        beamImpactExplosionMinDistance = tonumber(weaponDef.beamImpactExplosionMinDistance) or 0.0,
        beamLife = tonumber(weaponDef.beamLife) or 0.08,
        beamWidth = tonumber(weaponDef.beamWidth) or 0.16,
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
    server.netDebugCountRaycast(1)
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
    local nearDist = math.max(1.0, tonumber(probeDistance) or 7.0)
    local farDist = math.max(nearDist, nearDist * 1.6)

    if _hSlotTryDirection(shipBody, rejectBody, pos, forward, farDist) then
        return forward
    end

    local preferred = {
        _hSlotRotateToward(forward, worldUp, 35.0, forward),
        _hSlotRotateToward(forward, worldUp, -35.0, forward),
        _hSlotRotateToward(forward, right, -30.0, forward),
        _hSlotRotateToward(forward, right, 25.0, forward),
    }
    for i = 1, #preferred do
        if _hSlotTryDirection(
            shipBody,
            rejectBody,
            pos,
            preferred[i],
            farDist
        ) then
            return preferred[i]
        end
    end

    local emergency = {
        preferred[3],
        preferred[1],
        preferred[2],
    }
    for i = 1, #emergency do
        if _hSlotTryDirection(
            shipBody,
            rejectBody,
            pos,
            emergency[i],
            nearDist * 0.55
        ) then
            return emergency[i]
        end
    end

    return preferred[3]
end

local function _hSlotDirectionAngleDegrees(a, b)
    local aNorm = _hSlotNormalize(a, Vec(0, 0, -1))
    local bNorm = _hSlotNormalize(b, Vec(0, 0, -1))
    local dot = math.max(-1.0, math.min(1.0, VecDot(aNorm, bNorm)))
    return math.deg(math.acos(dot))
end

local function _hSlotResolveAvoidDirCached(
    shipBody,
    craft,
    desiredDir,
    probeDistance,
    dt
)
    craft.aiAccumulator = (craft.aiAccumulator or 0.0)
        + math.max(0.0, tonumber(dt) or 0.0)
    craft.avoidCacheAge = (craft.avoidCacheAge or 1000.0)
        + math.max(0.0, tonumber(dt) or 0.0)
    local interval = math.max(0.05, tonumber(craft.aiInterval) or 0.1)
    if craft.desiredDirection ~= nil and craft.aiAccumulator < interval then
        return craft.desiredDirection
    end
    craft.aiAccumulator = math.max(0.0, craft.aiAccumulator - interval)

    local cachedPos = craft.avoidCachePos
    local cachedInput = craft.avoidCacheInput
    local cacheReusable = craft.desiredDirection ~= nil
        and cachedPos ~= nil
        and cachedInput ~= nil
        and craft.avoidCacheAge <= 0.2
        and VecLength(VecSub(craft.pos, cachedPos)) < 1.0
        and _hSlotDirectionAngleDegrees(desiredDir, cachedInput) < 5.0
    if cacheReusable then return craft.desiredDirection end

    craft.desiredDirection = _hSlotResolveAvoidDir(
        shipBody,
        craft.bodyId or 0,
        craft.pos,
        desiredDir,
        craft.forward or desiredDir,
        probeDistance
    )
    craft.avoidCachePos = Vec(craft.pos[1], craft.pos[2], craft.pos[3])
    craft.avoidCacheInput = Vec(
        desiredDir[1],
        desiredDir[2],
        desiredDir[3]
    )
    craft.avoidCacheAge = 0.0
    return craft.desiredDirection
end

local function _hSlotApplyBeamDamage(
    hitPos,
    hitBody,
    weaponType,
    environmentExplosionSize,
    attackerBodyId
)
    if hitBody ~= nil and hitBody ~= 0 and server.registryShipExists(hitBody) then
        local resolvedDefaultShipType = server.shipContextGetType()
        if not server.registryShipEnsure(hitBody, resolvedDefaultShipType, resolvedDefaultShipType) then
            return false, hitPos, "none"
        end

        if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(hitBody) then
            return false, hitPos, "environment"
        end

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

        local result = server.shipDamageApplyWeaponDefinition(
            hitBody,
            weapon,
            rolledDamage,
            attackerBodyId
        )
        return result.didHitShield, hitPos, result.impactLayer
    end

    return false, hitPos, "environment"
end

local function _hSlotResolveTargetShieldRadius(targetBody, defaultShipType)
    if targetBody == nil or targetBody == 0 then
        return 5.0
    end

    local resolvedDefaultShipType = defaultShipType or server.shipContextGetType()
    local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(targetBody) or resolvedDefaultShipType
    local targetShipData = shipDefinitionGet(targetShipType, resolvedDefaultShipType)
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

local function _hSlotResolveCraftMuzzle(craft, fallback)
    local bodyId = craft and craft.bodyId or 0
    if bodyId ~= nil and bodyId ~= 0 and IsHandleValid(bodyId) then
        return TransformToParentPoint(
            GetBodyTransform(bodyId),
            Vec(0.0, 0.0, -2.61)
        )
    end
    return fallback
end

local function _hSlotFireGammaBeam(shipBody, craft, targetCenter, weaponConfig)
    _hSlotBumpDebugCounter(shipBody, "beam_fire")

    local origin = _hSlotResolveCraftMuzzle(craft, craft.pos or targetCenter)
    local toTarget = VecSub(targetCenter, origin)
    local dir = _hSlotNormalize(toTarget, craft.forward or Vec(0, 0, -1))
    local maxRange = math.max(1.0, tonumber(weaponConfig.maxRange) or 280.0)

    QueryRequire("physical")
    QueryRejectBody(shipBody)
    QueryRejectBody(craft.bodyId)
    server.netDebugCountRaycast(1)
    local hit, dist, normal, shape = QueryRaycast(origin, dir, maxRange, 0.05)
    if not hit then
        _hSlotBumpDebugCounter(shipBody, "beam_nohit")
        local endPos = VecAdd(origin, VecScale(dir, maxRange))
        server.netClientCall(
            "weapon.fireFx",
            0,
            "client.spawnHSlotBeamFx",
            origin[1], origin[2], origin[3],
            endPos[1], endPos[2], endPos[3],
            0,
            weaponConfig.beamLife or 0.08,
            weaponConfig.beamWidth or 0.16,
            "none"
        )
        return
    end

    _hSlotBumpDebugCounter(shipBody, "beam_hit")

    local hitPos = VecAdd(origin, VecScale(dir, dist))
    local hitBody = shape ~= nil and shape ~= 0 and GetShapeBody(shape) or 0

    if hitBody ~= 0 and server.registryShipExists(hitBody) then
        local targetShieldHP = server.registryShipGetHP(hitBody)
        if targetShieldHP ~= nil and targetShieldHP > 0.0 then
            local targetBodyT = GetBodyTransform(hitBody)
            local targetCenterPos = TransformToParentPoint(
                targetBodyT,
                GetBodyCenterOfMass(hitBody)
            )
            local shieldRadius = _hSlotResolveTargetShieldRadius(
                hitBody,
                server.shipContextGetType()
            )
            local entryT = _hSlotRaySphereEntryT(
                origin,
                dir,
                targetCenterPos,
                shieldRadius
            )
            if entryT ~= nil and entryT <= maxRange then
                hitPos = VecAdd(origin, VecScale(dir, entryT))
            end
        end
    end

    local didHitShield, _, impactLayer = _hSlotApplyBeamDamage(
        hitPos,
        hitBody,
        craft.weaponType,
        tonumber(weaponConfig.environmentExplosionSize) or 0.1,
        shipBody
    )

    local impactExplosionSize = math.max(0.0, tonumber(weaponConfig.beamImpactExplosionSize) or 0.0)
    local impactExplosionImpulse = math.max(0.0, tonumber(weaponConfig.beamImpactExplosionImpulse) or 0.0)
    local impactMinDistance = math.max(0.0, tonumber(weaponConfig.beamImpactExplosionMinDistance) or 0.0)
    local impactDistance = VecLength(VecSub(hitPos, origin))
    local hitIsShip = hitBody ~= nil and hitBody ~= 0 and server.registryShipExists(hitBody)
    if not hitIsShip and impactExplosionSize > 0.0 and impactDistance >= impactMinDistance then
        _hSlotBumpDebugCounter(shipBody, "impact_explosion")
        if impactExplosionImpulse > 0.0 then
            Explosion(hitPos, impactExplosionSize, impactExplosionImpulse)
        else
            Explosion(hitPos, impactExplosionSize)
        end
        server.netDebugCountExplosion(1)

        _hSlotWriteExplosionDebug(shipBody, hitPos, impactExplosionSize, impactExplosionImpulse)
    else
        _hSlotBumpDebugCounter(shipBody, "impact_skipped")
    end

    server.netClientCall(
        "weapon.fireFx",
        0,
        "client.playHSlotGammaFireSound",
        origin[1], origin[2], origin[3]
    )
    server.netClientCall(
        "weapon.hitFx",
        0,
        "client.playWeaponSound",
        craft.weaponType or "gammaStrikeCraft",
        "hit",
        hitPos[1], hitPos[2], hitPos[3]
    )
    server.netClientCall(
        "weapon.fireFx",
        0,
        "client.spawnHSlotBeamFx",
        origin[1], origin[2], origin[3],
        hitPos[1], hitPos[2], hitPos[3],
        didHitShield and 1 or 0,
        weaponConfig.beamLife or 0.08,
        weaponConfig.beamWidth or 0.16,
        impactLayer or "body"
    )

    if didHitShield and hitBody ~= nil and hitBody ~= 0 then
        server.netClientCall(
            "weapon.hitFx",
            0,
            "client.playProjectileShieldImpactFx",
            hitBody,
            hitPos[1], hitPos[2], hitPos[3],
            craft.weaponType or "gammaStrikeCraft"
        )
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
    local maxRange = math.max(1.0, tonumber(weaponConfig.maxRange) or 280.0)
    local toTargetDir = dist > 0.001
        and VecScale(VecSub(targetCenter, craft.pos or targetCenter), 1.0 / dist)
        or Vec(0, 0, -1)
    craft.fireRemain = (craft.fireRemain or 0.0) - (dt or 0.0)
    if dist <= maxRange and craft.fireRemain <= 0.0
        and VecDot(craft.forward or Vec(0, 0, -1), toTargetDir) > 0.0 then
        _hSlotFireGammaBeam(shipBody, craft, targetCenter, weaponConfig)
        craft.fireRemain = math.max(0.02, tonumber(weaponConfig.fireInterval) or 0.22)
    end
end

local function _hSlotCraftExplode(shipBody, craft, weaponConfig)
    _hSlotBumpDebugCounter(shipBody, "craft_explode")

    local bodyId = craft and craft.bodyId or 0
    local pos = _hSlotGetBodyCenterWorld(bodyId)
        or (craft and craft.pos or nil)
    local size = tonumber(weaponConfig.collisionExplosionSize) or 0.1
    if bodyId ~= 0 and IsHandleValid(bodyId) then
        SetBodyVelocity(bodyId, Vec(0, 0, 0))
        SetBodyAngularVelocity(bodyId, Vec(0, 0, 0))
    end
    if pos ~= nil then
        Explosion(pos, size)
        server.netDebugCountExplosion(1)
        _hSlotWriteExplosionDebug(shipBody, pos, size, 0.0)
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
    local finishedCraft = active[slotIndex]
    _hSlotDeleteCraftBody((finishedCraft or {}).bodyId or 0)
    active[slotIndex] = nil
    state.activeCrafts = active
    if finishedCraft ~= nil then _hSlotAdjustGlobalCraftCount(-1) end
    if state.hudSync ~= nil then state.hudSync.dirty = true end
end

local function _hSlotHandleDestroyedCraft(
    state,
    shipBody,
    slotIndex,
    craft,
    weaponConfig
)
    craft.state = "DISABLED"
    craft.disabled = true
    _hSlotSetDebugReason(slotIndex, "craft_destroyed", craft)
    _hSlotCraftExplode(shipBody, craft, weaponConfig)
    _hSlotFinishCraft(state, slotIndex)
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
        hudSync = {
            age = 0.0,
            lastSignature = "",
            dirty = true,
        },
        debugSync = {
            age = 0.0,
        },
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
    local removed = 0
    for slotIndex, craft in pairs(active) do
        local _ = slotIndex
        _hSlotDeleteCraftBody((craft or {}).bodyId or 0)
        if craft ~= nil then removed = removed + 1 end
    end
    if removed > 0 then _hSlotAdjustGlobalCraftCount(-removed) end
    state.activeCrafts = {}
    state.hudSync = state.hudSync or {}
    state.hudSync.dirty = true
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil then
            runtime.cooldownRemain = 0.0
        end
    end

    server.hSlotLastFireRequest = nil
    server.hSlotState = state
end

function server.hSlotStateNeedsTick()
    local state = server.hSlotState or {}
    if state.fireRequested or next(state.activeCrafts or {}) ~= nil then
        return true
    end
    for _, launcher in ipairs(state.launchers or {}) do
        if (tonumber((launcher.runtime or {}).cooldownRemain) or 0.0) > 0.0 then
            return true
        end
    end
    local body = server.shipContextGetBody()
    return body ~= 0
        and server.shipRuntimeGetDriverPlayerId(body) > 0
        and server.shipRuntimeGetCurrentMainWeapon(body) == "hSlot"
end

local function _hSlotResolveHudPlayer(shipBody)
    local playerId = server.shipRuntimeGetDriverPlayerId ~= nil
        and math.floor(server.shipRuntimeGetDriverPlayerId(shipBody) or 0)
        or 0
    if playerId <= 0 then return 0 end
    if IsPlayerValid ~= nil and not IsPlayerValid(playerId) then return 0 end
    local vehicle = GetPlayerVehicle(playerId)
    if vehicle == nil or vehicle == 0 or GetVehicleBody(vehicle) ~= shipBody then
        if server.shipRuntimeSetDriverPlayerId ~= nil then
            server.shipRuntimeSetDriverPlayerId(shipBody, 0)
        end
        return 0
    end
    return playerId
end

local function _hSlotBuildHudSignature(state)
    local launchers = state.launchers or {}
    local active = state.activeCrafts or {}
    local currentMode = server.shipRuntimeGetCurrentMainWeapon ~= nil
        and server.shipRuntimeGetCurrentMainWeapon(server.shipContextGetBody())
        or ""
    local values = { tostring(currentMode) }
    for i = 1, 2 do
        local runtime = ((launchers[i] or {}).runtime or {})
        values[#values + 1] = active[i] ~= nil and "1" or "0"
        values[#values + 1] = string.format(
            "%.1f",
            server.netSyncQuantize(runtime.cooldownRemain or 0.0, 0.1)
        )
    end
    return table.concat(values, "|")
end

local function _hSlotWriteDebugSnapshot(
    shipBody,
    active1,
    active2,
    dbgReason,
    dbgS1State,
    dbgS1Attack,
    dbgS1Life,
    dbgS1Return,
    dbgS1Fire,
    dbgS2State,
    dbgS2Attack,
    dbgS2Life,
    dbgS2Return,
    dbgS2Fire
)
    local dbgRoot = "StellarisShips/debug/hslot"
    local shipRoot = dbgRoot .. "/byShip/" .. tostring(math.floor(shipBody or 0))
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
    SetInt(dbgRoot .. "/lastShipBody", math.floor(shipBody or 0))
end

function server.hSlotControlSyncHud(dt, force)
    local shipBody = server.shipContextGetBody()
    if shipBody == nil or shipBody == 0 then
        return
    end

    local state = server.hSlotState or {}
    local launchers = state.launchers or {}
    local activeCrafts = state.activeCrafts or {}
    state.hudSync = state.hudSync or {
        age = 0.0,
        lastSignature = "",
        dirty = true,
    }
    state.debugSync = state.debugSync or { age = 0.0 }
    state.hudSync.age = (state.hudSync.age or 0.0)
        + math.max(0.0, tonumber(dt) or 0.0)
    state.debugSync.age = (state.debugSync.age or 0.0)
        + math.max(0.0, tonumber(dt) or 0.0)

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

    local playerId = _hSlotResolveHudPlayer(shipBody)
    local signature = _hSlotBuildHudSignature(state)
    local hudInterval = math.max(
        0.05,
        tonumber(server.hSlotNetworkConfig.hudInterval) or 0.2
    )
    local changed = signature ~= tostring(state.hudSync.lastSignature or "")
    local keepAlive = state.hudSync.age >= 1.0
    if playerId > 0
        and (force or state.hudSync.dirty
            or (changed and state.hudSync.age >= hudInterval)
            or keepAlive) then
        server.netClientCall(
            "hud.hslot",
            playerId,
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
        state.hudSync.lastSignature = signature
        state.hudSync.age = 0.0
        state.hudSync.dirty = false
    end

    local debugInterval = math.max(
        0.25,
        tonumber(server.hSlotNetworkConfig.debugInterval) or 1.0
    )
    if server.hSlotNetworkConfig.debugEnabled
        and playerId > 0
        and state.debugSync.age >= debugInterval then
        _hSlotWriteDebugSnapshot(
            shipBody,
            active1, active2,
            dbgReason,
            dbgS1State, dbgS1Attack, dbgS1Life, dbgS1Return, dbgS1Fire,
            dbgS2State, dbgS2Attack, dbgS2Life, dbgS2Return, dbgS2Fire
        )
        server.netClientCall(
            "debug.hslot",
            playerId,
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
        state.debugSync.age = 0.0
    end
end

local function _hSlotUpdateReplacementFlight(
    state,
    shipBody,
    slotIndex,
    craft,
    weaponConfig,
    dt
)
    if craft.bodyId == nil or craft.bodyId == 0
        or not IsHandleValid(craft.bodyId) then
        _hSlotSetDebugReason(slotIndex, "craft_invalid_handle", craft)
        _hSlotFinishCraft(state, slotIndex)
        return
    end

    if server.registryShipExists(craft.bodyId)
        and server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(craft.bodyId) then
        _hSlotHandleDestroyedCraft(
            state,
            shipBody,
            slotIndex,
            craft,
            weaponConfig
        )
        return
    end

    craft.lifeRemain = (craft.lifeRemain or 0.0) - (dt or 0.0)
    if craft.lifeRemain <= 0.0 then
        _hSlotSetDebugReason(slotIndex, "life_timeout_explode", craft)
        _hSlotCraftExplode(shipBody, craft, weaponConfig)
        _hSlotFinishCraft(state, slotIndex)
        return
    end

    local targetBodyId = math.floor(craft.targetBodyId or 0)
    local targetCenter = _hSlotGetBodyCenterWorld(targetBodyId)
    if targetBodyId ~= 0
        and server.registryShipExists(targetBodyId)
        and server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(targetBodyId) then
        targetCenter = nil
    end

    local shipTransform = GetBodyTransform(shipBody)
    local carrierUp = _hSlotNormalize(
        TransformToParentVec(shipTransform, Vec(0, 1, 0)),
        Vec(0, 1, 0)
    )
    local recoveryPoint = _hSlotResolveRecoveryPoint(shipBody, weaponConfig)
    local flightStatus, allowFire = server.hSlotFlightUpdate(
        shipBody,
        craft,
        weaponConfig,
        targetCenter,
        recoveryPoint,
        carrierUp,
        dt
    )

    if flightStatus == "recovered" then
        _hSlotSetDebugReason(slotIndex, "return_recovered_finish", craft)
        server.netClientCall("weapon.fireFx", 0, "client.spawnHSlotRecoverFx",
            craft.pos[1], craft.pos[2], craft.pos[3])
        _hSlotFinishCraft(state, slotIndex, "ready")
    elseif flightStatus == "timeout" then
        _hSlotSetDebugReason(slotIndex, "return_timeout_explode", craft)
        _hSlotCraftExplode(shipBody, craft, weaponConfig)
        _hSlotFinishCraft(state, slotIndex)
    elseif allowFire and targetCenter ~= nil then
        _hSlotUpdateBeamFire(
            shipBody,
            craft,
            targetCenter,
            weaponConfig,
            dt
        )
    end
end

function server.hSlotControlTick(dt)
    local shipBody = server.shipContextGetBody()
    if shipBody == nil or shipBody == 0 then
        return
    end

    local shipType = server.shipContextGetType()
    if not server.registryShipEnsure(shipBody, shipType, shipType) then
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
            local wasCooling = runtime.cooldownRemain > 0.0
            runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - (dt or 0.0))
            if wasCooling and runtime.cooldownRemain <= 0.0 then
                state.hudSync.dirty = true
            end
        end
    end

    local activeCrafts = state.activeCrafts or {}
    for slotIndex = 1, #launchers do
        local craft = activeCrafts[slotIndex]
        if craft ~= nil then
            local launcher = launchers[slotIndex]
            _hSlotUpdateReplacementFlight(
                state,
                shipBody,
                slotIndex,
                craft,
                launcher and launcher.config or {},
                dt
            )
        end
    end

    local activeCraftCount = 0
    for _, craft in pairs(state.activeCrafts or {}) do
        if craft ~= nil then activeCraftCount = activeCraftCount + 1 end
    end
    server.netDebugSetEntityCounts(nil, nil, activeCraftCount)
    server.hSlotControlSyncHud(dt, false)

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

    local activeCount = 0
    for _, craft in pairs(state.activeCrafts or {}) do
        if craft ~= nil then activeCount = activeCount + 1 end
    end
    local maxPerShip = math.max(
        1,
        math.floor(server.hSlotEntityLimits.maxPerShip or 4)
    )
    local maxGlobal = math.max(
        maxPerShip,
        math.floor(server.hSlotEntityLimits.maxGlobal or 24)
    )
    if activeCount >= maxPerShip
        or _hSlotGetGlobalCraftCount() >= maxGlobal then
        _hSlotSetDebugReason(0, "craft_capacity_full", nil)
        _hSlotSetDebugStage("capacity_full")
        return
    end

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
    local craftBody, muzzleLocation, engineLeft, engineRight =
        _hSlotSpawnCraftBody(launcher.config.prefabPath, firePos, fireDir)
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
    SetBodyVelocity(
        craftBody,
        VecScale(
            fireDir,
            math.max(4.0, tonumber(launcher.config.cruiseSpeed) or 82.0)
                * (tonumber(launcher.config.launchSpeedFactor) or 0.86)
        )
    )
    server.registryShipRegister(
        craftBody,
        "advancedStrikeCraft",
        server.shipContextGetType()
    )
    if server.registryShipSetInterceptorOwner ~= nil then
        server.registryShipSetInterceptorOwner(craftBody, shipBody)
    end
    server.netClientCall("weapon.fireFx", 0, "client.spawnHSlotLaunchFx", firePos[1], firePos[2], firePos[3], fireDir[1], fireDir[2], fireDir[3])
    server.netClientCall(
        "weapon.fireFx",
        0,
        "client.registerHSlotCraftFx",
        craftBody,
        engineLeft or 0,
        engineRight or 0
    )

    local newCraft = {
        slotIndex = slotIndex,
        bodyId = craftBody,
        muzzleLocation = muzzleLocation or 0,
        engineLeft = engineLeft or 0,
        engineRight = engineRight or 0,
        weaponType = tostring(launcher.config.weaponType or "gammaStrikeCraft"),
        targetBodyId = targetBodyId,
        pos = firePos,
        forward = fireDir,
        attackRemain = math.max(0.5, tonumber(launcher.config.attackDuration) or 10.0),
        lifeRemain = math.max(0.5, tonumber(launcher.config.craftLifetime) or 24.0),
        returnRemain = math.max(0.5, tonumber(launcher.config.returnTimeout) or 6.0),
        fireRemain = 0.0,
    }
    state.activeCrafts[slotIndex] = server.hSlotFlightCreate(
        newCraft,
        slotIndex,
        firePos,
        fireDir
    )
    _hSlotAdjustGlobalCraftCount(1)
    state.hudSync.dirty = true

    _hSlotSetDebugReason(slotIndex, "spawn_success", state.activeCrafts[slotIndex])
    _hSlotSetDebugStage("active_registered")
    server.hSlotControlSyncHud(0.0, true)
end
