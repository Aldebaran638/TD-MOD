---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.sSlotState = server.sSlotState or {
    nextMissileId = 1,
    nextLauncherIndex = 1,
    launchers = {},
    activeMissiles = {},
}

local _sSlotProbeHeadLocal = Vec(0, 0, -3.2)
local _sSlotProbeMidLocal = Vec(0, 0, -1.0)
local _sSlotClosestPointDist = 0.14
local _sSlotSweepRadius = 0.32

local function _sSlotCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = tonumber(t.x) or defaultX or 0.0,
        y = tonumber(t.y) or defaultY or 0.0,
        z = tonumber(t.z) or defaultZ or 0.0,
    }
end

local function _sSlotResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    return defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

local function _sSlotResolveWeaponDefinition(weaponType)
    local defs = sSlotWeaponRegistryData or {}
    local requested = weaponType or "swarmerMissile"
    return defs[requested] or defs.swarmerMissile or {}
end

local function _sSlotNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _sSlotGetBodyCenterWorld(bodyId)
    if bodyId == nil or bodyId == 0 or not IsHandleValid(bodyId) then
        return nil
    end
    local bodyT = GetBodyTransform(bodyId)
    local centerLocal = GetBodyCenterOfMass(bodyId)
    return TransformToParentPoint(bodyT, centerLocal)
end

local function _sSlotGetProbePoints(bodyT)
    return {
        center = bodyT.pos,
        head = TransformToParentPoint(bodyT, _sSlotProbeHeadLocal),
        mid = TransformToParentPoint(bodyT, _sSlotProbeMidLocal),
    }
end

local function _sSlotBuildLauncherConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "swarmerMissile")
    local weaponDef = _sSlotResolveWeaponDefinition(weaponType)
    return {
        weaponType = weaponType,
        firePosOffset = _sSlotCloneVec3(slotDef and slotDef.firePosOffset, 0.0, 0.0, 0.0),
        fireDirRelative = _sSlotCloneVec3(slotDef and slotDef.fireDirRelative, 0.0, 0.0, -1.0),
        cooldown = tonumber(weaponDef.cooldown) or 0.0,
        prefabPath = tostring(weaponDef.prefabPath or ""),
        spawnForwardOffset = tonumber(weaponDef.spawnForwardOffset) or 0.0,
        muzzleSpeed = tonumber(weaponDef.muzzleSpeed) or 0.0,
        cruiseSpeed = tonumber(weaponDef.cruiseSpeed) or 0.0,
        maxSpeed = tonumber(weaponDef.maxSpeed) or 0.0,
        acceleration = tonumber(weaponDef.acceleration) or 0.0,
        lifetime = tonumber(weaponDef.lifetime) or 0.0,
        maxRange = tonumber(weaponDef.maxRange) or 0.0,
        turnBlendRate = tonumber(weaponDef.turnBlendRate) or 0.0,
        turnRate = tonumber(weaponDef.turnRate) or 0.0,
        turnImpulse = tonumber(weaponDef.turnImpulse) or 0.0,
        damage = tonumber(weaponDef.damage) or 0.0,
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
    }
end

local function _sSlotBuildLauncherRuntime()
    return {
        cooldownRemain = 0.0,
    }
end

local function _sSlotPlayFireSound(firePos)
    local p = firePos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileFireSound", p[1], p[2], p[3])
end

local function _sSlotPlayImpactSound(hitPos)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileImpactSound", p[1], p[2], p[3])
end

local function _sSlotPlayImpactFx(hitPos, impactLayer)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileImpactFx", p[1], p[2], p[3], impactLayer or "body")
end

local function _sSlotDeleteMissileBody(bodyId)
    if bodyId ~= nil and bodyId ~= 0 and IsHandleValid(bodyId) then
        Delete(bodyId)
    end
end

local function _sSlotRemoveMissileAt(index)
    local active = server.sSlotState.activeMissiles or {}
    local missile = active[index]
    if missile ~= nil then
        _sSlotDeleteMissileBody(missile.bodyId or 0)
        -- 通知客户端结束导弹视觉效果
        ClientCall(0, "client.finishMissileVisual", missile.id or 0)
    end

    local last = #active
    if index >= 1 and index <= last then
        active[index] = active[last]
        active[last] = nil
    end
end

local function _sSlotClearAllMissiles()
    local active = server.sSlotState.activeMissiles or {}
    for i = #active, 1, -1 do
        _sSlotDeleteMissileBody((active[i] or {}).bodyId or 0)
        active[i] = nil
    end
end

local function _sSlotConsumeFireRequest()
    local request = server.sSlotLastFireRequest
    server.sSlotLastFireRequest = nil
    return request
end

local function _sSlotChooseLauncher(state)
    local launchers = state.launchers or {}
    local count = #launchers
    if count <= 0 then
        return nil
    end

    local startIndex = math.floor(state.nextLauncherIndex or 1)
    if startIndex < 1 or startIndex > count then
        startIndex = 1
    end

    for offset = 0, count - 1 do
        local idx = ((startIndex - 1 + offset) % count) + 1
        local launcher = launchers[idx]
        local runtime = launcher and launcher.runtime or nil
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) <= 0.0 then
            state.nextLauncherIndex = (idx % count) + 1
            return launcher
        end
    end

    return nil
end

local function _sSlotBuildBodyTransform(spawnPos, forwardDir)
    local eye = spawnPos or Vec(0, 0, 0)
    local target = VecAdd(eye, _sSlotNormalize(forwardDir, Vec(0, 0, -1)))
    return Transform(eye, QuatLookAt(eye, target))
end

local function _sSlotSpawnMissileBody(prefabPath, spawnPos, forwardDir)
    if prefabPath == nil or prefabPath == "" then
        return 0
    end

    local entities = Spawn(prefabPath, _sSlotBuildBodyTransform(spawnPos, forwardDir), true, false) or {}
    for i = 1, #entities do
        local entityId = entities[i]
        if entityId ~= nil and entityId ~= 0 and GetEntityType(entityId) == "body" then
            return entityId
        end
    end
    return 0
end

local function _sSlotApplyShipDamage(hitBody, missile)
    if hitBody == nil or hitBody == 0 or not server.registryShipExists(hitBody) then
        return "none"
    end

    local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(hitBody) or (server.defaultShipType or "enigmaticCruiser")
    local targetShieldHP, targetArmorHP, targetBodyHP = server.registryShipGetHP(hitBody)
    if targetShieldHP == nil or targetArmorHP == nil or targetBodyHP == nil then
        return "none"
    end

    local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[server.defaultShipType or "enigmaticCruiser"]) or {}
    local rawRemain = tonumber(missile.damage) or 0.0
    local impactLayer = "none"

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

    targetArmorHP = _applyLayer("armor", targetArmorHP, missile.armorFix)
    targetBodyHP = _applyLayer("body", targetBodyHP, missile.bodyFix)

    local maxShield = tonumber(targetShipData.maxShieldHP) or targetShieldHP or 0.0
    local maxArmor = tonumber(targetShipData.maxArmorHP) or targetArmorHP or 0.0
    local maxBody = tonumber(targetShipData.maxBodyHP) or targetBodyHP or 0.0
    if targetShieldHP > maxShield then targetShieldHP = maxShield end
    if targetArmorHP > maxArmor then targetArmorHP = maxArmor end
    if targetBodyHP > maxBody then targetBodyHP = maxBody end

    server.registryShipSetHP(hitBody, targetShieldHP, targetArmorHP, targetBodyHP)
    return impactLayer
end

local function _sSlotQueryClosestBody(missile, probePos, maxDist)
    QueryRequire("physical")
    QueryRejectBody(missile.bodyId)
    QueryRejectBody(missile.ownerShipBody)
    local hit, point, normal, shape = QueryClosestPoint(probePos, maxDist)
    if not hit or shape == nil or shape == 0 then
        return nil
    end

    return {
        hitPos = point or probePos,
        hitBody = GetShapeBody(shape) or 0,
        normal = normal or Vec(0, 1, 0),
    }
end

local function _sSlotQuerySweepBody(missile, startPos, endPos, radius)
    local seg = VecSub(endPos, startPos)
    local segLen = VecLength(seg)
    if segLen < 0.0001 then
        return nil
    end

    QueryRequire("physical")
    QueryRejectBody(missile.bodyId)
    QueryRejectBody(missile.ownerShipBody)
    local dir = VecScale(seg, 1.0 / segLen)
    local hit, dist, normal, shape = QueryRaycast(startPos, dir, segLen, radius or 0.0)
    if not hit or shape == nil or shape == 0 then
        return nil
    end

    return {
        hitPos = VecAdd(startPos, VecScale(dir, dist)),
        hitBody = GetShapeBody(shape) or 0,
        normal = normal or dir,
    }
end

local function _sSlotResolvePostPhysicsHit(missile, currentProbes)
    local previousHead = missile.prePhysicsHeadPos or currentProbes.head
    local previousMid = missile.prePhysicsMidPos or currentProbes.mid
    local previousCenter = missile.prePhysicsCenterPos or currentProbes.center

    local hit = _sSlotQueryClosestBody(missile, currentProbes.head, _sSlotClosestPointDist)
    if hit ~= nil then
        return hit
    end

    hit = _sSlotQueryClosestBody(missile, currentProbes.mid, _sSlotClosestPointDist)
    if hit ~= nil then
        return hit
    end

    hit = _sSlotQuerySweepBody(missile, previousHead, currentProbes.head, _sSlotSweepRadius)
    if hit ~= nil then
        return hit
    end

    hit = _sSlotQuerySweepBody(missile, previousMid, currentProbes.mid, _sSlotSweepRadius)
    if hit ~= nil then
        return hit
    end

    return _sSlotQuerySweepBody(missile, previousCenter, currentProbes.center, _sSlotSweepRadius)
end

local function _sSlotHandleMissileHit(missile, hitPos, hitBody)
    local pos = hitPos or _sSlotGetBodyCenterWorld(missile.bodyId) or Vec(0, 0, 0)
    local bodyId = hitBody or 0

    if bodyId ~= 0 and server.registryShipExists(bodyId) and not server.registryShipIsBodyDead(bodyId) then
        local impactLayer = _sSlotApplyShipDamage(bodyId, missile)
        _sSlotPlayImpactSound(pos)
        _sSlotPlayImpactFx(pos, impactLayer ~= "none" and impactLayer or "body")
        return
    end

    if bodyId ~= 0 then
        _sSlotPlayImpactSound(pos)
        Explosion(pos, 1.0)
    end
end

function server.sSlotStateInit(shipType)
    _sSlotClearAllMissiles()

    local shipDef = _sSlotResolveShipDefinition(shipType)
    local state = {
        nextMissileId = 1,
        nextLauncherIndex = 1,
        launchers = {},
        activeMissiles = {},
    }

    local slotDefs = shipDef.sSlots or {}
    for i = 1, #slotDefs do
        state.launchers[i] = {
            config = _sSlotBuildLauncherConfig(slotDefs[i]),
            runtime = _sSlotBuildLauncherRuntime(),
        }
    end

    server.sSlotState = state
    server.sSlotLastFireRequest = nil
    return state
end

function server.sSlotStateResetRuntime()
    local state = server.sSlotState or {}
    _sSlotClearAllMissiles()

    state.nextMissileId = 1
    state.nextLauncherIndex = 1
    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil then
            runtime.cooldownRemain = 0.0
        end
    end
    server.sSlotLastFireRequest = nil
end

function server.sSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end

    local state = server.sSlotState
    if state == nil then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.sSlotStateResetRuntime()
        return
    end

    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil and (runtime.cooldownRemain or 0.0) > 0.0 then
            runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - (dt or 0.0))
        end
    end

    local active = state.activeMissiles or {}
    local i = #active
    while i >= 1 do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId == 0 or not IsHandleValid(bodyId) then
            _sSlotRemoveMissileAt(i)
        else
            local currentPos = _sSlotGetBodyCenterWorld(bodyId)
            if currentPos == nil then
                _sSlotRemoveMissileAt(i)
            end
        end

        i = i - 1
    end

    local request = _sSlotConsumeFireRequest()
    if request == nil then
        return
    end
    if server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBody) ~= "sSlot" then
        return
    end

    local targetBodyId = math.floor(request.targetBodyId or 0)
    local targetVehicleId = math.floor(request.targetVehicleId or 0)
    if (targetBodyId == 0 or not IsHandleValid(targetBodyId)) and targetVehicleId == 0 then
        return
    end
    if targetBodyId ~= 0 and targetBodyId == shipBody then
        return
    end
    if targetBodyId ~= 0 and server.registryShipExists(targetBodyId) and server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(targetBodyId) then
        return
    end

    local launcher = _sSlotChooseLauncher(state)
    if launcher == nil then
        return
    end

    local launcherConfig = launcher.config or {}
    local launcherRuntime = launcher.runtime or {}
    local shipT = GetBodyTransform(shipBody)
    local fireLocal = Vec(
        launcherConfig.firePosOffset.x or 0.0,
        launcherConfig.firePosOffset.y or 0.0,
        launcherConfig.firePosOffset.z or 0.0
    )
    local fireDirLocal = Vec(
        launcherConfig.fireDirRelative.x or 0.0,
        launcherConfig.fireDirRelative.y or 0.0,
        launcherConfig.fireDirRelative.z or -1.0
    )
    local fireDirWorld = _sSlotNormalize(TransformToParentVec(shipT, fireDirLocal), Vec(0, 0, -1))
    local firePosWorld = TransformToParentPoint(shipT, fireLocal)
    firePosWorld = VecAdd(firePosWorld, VecScale(fireDirWorld, launcherConfig.spawnForwardOffset or 0.0))

    local missileBody = _sSlotSpawnMissileBody(launcherConfig.prefabPath, firePosWorld, fireDirWorld)
    if missileBody == nil or missileBody == 0 then
        return
    end

    SetBodyDynamic(missileBody, true)
    SetBodyActive(missileBody, true)
    local ownerVelocity = GetBodyVelocity(shipBody)
    local startVelocity = VecAdd(ownerVelocity, VecScale(fireDirWorld, launcherConfig.muzzleSpeed or 0.0))
    SetBodyVelocity(missileBody, startVelocity)
    
    local missileId = state.nextMissileId or 1
    state.nextMissileId = missileId + 1
    
    -- 通知客户端创建导弹视觉效果
    ClientCall(
        0,
        "client.spawnMissileVisual",
        missileId,
        firePosWorld[1], firePosWorld[2], firePosWorld[3],
        startVelocity[1], startVelocity[2], startVelocity[3]
    )
    
    -- 通知客户端创建导弹跃迁特效
    ClientCall(
        0,
        "client.spawnMissileWarpFx",
        firePosWorld[1], firePosWorld[2], firePosWorld[3]
    )
    
    local spawnedProbes = _sSlotGetProbePoints(GetBodyTransform(missileBody))
    table.insert(active, {
        id = missileId,
        bodyId = missileBody,
        ownerShipBody = shipBody,
        targetBodyId = targetBodyId,
        targetVehicleId = targetVehicleId,
        damage = launcherConfig.damage or 0.0,
        armorFix = launcherConfig.armorFix or 1.0,
        bodyFix = launcherConfig.bodyFix or 1.0,
        cruiseSpeed = launcherConfig.cruiseSpeed or 0.0,
        maxSpeed = launcherConfig.maxSpeed or 0.0,
        acceleration = launcherConfig.acceleration or 0.0,
        maxRange = launcherConfig.maxRange or 0.0,
        turnBlendRate = launcherConfig.turnBlendRate or 0.0,
        turnRate = launcherConfig.turnRate or 0.0,
        turnImpulse = launcherConfig.turnImpulse or 0.0,
        lifeRemain = launcherConfig.lifetime or 0.0,
        distanceTravelled = 0.0,
        prePhysicsCenterPos = Vec(spawnedProbes.center[1], spawnedProbes.center[2], spawnedProbes.center[3]),
        prePhysicsHeadPos = Vec(spawnedProbes.head[1], spawnedProbes.head[2], spawnedProbes.head[3]),
        prePhysicsMidPos = Vec(spawnedProbes.mid[1], spawnedProbes.mid[2], spawnedProbes.mid[3]),
        desiredRot = QuatLookAt(firePosWorld, VecAdd(firePosWorld, fireDirWorld)),
    })

    launcherRuntime.cooldownRemain = math.max(0.0, launcherConfig.cooldown or 0.0)
    _sSlotPlayFireSound(firePosWorld)
end

function server.sSlotControlUpdate(dt)
    local active = (server.sSlotState or {}).activeMissiles or {}
    for i = 1, #active do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId ~= 0 and IsHandleValid(bodyId) and missile.desiredRot ~= nil then
            missile.lifeRemain = (missile.lifeRemain or 0.0) - (dt or 0.0)
            local currentRot = GetBodyTransform(bodyId).rot
            local bodyT = GetBodyTransform(bodyId)
            local currentPos = bodyT.pos
            local currentVel = GetBodyVelocity(bodyId)
            local currentSpeed = VecLength(currentVel)
            local fallbackDir = _sSlotNormalize(TransformToParentVec(bodyT, Vec(0, 0, -1)), Vec(0, 0, -1))
            local currentDir = _sSlotNormalize(currentVel, fallbackDir)
            local desiredDir = currentDir

            local targetBodyId = missile.targetBodyId or 0
            local targetVehicleId = missile.targetVehicleId or 0
            local targetPos = nil
            local targetVel = nil
            
            -- 优先使用body追踪
            if targetBodyId ~= 0 and IsHandleValid(targetBodyId) and server.registryShipExists(targetBodyId) and (not server.registryShipIsBodyDead(targetBodyId)) then
                targetPos = _sSlotGetBodyCenterWorld(targetBodyId)
                if targetPos ~= nil then
                    targetVel = GetBodyVelocity(targetBodyId)
                end
            -- 如果没有body或body无效，使用vehicle追踪
            elseif targetVehicleId ~= 0 then
                local targetBody = GetVehicleBody(targetVehicleId)
                if targetBody ~= nil and targetBody ~= 0 and IsHandleValid(targetBody) then
                    targetPos = _sSlotGetBodyCenterWorld(targetBody)
                    if targetPos ~= nil then
                        targetVel = GetBodyVelocity(targetBody)
                    end
                else
                    -- 直接使用vehicle的位置
                    local vehicleT = GetVehicleTransform(targetVehicleId)
                    if vehicleT ~= nil then
                        targetPos = vehicleT.pos
                        targetVel = GetVehicleVelocity(targetVehicleId)
                    end
                end
            end
            
            if targetPos ~= nil and targetVel ~= nil then
                local dist = VecLength(VecSub(targetPos, currentPos))
                local leadTime = math.min(1.0, dist / math.max(1.0, currentSpeed, missile.cruiseSpeed or 1.0))
                local leadPos = VecAdd(targetPos, VecScale(targetVel, leadTime))
                desiredDir = _sSlotNormalize(VecSub(leadPos, currentPos), currentDir)
            end

            local steerAlpha = math.min(1.0, math.max(0.0, (missile.turnBlendRate or 0.0) * (dt or 0.0)))
            local blendedDir = _sSlotNormalize(VecLerp(currentDir, desiredDir, steerAlpha), desiredDir)
            local targetSpeed = math.max(currentSpeed, missile.cruiseSpeed or 0.0)
            targetSpeed = math.min(missile.maxSpeed or targetSpeed, targetSpeed + (missile.acceleration or 0.0) * (dt or 0.0))
            local desiredVel = VecScale(blendedDir, targetSpeed)
            local probes = _sSlotGetProbePoints(bodyT)

            missile.prePhysicsCenterPos = Vec(probes.center[1], probes.center[2], probes.center[3])
            missile.prePhysicsHeadPos = Vec(probes.head[1], probes.head[2], probes.head[3])
            missile.prePhysicsMidPos = Vec(probes.mid[1], probes.mid[2], probes.mid[3])
            missile.desiredRot = QuatLookAt(currentPos, VecAdd(currentPos, blendedDir))

            SetBodyActive(bodyId, true)
            SetBodyVelocity(bodyId, desiredVel)
            ConstrainOrientation(
                bodyId,
                0,
                currentRot,
                missile.desiredRot,
                missile.turnRate or 0.0,
                missile.turnImpulse or 0.0
            )
        end
    end
end

function server.sSlotControlPostUpdate()
    local active = (server.sSlotState or {}).activeMissiles or {}
    local i = #active
    while i >= 1 do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId == 0 or not IsHandleValid(bodyId) then
            _sSlotRemoveMissileAt(i)
        else
            local bodyT = GetBodyTransform(bodyId)
            local probes = _sSlotGetProbePoints(bodyT)
            local preCenter = missile.prePhysicsCenterPos or probes.center
            missile.distanceTravelled = (missile.distanceTravelled or 0.0) + VecLength(VecSub(probes.center, preCenter))

            -- 向客户端发送导弹位置更新
            local currentPos = bodyT.pos
            local currentVel = GetBodyVelocity(bodyId)
            ClientCall(
                0,
                "client.updateMissileVisual",
                missile.id or 0,
                currentPos[1], currentPos[2], currentPos[3],
                currentVel[1], currentVel[2], currentVel[3]
            )

            local hit = _sSlotResolvePostPhysicsHit(missile, probes)
            if hit ~= nil then
                _sSlotHandleMissileHit(missile, hit.hitPos, hit.hitBody or 0)
                _sSlotRemoveMissileAt(i)
            elseif (missile.lifeRemain or 0.0) <= 0.0 or (missile.distanceTravelled or 0.0) >= (missile.maxRange or 0.0) then
                _sSlotRemoveMissileAt(i)
            end
        end

        i = i - 1
    end
end
