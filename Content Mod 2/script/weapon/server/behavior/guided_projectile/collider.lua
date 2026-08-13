---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local function _guidedProjectileVelocityAngleDegrees(a, b)
    local aLength = VecLength(a)
    local bLength = VecLength(b)
    if aLength < 0.0001 or bLength < 0.0001 then return 0.0 end
    local dot = VecDot(
        VecScale(a, 1.0 / aLength),
        VecScale(b, 1.0 / bLength)
    )
    dot = math.max(-1.0, math.min(1.0, dot))
    return math.deg(math.acos(dot))
end

local function _guidedProjectileMaybeSyncVisual(projectile, currentPos, currentVel)
    local now = (GetTime ~= nil) and GetTime() or 0.0
    local elapsed = now - (projectile.lastSyncAt or -1000.0)
    local interval = math.max(0.1, tonumber(projectile.syncInterval) or 0.1)
    if elapsed < interval then return end

    local lastPos = projectile.lastSyncPos or currentPos
    local lastVel = projectile.lastSyncVel or currentVel
    local positionChanged = VecLength(VecSub(currentPos, lastPos)) >= 1.0
    local speedChanged = math.abs(VecLength(currentVel) - VecLength(lastVel)) >= 2.0
    local directionChanged =
        _guidedProjectileVelocityAngleDegrees(currentVel, lastVel) >= 3.0
    local keepAlive = elapsed >= 1.0
    if not positionChanged and not speedChanged
        and not directionChanged and not keepAlive then
        return
    end

    server.netClientCall(
        "missile.update",
        0,
        "client.correctMissileVisual",
        projectile.id or 0,
        currentPos[1], currentPos[2], currentPos[3],
        currentVel[1], currentVel[2], currentVel[3],
        now
    )
    projectile.lastSyncAt = now
    projectile.lastSyncPos = Vec(currentPos[1], currentPos[2], currentPos[3])
    projectile.lastSyncVel = Vec(currentVel[1], currentVel[2], currentVel[3])
end

local _guidedProjectileClosestPointDist = 0.14
local _guidedProjectileSweepRadius = 0.32

local function _guidedProjectileApplyShipDamage(hitBody, projectile)
    if hitBody == nil or hitBody == 0 or not server.registryShipExists(hitBody) then
        return "none"
    end

    local result = server.shipDamageApplyWeaponDefinition(
        hitBody,
        projectile,
        server.weaponDamageRoll(projectile),
        projectile.ownerShipBody
    )
    return result.impactLayer
end

local function _guidedProjectileQueryClosestBody(projectile, probePos, maxDist)
    QueryRequire("physical")
    QueryRejectBody(projectile.bodyId)
    QueryRejectBody(projectile.ownerShipBody)
    local hit, point, normal, shape = QueryClosestPoint(probePos, maxDist)
    if not hit or shape == nil or shape == 0 then return nil end
    return { hitPos = point or probePos, hitBody = GetShapeBody(shape) or 0, normal = normal or Vec(0, 1, 0) }
end

local function _guidedProjectileQuerySweepBody(projectile, startPos, endPos, radius)
    local seg = VecSub(endPos, startPos)
    local segLen = VecLength(seg)
    if segLen < 0.0001 then return nil end
    QueryRequire("physical")
    QueryRejectBody(projectile.bodyId)
    QueryRejectBody(projectile.ownerShipBody)
    local dir = VecScale(seg, 1.0 / segLen)
    local hit, dist, normal, shape = QueryRaycast(startPos, dir, segLen, radius or 0.0)
    if not hit or shape == nil or shape == 0 then return nil end
    return { hitPos = VecAdd(startPos, VecScale(dir, dist)), hitBody = GetShapeBody(shape) or 0, normal = normal or dir }
end

local function _guidedProjectileTargetDistance(projectile, currentPos)
    local targetBodyId = math.floor(tonumber(projectile.targetBodyId) or 0)
    if targetBodyId ~= 0
        and IsHandleValid(targetBodyId)
        and server.guidedProjectileGetBodyCenterWorld ~= nil then
        local targetPos = server.guidedProjectileGetBodyCenterWorld(targetBodyId)
        if targetPos ~= nil then
            return VecLength(VecSub(targetPos, currentPos))
        end
    end
    local targetVehicleId = math.floor(tonumber(projectile.targetVehicleId) or 0)
    if targetVehicleId ~= 0 and GetVehicleTransform ~= nil then
        local vehicleTransform = GetVehicleTransform(targetVehicleId)
        if vehicleTransform ~= nil and vehicleTransform.pos ~= nil then
            return VecLength(VecSub(vehicleTransform.pos, currentPos))
        end
    end
    return math.huge
end

local function _guidedProjectileResolveBudgetedHit(projectile, currentProbes)
    if cm2GuidedCollisionBudgetV1 == nil
        or cm2GuidedCollisionBudgetV1.getDiagnostics == nil
        or cm2GuidedCollisionBudgetV1.plan == nil then
        return nil, false
    end
    local diagnostics = cm2GuidedCollisionBudgetV1.getDiagnostics()
    if diagnostics == nil or diagnostics.mode ~= "budgeted" then
        return nil, false
    end

    local now = (GetTime ~= nil) and GetTime() or 0.0
    local lastNow = tonumber(projectile.collisionLastTime)
    local frameDt = now - (lastNow or (now - (1.0 / 60.0)))
    if frameDt <= 0.0 or frameDt > 0.25 then frameDt = 1.0 / 60.0 end
    projectile.collisionLastTime = now

    local currentVel = projectile.ignoreGravity
        and (projectile.kinematicVelocity or Vec(0, 0, 0))
        or GetBodyVelocity(projectile.bodyId)
    local previousVel = projectile.collisionPreviousVelocity
    local turning = previousVel ~= nil
        and _guidedProjectileVelocityAngleDegrees(currentVel, previousVel) >= 12.0
    projectile.collisionPreviousVelocity = Vec(currentVel[1], currentVel[2], currentVel[3])

    local currentPos = currentProbes.center
    local targetDistance = _guidedProjectileTargetDistance(projectile, currentPos)
    local speed = VecLength(currentVel)
    local timeToImpact = targetDistance / math.max(1.0, speed)
    local firstContact = projectile.collisionFirstContact ~= false
    local projectileId = tostring(projectile.id or 0)
    local plan = cm2GuidedCollisionBudgetV1.plan(
        projectileId,
        projectile.collisionSeed or projectile.id or 0,
        frameDt,
        now,
        targetDistance,
        timeToImpact,
        speed,
        turning,
        firstContact
    )
    if plan == nil then
        cm2GuidedCollisionBudgetV1.recordPotentialMiss(projectileId)
        return nil, true
    end

    local previousCenter = projectile.prePhysicsCenterPos or currentPos
    local hit = nil
    if plan.doClosestPoint then
        hit = _guidedProjectileQueryClosestBody(
            projectile,
            currentProbes.head,
            _guidedProjectileClosestPointDist
        )
        projectile.collisionFirstContact = false
    end
    if hit == nil and plan.doSweep then
        hit = _guidedProjectileQuerySweepBody(
            projectile,
            previousCenter,
            currentPos,
            _guidedProjectileSweepRadius
        )
    end
    if hit ~= nil then
        cm2GuidedCollisionBudgetV1.recordHit(projectileId)
        return hit, true
    end
    if (tonumber(plan.queryCost) or 0) > 0 then
        cm2GuidedCollisionBudgetV1.recordPotentialMiss(projectileId)
    end
    return nil, true
end

local function _guidedProjectileResolveHit(projectile, currentProbes)
    local budgetedHit, budgeted = _guidedProjectileResolveBudgetedHit(projectile, currentProbes)
    if budgeted then return budgetedHit end
    local previousHead = projectile.prePhysicsHeadPos or currentProbes.head
    local previousMid = projectile.prePhysicsMidPos or currentProbes.mid
    local previousCenter = projectile.prePhysicsCenterPos or currentProbes.center
    local hit = _guidedProjectileQueryClosestBody(projectile, currentProbes.head, _guidedProjectileClosestPointDist)
    if hit ~= nil then return hit end
    hit = _guidedProjectileQueryClosestBody(projectile, currentProbes.mid, _guidedProjectileClosestPointDist)
    if hit ~= nil then return hit end
    hit = _guidedProjectileQuerySweepBody(projectile, previousHead, currentProbes.head, _guidedProjectileSweepRadius)
    if hit ~= nil then return hit end
    hit = _guidedProjectileQuerySweepBody(projectile, previousMid, currentProbes.mid, _guidedProjectileSweepRadius)
    if hit ~= nil then return hit end
    return _guidedProjectileQuerySweepBody(projectile, previousCenter, currentProbes.center, _guidedProjectileSweepRadius)
end

local function _guidedProjectileHandleHit(projectile, hitPos, hitBody, hitNormal)
    local pos = hitPos or server.guidedProjectileGetBodyCenterWorld(projectile.bodyId) or Vec(0, 0, 0)
    local bodyId = hitBody or 0
    if bodyId ~= 0 and server.registryShipExists(bodyId) and not server.registryShipIsBodyDead(bodyId) then
        local impactLayer = _guidedProjectileApplyShipDamage(bodyId, projectile)
        server.guidedProjectilePlayImpactSound(projectile.weaponType, pos)
        server.guidedProjectilePlayImpactFx(
            projectile.weaponType,
            pos,
            hitNormal,
            impactLayer ~= "none" and impactLayer or "body",
            bodyId
        )
        return
    end
    if bodyId ~= 0 then
        server.guidedProjectilePlayImpactSound(projectile.weaponType, pos)
        Explosion(pos, 1.0)
    end
end

function server.guidedProjectileColliderPostUpdate()
    local active = (server.guidedProjectileRuntimeState or {}).activeProjectiles or {}
    for i = #active, 1, -1 do
        local projectile = active[i]
        local bodyId = projectile and projectile.bodyId or 0
        if bodyId == 0 or not IsHandleValid(bodyId) then
            server.guidedProjectileRemoveAt(i)
        elseif server.guidedProjectileDestroyIfDeadAt(i) then
            -- Destroyed interceptors terminate before collision or range logic.
        else
            local bodyT = GetBodyTransform(bodyId)
            local probes = server.guidedProjectileGetProbePoints(bodyT)
            local preCenter = projectile.prePhysicsCenterPos or probes.center
            projectile.distanceTravelled = (projectile.distanceTravelled or 0.0) + VecLength(VecSub(probes.center, preCenter))

            local currentPos = bodyT.pos
            local currentVel = projectile.ignoreGravity
                and (projectile.kinematicVelocity or Vec(0, 0, 0))
                or GetBodyVelocity(bodyId)
            _guidedProjectileMaybeSyncVisual(projectile, currentPos, currentVel)

            local hit = _guidedProjectileResolveHit(projectile, probes)
            if hit ~= nil then
                _guidedProjectileHandleHit(projectile, hit.hitPos, hit.hitBody or 0, hit.normal)
                server.guidedProjectileRemoveAt(i)
            elseif (projectile.lifeRemain or 0.0) <= 0.0 or (projectile.distanceTravelled or 0.0) >= (projectile.maxRange or 0.0) then
                server.guidedProjectileRemoveAt(i)
            end
        end
    end
end
