---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.guidedProjectileRuntimeState = server.guidedProjectileRuntimeState or {
    nextProjectileId = 1,
    activeProjectiles = {},
}

server.projectileLimits = server.projectileLimits or {
    maxPerShip = 24,
    maxGlobal = 96,
}

local _guidedProjectileGlobalCountKey =
    "StellarisShips/server/runtime/activeMissiles"

local function _guidedProjectileGetGlobalCount()
    return math.max(0, GetInt(_guidedProjectileGlobalCountKey) or 0)
end

local function _guidedProjectileAdjustGlobalCount(delta)
    local nextCount = math.max(
        0,
        _guidedProjectileGetGlobalCount() + math.floor(delta or 0)
    )
    SetInt(_guidedProjectileGlobalCountKey, nextCount)
    return nextCount
end

server.guidedProjectileProbeHeadLocal = Vec(0, 0, -3.2)
server.guidedProjectileProbeMidLocal = Vec(0, 0, -1.0)

function server.guidedProjectileNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

function server.guidedProjectileGetBodyCenterWorld(bodyId)
    if bodyId == nil or bodyId == 0 or not IsHandleValid(bodyId) then
        return nil
    end
    local bodyT = GetBodyTransform(bodyId)
    return TransformToParentPoint(bodyT, GetBodyCenterOfMass(bodyId))
end

function server.guidedProjectileGetProbePoints(bodyT)
    return {
        center = bodyT.pos,
        head = TransformToParentPoint(bodyT, server.guidedProjectileProbeHeadLocal),
        mid = TransformToParentPoint(bodyT, server.guidedProjectileProbeMidLocal),
    }
end

local function _guidedProjectileBuildBodyTransform(spawnPos, forwardDir)
    local eye = spawnPos or Vec(0, 0, 0)
    local target = VecAdd(eye, server.guidedProjectileNormalize(forwardDir, Vec(0, 0, -1)))
    return Transform(eye, QuatLookAt(eye, target))
end

local function _guidedProjectileSpawnBody(prefabPath, spawnPos, forwardDir)
    if prefabPath == nil or prefabPath == "" then
        return 0
    end
    local entities = Spawn(prefabPath, _guidedProjectileBuildBodyTransform(spawnPos, forwardDir), true, false) or {}
    for i = 1, #entities do
        local entityId = entities[i]
        if entityId ~= nil and entityId ~= 0 and GetEntityType(entityId) == "body" then
            return entityId
        end
    end
    return 0
end

local function _guidedProjectileDeleteBody(bodyId)
    if bodyId ~= nil and bodyId ~= 0 and IsHandleValid(bodyId) then
        Delete(bodyId)
    end
end

function server.guidedProjectileRemoveAt(index)
    local active = server.guidedProjectileRuntimeState.activeProjectiles or {}
    local projectile = active[index]
    if projectile ~= nil then
        _guidedProjectileDeleteBody(projectile.bodyId or 0)
        server.netClientCall(
            "missile.finish",
            0,
            "client.finishMissileVisual",
            projectile.id or 0
        )
        _guidedProjectileAdjustGlobalCount(-1)
    end

    local last = #active
    if index >= 1 and index <= last then
        active[index] = active[last]
        active[last] = nil
    end
end

function server.guidedProjectileClearAll()
    local active = server.guidedProjectileRuntimeState.activeProjectiles or {}
    local removed = #active
    for i = #active, 1, -1 do
        _guidedProjectileDeleteBody((active[i] or {}).bodyId or 0)
        active[i] = nil
    end
    if removed > 0 then _guidedProjectileAdjustGlobalCount(-removed) end
end

function server.guidedProjectilePlayImpactSound(weaponType, hitPos)
    local p = hitPos or Vec(0, 0, 0)
    server.netClientCall(
        "weapon.hitFx",
        0,
        "client.playMissileImpactSound",
        weaponType or "",
        p[1], p[2], p[3]
    )
end

function server.guidedProjectilePlayImpactFx(weaponType, hitPos, hitNormal, impactLayer, hitTargetBodyId)
    local p = hitPos or Vec(0, 0, 0)
    local normal = hitNormal or Vec(0, 1, 0)
    server.netClientCall(
        "weapon.hitFx",
        0,
        "client.playMissileImpactFx",
        weaponType or "",
        p[1], p[2], p[3],
        normal[1], normal[2], normal[3],
        impactLayer or "body",
        math.floor(hitTargetBodyId or 0)
    )
end

function server.guidedProjectileSpawn(ownerShipBody, groupMode, config, firePosWorld, fireDirWorld, targetBodyId, targetVehicleId)
    local state = server.guidedProjectileRuntimeState
    local active = state.activeProjectiles or {}
    local maxPerShip = math.max(
        1,
        math.floor(server.projectileLimits.maxPerShip or 24)
    )
    if #active >= maxPerShip then
        local removeIndex = 1
        local shortestLife = math.huge
        for i = 1, #active do
            local life = tonumber((active[i] or {}).lifeRemain) or 0.0
            if life < shortestLife then
                shortestLife = life
                removeIndex = i
            end
        end
        server.guidedProjectileRemoveAt(removeIndex)
    end
    local maxGlobal = math.max(
        maxPerShip,
        math.floor(server.projectileLimits.maxGlobal or 96)
    )
    if _guidedProjectileGetGlobalCount() >= maxGlobal then return nil end

    local cfg = config or {}
    local dir = server.guidedProjectileNormalize(fireDirWorld, Vec(0, 0, -1))
    local bodyId = _guidedProjectileSpawnBody(tostring(cfg.prefabPath or ""), firePosWorld, dir)
    if bodyId == nil or bodyId == 0 then
        return nil
    end

    local ignoreGravity = cfg.ignoreGravity == true
        or ((cfg.projectileProfile or {}).ignoreGravity == true)
    SetBodyDynamic(bodyId, not ignoreGravity)
    SetBodyActive(bodyId, true)
    local ownerVelocity = GetBodyVelocity(ownerShipBody)
    local startVelocity = VecAdd(ownerVelocity, VecScale(dir, tonumber(cfg.muzzleSpeed) or 0.0))
    SetBodyVelocity(bodyId, startVelocity)

    local projectileId = state.nextProjectileId or 1
    state.nextProjectileId = projectileId + 1

    server.netClientCall(
        "missile.spawn",
        0,
        "client.spawnMissileVisual",
        projectileId,
        tostring(cfg.weaponType or ""),
        firePosWorld[1], firePosWorld[2], firePosWorld[3],
        startVelocity[1], startVelocity[2], startVelocity[3],
        tonumber(cfg.lifetime) or 10.0
    )
    server.netClientCall(
        "weapon.fireFx",
        0,
        "client.playMissileFireSound",
        tostring(cfg.weaponType or ""),
        firePosWorld[1], firePosWorld[2], firePosWorld[3]
    )
    server.netClientCall(
        "weapon.fireFx",
        0,
        "client.spawnWeaponMuzzleFx",
        tostring(cfg.weaponType or ""),
        firePosWorld[1], firePosWorld[2], firePosWorld[3],
        dir[1], dir[2], dir[3]
    )

    local probes = server.guidedProjectileGetProbePoints(GetBodyTransform(bodyId))
    local projectile = {
        id = projectileId,
        bodyId = bodyId,
        ownerShipBody = ownerShipBody,
        groupMode = tostring(groupMode or ""),
        weaponType = tostring(cfg.weaponType or ""),
        targetBodyId = math.floor(targetBodyId or 0),
        targetVehicleId = math.floor(targetVehicleId or 0),
        damage = tonumber(cfg.damage) or 0.0,
        shieldFix = tonumber(cfg.shieldFix) or 1.0,
        armorFix = tonumber(cfg.armorFix) or 1.0,
        bodyFix = tonumber(cfg.bodyFix) or 1.0,
        shieldPenetration = tonumber(cfg.shieldPenetration) or 0.0,
        armorPenetration = tonumber(cfg.armorPenetration) or 0.0,
        cruiseSpeed = tonumber(cfg.cruiseSpeed) or 0.0,
        maxSpeed = tonumber(cfg.maxSpeed) or 0.0,
        acceleration = tonumber(cfg.acceleration) or 0.0,
        maxRange = tonumber(cfg.maxRange) or 0.0,
        turnBlendRate = tonumber(cfg.turnBlendRate) or 0.0,
        turnRate = tonumber(cfg.turnRate) or 0.0,
        turnImpulse = tonumber(cfg.turnImpulse) or 0.0,
        lifeRemain = tonumber(cfg.lifetime) or 0.0,
        distanceTravelled = 0.0,
        prePhysicsCenterPos = Vec(probes.center[1], probes.center[2], probes.center[3]),
        prePhysicsHeadPos = Vec(probes.head[1], probes.head[2], probes.head[3]),
        prePhysicsMidPos = Vec(probes.mid[1], probes.mid[2], probes.mid[3]),
        desiredRot = QuatLookAt(firePosWorld, VecAdd(firePosWorld, dir)),
        ignoreGravity = ignoreGravity,
        kinematicVelocity = Vec(startVelocity[1], startVelocity[2], startVelocity[3]),
        syncInterval = 0.1,
        lastSyncAt = (GetTime ~= nil) and GetTime() or 0.0,
        lastSyncPos = Vec(
            firePosWorld[1],
            firePosWorld[2],
            firePosWorld[3]
        ),
        lastSyncVel = Vec(
            startVelocity[1],
            startVelocity[2],
            startVelocity[3]
        ),
    }
    table.insert(state.activeProjectiles, projectile)
    _guidedProjectileAdjustGlobalCount(1)
    return projectile
end

function server.guidedProjectileRuntimeInit()
    server.guidedProjectileClearAll()
    server.guidedProjectileRuntimeState = {
        nextProjectileId = 1,
        activeProjectiles = {},
    }
end

function server.guidedProjectileRuntimeTick(dt)
    local _ = dt
    local active = server.guidedProjectileRuntimeState.activeProjectiles or {}
    for i = #active, 1, -1 do
        local bodyId = (active[i] or {}).bodyId or 0
        if bodyId == 0 or not IsHandleValid(bodyId) then
            server.guidedProjectileRemoveAt(i)
        end
    end
    server.netDebugSetEntityCounts(#active, nil, nil)
end
