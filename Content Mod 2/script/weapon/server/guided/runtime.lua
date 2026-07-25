---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.guidedProjectileRuntimeState = server.guidedProjectileRuntimeState or {
    nextProjectileId = 1,
    activeProjectiles = {},
}

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
        ClientCall(0, "client.finishMissileVisual", projectile.id or 0)
    end

    local last = #active
    if index >= 1 and index <= last then
        active[index] = active[last]
        active[last] = nil
    end
end

function server.guidedProjectileClearAll()
    local active = server.guidedProjectileRuntimeState.activeProjectiles or {}
    for i = #active, 1, -1 do
        _guidedProjectileDeleteBody((active[i] or {}).bodyId or 0)
        active[i] = nil
    end
end

function server.guidedProjectilePlayImpactSound(hitPos)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileImpactSound", p[1], p[2], p[3])
end

function server.guidedProjectilePlayImpactFx(hitPos, impactLayer)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playMissileImpactFx", p[1], p[2], p[3], impactLayer or "body")
end

function server.guidedProjectileSpawn(ownerShipBody, groupMode, config, firePosWorld, fireDirWorld, targetBodyId, targetVehicleId)
    local cfg = config or {}
    local dir = server.guidedProjectileNormalize(fireDirWorld, Vec(0, 0, -1))
    local bodyId = _guidedProjectileSpawnBody(tostring(cfg.prefabPath or ""), firePosWorld, dir)
    if bodyId == nil or bodyId == 0 then
        return nil
    end

    SetBodyDynamic(bodyId, true)
    SetBodyActive(bodyId, true)
    local ownerVelocity = GetBodyVelocity(ownerShipBody)
    local startVelocity = VecAdd(ownerVelocity, VecScale(dir, tonumber(cfg.muzzleSpeed) or 0.0))
    SetBodyVelocity(bodyId, startVelocity)

    local state = server.guidedProjectileRuntimeState
    local projectileId = state.nextProjectileId or 1
    state.nextProjectileId = projectileId + 1

    ClientCall(
        0,
        "client.spawnMissileVisual",
        projectileId,
        firePosWorld[1], firePosWorld[2], firePosWorld[3],
        startVelocity[1], startVelocity[2], startVelocity[3]
    )
    ClientCall(0, "client.spawnMissileWarpFx", firePosWorld[1], firePosWorld[2], firePosWorld[3])
    ClientCall(0, "client.playMissileFireSound", firePosWorld[1], firePosWorld[2], firePosWorld[3])

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
        armorFix = tonumber(cfg.armorFix) or 1.0,
        bodyFix = tonumber(cfg.bodyFix) or 1.0,
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
    }
    table.insert(state.activeProjectiles, projectile)
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
end
