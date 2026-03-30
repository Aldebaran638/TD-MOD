---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.escortGSlotState = server.escortGSlotState or {
    nextMissileId = 1,
    nextLauncherIndex = 1,
    globalCooldownRemain = 0.0,
    requestFire = false,
    launchers = {},
    activeMissiles = {},
}

local _escortGProbeHeadLocal = Vec(0, 0, -3.2)
local _escortGProbeMidLocal = Vec(0, 0, -1.0)
local _escortGClosestPointDist = 0.14
local _escortGSweepRadius = 0.32

local function _escortGCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = tonumber(t.x) or defaultX or 0.0,
        y = tonumber(t.y) or defaultY or 0.0,
        z = tonumber(t.z) or defaultZ or 0.0,
    }
end

local function _escortGResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "riddle_escort"
    return defs[requested] or defs[server.defaultShipType] or defs.riddle_escort or {}
end

local function _escortGResolveWeaponDefinition(weaponType)
    local defs = escortGSlotWeaponRegistryData or {}
    local requested = weaponType or "devastatorTorpedoes"
    return defs[requested] or defs.devastatorTorpedoes or {}
end

local function _escortGNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _escortGGetBodyCenterWorld(bodyId)
    if bodyId == nil or bodyId == 0 or not IsHandleValid(bodyId) then
        return nil
    end
    local bodyT = GetBodyTransform(bodyId)
    local centerLocal = GetBodyCenterOfMass(bodyId)
    return TransformToParentPoint(bodyT, centerLocal)
end

local function _escortGGetProbePoints(bodyT)
    return {
        center = bodyT.pos,
        head = TransformToParentPoint(bodyT, _escortGProbeHeadLocal),
        mid = TransformToParentPoint(bodyT, _escortGProbeMidLocal),
    }
end

local function _escortGBuildLauncherConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "devastatorTorpedoes")
    local weaponDef = _escortGResolveWeaponDefinition(weaponType)
    return {
        weaponType = weaponType,
        firePosOffset = _escortGCloneVec3(slotDef and slotDef.firePosOffset, 0.0, 0.0, 0.0),
        fireDirRelative = _escortGCloneVec3(slotDef and slotDef.fireDirRelative, 0.0, 0.0, -1.0),
        fireInterval = tonumber(weaponDef.fireInterval) or 0.0,
        reloadTime = tonumber(weaponDef.reloadTime) or 0.0,
        prefabPath = tostring(weaponDef.prefabPath or ""),
        spawnForwardOffset = tonumber(weaponDef.spawnForwardOffset) or 0.0,
        muzzleSpeed = tonumber(weaponDef.muzzleSpeed) or 0.0,
        cruiseSpeed = tonumber(weaponDef.cruiseSpeed) or 0.0,
        maxSpeed = tonumber(weaponDef.maxSpeed) or 0.0,
        acceleration = tonumber(weaponDef.acceleration) or 0.0,
        lifetime = tonumber(weaponDef.lifetime) or 0.0,
        maxRange = tonumber(weaponDef.maxRange) or 0.0,
        damage = tonumber(weaponDef.damage) or 0.0,
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
        environmentExplosionRadius = tonumber(weaponDef.environmentExplosionRadius) or 4.0,
        targetShipTypeDamageMultiplier = weaponDef.targetShipTypeDamageMultiplier or {},
    }
end

local function _escortGBuildLauncherRuntime()
    return {
        reloadRemain = 0.0,
    }
end

local function _escortGPlayFireSound(firePos)
    local p = firePos or Vec(0, 0, 0)
    ClientCall(0, "client.playEscortGFireSound", p[1], p[2], p[3])
end

local function _escortGPlayImpactSound(hitPos)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playEscortGHitSound", p[1], p[2], p[3])
end

local function _escortGPlayImpactFx(hitPos, impactLayer)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileImpactFx", p[1], p[2], p[3], impactLayer or "body")
end

local function _escortGDeleteMissileBody(bodyId)
    if bodyId ~= nil and bodyId ~= 0 and IsHandleValid(bodyId) then
        Delete(bodyId)
    end
end

local function _escortGRemoveMissileAt(index)
    local active = server.escortGSlotState.activeMissiles or {}
    local missile = active[index]
    if missile ~= nil then
        _escortGDeleteMissileBody(missile.bodyId or 0)
        ClientCall(0, "client.finishMissileVisual", missile.id or 0)
    end

    local last = #active
    if index >= 1 and index <= last then
        active[index] = active[last]
        active[last] = nil
    end
end

local function _escortGClearAllMissiles()
    local active = server.escortGSlotState.activeMissiles or {}
    for i = #active, 1, -1 do
        _escortGDeleteMissileBody((active[i] or {}).bodyId or 0)
        active[i] = nil
    end
end

local function _escortGChooseLauncher(state)
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
        if runtime ~= nil and (runtime.reloadRemain or 0.0) <= 0.0 then
            state.nextLauncherIndex = (idx % count) + 1
            return launcher
        end
    end
    return nil
end

local function _escortGBuildBodyTransform(spawnPos, forwardDir)
    local eye = spawnPos or Vec(0, 0, 0)
    local target = VecAdd(eye, _escortGNormalize(forwardDir, Vec(0, 0, -1)))
    return Transform(eye, QuatLookAt(eye, target))
end

local function _escortGSpawnMissileBody(prefabPath, spawnPos, forwardDir)
    if prefabPath == nil or prefabPath == "" then
        return 0
    end
    local entities = Spawn(prefabPath, _escortGBuildBodyTransform(spawnPos, forwardDir), true, false) or {}
    for i = 1, #entities do
        local entityId = entities[i]
        if entityId ~= nil and entityId ~= 0 and GetEntityType(entityId) == "body" then
            return entityId
        end
    end
    return 0
end

local function _escortGResolveDamageMultiplier(multiplierMap, shipType)
    local exact = tonumber((multiplierMap or {})[shipType])
    if exact ~= nil then
        return exact
    end
    return 1.0
end

local function _escortGApplyShipDamage(hitBody, missile)
    if hitBody == nil or hitBody == 0 or not server.registryShipExists(hitBody) then
        return "none"
    end

    local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(hitBody) or (server.defaultShipType or "riddle_escort")
    local targetShieldHP, targetArmorHP, targetBodyHP = server.registryShipGetHP(hitBody)
    if targetShieldHP == nil or targetArmorHP == nil or targetBodyHP == nil then
        return "none"
    end

    local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[server.defaultShipType or "riddle_escort"]) or {}
    local rawRemain = (tonumber(missile.damage) or 0.0) * _escortGResolveDamageMultiplier(missile.targetShipTypeDamageMultiplier, targetShipType)
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

local function _escortGQueryClosestBody(missile, probePos, maxDist)
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

local function _escortGQuerySweepBody(missile, startPos, endPos, radius)
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

local function _escortGResolvePostPhysicsHit(missile, currentProbes)
    local previousHead = missile.prePhysicsHeadPos or currentProbes.head
    local previousMid = missile.prePhysicsMidPos or currentProbes.mid
    local previousCenter = missile.prePhysicsCenterPos or currentProbes.center

    local hit = _escortGQueryClosestBody(missile, currentProbes.head, _escortGClosestPointDist)
    if hit ~= nil then return hit end
    hit = _escortGQueryClosestBody(missile, currentProbes.mid, _escortGClosestPointDist)
    if hit ~= nil then return hit end
    hit = _escortGQuerySweepBody(missile, previousHead, currentProbes.head, _escortGSweepRadius)
    if hit ~= nil then return hit end
    hit = _escortGQuerySweepBody(missile, previousMid, currentProbes.mid, _escortGSweepRadius)
    if hit ~= nil then return hit end
    return _escortGQuerySweepBody(missile, previousCenter, currentProbes.center, _escortGSweepRadius)
end

local function _escortGHandleMissileHit(missile, hitPos, hitBody)
    local pos = hitPos or _escortGGetBodyCenterWorld(missile.bodyId) or Vec(0, 0, 0)
    local bodyId = hitBody or 0

    if bodyId ~= 0 and server.registryShipExists(bodyId) and not server.registryShipIsBodyDead(bodyId) then
        local impactLayer = _escortGApplyShipDamage(bodyId, missile)
        _escortGPlayImpactSound(pos)
        _escortGPlayImpactFx(pos, impactLayer ~= "none" and impactLayer or "armor")
        return
    end

    _escortGPlayImpactSound(pos)
    _escortGPlayImpactFx(pos, "environment")
    Explosion(pos, tonumber(missile.environmentExplosionRadius) or 4.0)
end

function server.escortGSlotStateInit(shipType)
    _escortGClearAllMissiles()

    local shipDef = _escortGResolveShipDefinition(shipType)
    local state = {
        nextMissileId = 1,
        nextLauncherIndex = 1,
        globalCooldownRemain = 0.0,
        requestFire = false,
        launchers = {},
        activeMissiles = {},
    }

    local slotDefs = shipDef.gSlots or {}
    for i = 1, #slotDefs do
        state.launchers[i] = {
            config = _escortGBuildLauncherConfig(slotDefs[i]),
            runtime = _escortGBuildLauncherRuntime(),
        }
    end

    server.escortGSlotState = state
    return state
end

function server.escortGSlotStateSetRequestFire(active)
    local state = server.escortGSlotState
    if state == nil then
        return
    end
    state.requestFire = active and true or false
end

function server.escortGSlotStateConsumeRequestFire()
    local state = server.escortGSlotState
    if state == nil then
        return false
    end
    local requested = state.requestFire and true or false
    state.requestFire = false
    return requested
end

function server.escortGSlotStateResetRuntime()
    local state = server.escortGSlotState or {}
    _escortGClearAllMissiles()
    state.nextMissileId = 1
    state.nextLauncherIndex = 1
    state.globalCooldownRemain = 0.0
    state.requestFire = false
    local launchers = state.launchers or {}
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil then
            runtime.reloadRemain = 0.0
        end
    end
end

function server.escortGSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end

    local state = server.escortGSlotState
    if state == nil then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.escortGSlotStateResetRuntime()
        return
    end

    local launchers = state.launchers or {}
    state.globalCooldownRemain = math.max(0.0, (state.globalCooldownRemain or 0.0) - (dt or 0.0))
    for i = 1, #launchers do
        local runtime = launchers[i] and launchers[i].runtime or nil
        if runtime ~= nil then
            runtime.reloadRemain = math.max(0.0, (runtime.reloadRemain or 0.0) - (dt or 0.0))
        end
    end

    server.escortGSlotControlSyncHud(false)

    local active = state.activeMissiles or {}
    local i = #active
    while i >= 1 do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId == 0 or not IsHandleValid(bodyId) then
            _escortGRemoveMissileAt(i)
        elseif _escortGGetBodyCenterWorld(bodyId) == nil then
            _escortGRemoveMissileAt(i)
        end
        i = i - 1
    end

    local requestFire = server.escortGSlotStateConsumeRequestFire()
    if not requestFire then
        return
    end
    if server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBody) ~= "gSlot" then
        return
    end
    if (state.globalCooldownRemain or 0.0) > 0.0 then
        return
    end

    local launcher = _escortGChooseLauncher(state)
    if launcher == nil then
        return
    end

    local launcherConfig = launcher.config or {}
    local launcherRuntime = launcher.runtime or {}
    local shipT = GetBodyTransform(shipBody)
    local fireLocal = Vec(launcherConfig.firePosOffset.x or 0.0, launcherConfig.firePosOffset.y or 0.0, launcherConfig.firePosOffset.z or 0.0)
    local fireDirLocal = Vec(launcherConfig.fireDirRelative.x or 0.0, launcherConfig.fireDirRelative.y or 0.0, launcherConfig.fireDirRelative.z or -1.0)
    local fireDirWorld = _escortGNormalize(TransformToParentVec(shipT, fireDirLocal), Vec(0, 0, -1))
    local firePosWorld = TransformToParentPoint(shipT, fireLocal)
    firePosWorld = VecAdd(firePosWorld, VecScale(fireDirWorld, launcherConfig.spawnForwardOffset or 0.0))

    local missileBody = _escortGSpawnMissileBody(launcherConfig.prefabPath, firePosWorld, fireDirWorld)
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
    ClientCall(0, "client.spawnMissileVisual", missileId, firePosWorld[1], firePosWorld[2], firePosWorld[3], startVelocity[1], startVelocity[2], startVelocity[3])

    local spawnedProbes = _escortGGetProbePoints(GetBodyTransform(missileBody))
    table.insert(active, {
        id = missileId,
        bodyId = missileBody,
        ownerShipBody = shipBody,
        damage = launcherConfig.damage or 0.0,
        armorFix = launcherConfig.armorFix or 1.0,
        bodyFix = launcherConfig.bodyFix or 1.0,
        cruiseSpeed = launcherConfig.cruiseSpeed or 0.0,
        maxSpeed = launcherConfig.maxSpeed or 0.0,
        acceleration = launcherConfig.acceleration or 0.0,
        maxRange = launcherConfig.maxRange or 0.0,
        lifeRemain = launcherConfig.lifetime or 0.0,
        distanceTravelled = 0.0,
        environmentExplosionRadius = launcherConfig.environmentExplosionRadius or 4.0,
        targetShipTypeDamageMultiplier = launcherConfig.targetShipTypeDamageMultiplier or {},
        prePhysicsCenterPos = Vec(spawnedProbes.center[1], spawnedProbes.center[2], spawnedProbes.center[3]),
        prePhysicsHeadPos = Vec(spawnedProbes.head[1], spawnedProbes.head[2], spawnedProbes.head[3]),
        prePhysicsMidPos = Vec(spawnedProbes.mid[1], spawnedProbes.mid[2], spawnedProbes.mid[3]),
        desiredRot = QuatLookAt(firePosWorld, VecAdd(firePosWorld, fireDirWorld)),
    })

    launcherRuntime.reloadRemain = math.max(0.0, launcherConfig.reloadTime or 0.0)
    state.globalCooldownRemain = math.max(0.0, launcherConfig.fireInterval or 0.0)
    _escortGPlayFireSound(firePosWorld)
end

function server.escortGSlotControlUpdate(dt)
    local active = (server.escortGSlotState or {}).activeMissiles or {}
    for i = 1, #active do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId ~= 0 and IsHandleValid(bodyId) and missile.desiredRot ~= nil then
            missile.lifeRemain = (missile.lifeRemain or 0.0) - (dt or 0.0)
            local bodyT = GetBodyTransform(bodyId)
            local currentPos = bodyT.pos
            local currentVel = GetBodyVelocity(bodyId)
            local currentSpeed = VecLength(currentVel)
            local fallbackDir = _escortGNormalize(TransformToParentVec(bodyT, Vec(0, 0, -1)), Vec(0, 0, -1))
            local currentDir = _escortGNormalize(currentVel, fallbackDir)
            local targetSpeed = math.max(currentSpeed, missile.cruiseSpeed or 0.0)
            targetSpeed = math.min(missile.maxSpeed or targetSpeed, targetSpeed + (missile.acceleration or 0.0) * (dt or 0.0))
            local desiredVel = VecScale(currentDir, targetSpeed)
            local probes = _escortGGetProbePoints(bodyT)

            missile.prePhysicsCenterPos = Vec(probes.center[1], probes.center[2], probes.center[3])
            missile.prePhysicsHeadPos = Vec(probes.head[1], probes.head[2], probes.head[3])
            missile.prePhysicsMidPos = Vec(probes.mid[1], probes.mid[2], probes.mid[3])
            missile.desiredRot = QuatLookAt(currentPos, VecAdd(currentPos, currentDir))

            SetBodyActive(bodyId, true)
            SetBodyVelocity(bodyId, desiredVel)
            ConstrainOrientation(bodyId, 0, bodyT.rot, missile.desiredRot, 8.0, 160.0)
        end
    end
end

function server.escortGSlotControlPostUpdate()
    local active = (server.escortGSlotState or {}).activeMissiles or {}
    local i = #active
    while i >= 1 do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId == 0 or not IsHandleValid(bodyId) then
            _escortGRemoveMissileAt(i)
        else
            local bodyT = GetBodyTransform(bodyId)
            local probes = _escortGGetProbePoints(bodyT)
            local preCenter = missile.prePhysicsCenterPos or probes.center
            missile.distanceTravelled = (missile.distanceTravelled or 0.0) + VecLength(VecSub(probes.center, preCenter))

            local currentPos = bodyT.pos
            local currentVel = GetBodyVelocity(bodyId)
            ClientCall(0, "client.updateMissileVisual", missile.id or 0, currentPos[1], currentPos[2], currentPos[3], currentVel[1], currentVel[2], currentVel[3])

            local hit = _escortGResolvePostPhysicsHit(missile, probes)
            if hit ~= nil then
                _escortGHandleMissileHit(missile, hit.hitPos, hit.hitBody or 0)
                _escortGRemoveMissileAt(i)
            elseif (missile.lifeRemain or 0.0) <= 0.0 or (missile.distanceTravelled or 0.0) >= (missile.maxRange or 0.0) then
                _escortGRemoveMissileAt(i)
            end
        end
        i = i - 1
    end
end

function server.escortGSlotControlSyncHud(force)
    local _ = force
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    local state = server.escortGSlotState or {}
    local launchers = state.launchers or {}
    local cd1, cd2, cd3 = 0.0, 0.0, 0.0
    local maxCd1, maxCd2, maxCd3 = 1.0, 1.0, 1.0
    for i = 1, 3 do
        local launcher = launchers[i]
        if launcher then
            local config = launcher.config or {}
            local runtime = launcher.runtime or {}
            if i == 1 then
                cd1 = runtime.reloadRemain or 0.0
                maxCd1 = config.reloadTime or 0.0
            elseif i == 2 then
                cd2 = runtime.reloadRemain or 0.0
                maxCd2 = config.reloadTime or 0.0
            elseif i == 3 then
                cd3 = runtime.reloadRemain or 0.0
                maxCd3 = config.reloadTime or 0.0
            end
        end
    end

    ClientCall(0, "client.updateEscortGHudState", shipBody, cd1, cd2, cd3, maxCd1, maxCd2, maxCd3)
end
