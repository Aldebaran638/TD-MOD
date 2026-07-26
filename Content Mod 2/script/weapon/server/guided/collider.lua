---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local _guidedProjectileClosestPointDist = 0.14
local _guidedProjectileSweepRadius = 0.32

local function _guidedProjectileApplyShipDamage(hitBody, projectile)
    if hitBody == nil or hitBody == 0 or not server.registryShipExists(hitBody) then
        return "none"
    end

    local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(hitBody) or (server.defaultShipType or "enigmaticCruiser")
    local targetShieldHP, targetArmorHP, targetBodyHP = server.registryShipGetHP(hitBody)
    if targetShieldHP == nil or targetArmorHP == nil or targetBodyHP == nil then
        return "none"
    end

    local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[server.defaultShipType or "enigmaticCruiser"]) or {}
    local rawRemain = tonumber(projectile.damage) or 0.0
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
        if rawRemain < 0.0 then rawRemain = 0.0 end
        if impactLayer == "none" then impactLayer = layerName end
        return hp
    end

    targetShieldHP = _applyLayer("shield", targetShieldHP, projectile.shieldFix)
    targetArmorHP = _applyLayer("armor", targetArmorHP, projectile.armorFix)
    targetBodyHP = _applyLayer("body", targetBodyHP, projectile.bodyFix)

    local maxShield = tonumber(targetShipData.maxShieldHP) or targetShieldHP or 0.0
    local maxArmor = tonumber(targetShipData.maxArmorHP) or targetArmorHP or 0.0
    local maxBody = tonumber(targetShipData.maxBodyHP) or targetBodyHP or 0.0
    if targetShieldHP > maxShield then targetShieldHP = maxShield end
    if targetArmorHP > maxArmor then targetArmorHP = maxArmor end
    if targetBodyHP > maxBody then targetBodyHP = maxBody end
    server.registryShipSetHP(hitBody, targetShieldHP, targetArmorHP, targetBodyHP)
    return impactLayer
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

local function _guidedProjectileResolveHit(projectile, currentProbes)
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

local function _guidedProjectileHandleHit(projectile, hitPos, hitBody)
    local pos = hitPos or server.guidedProjectileGetBodyCenterWorld(projectile.bodyId) or Vec(0, 0, 0)
    local bodyId = hitBody or 0
    if bodyId ~= 0 and server.registryShipExists(bodyId) and not server.registryShipIsBodyDead(bodyId) then
        local impactLayer = _guidedProjectileApplyShipDamage(bodyId, projectile)
        server.guidedProjectilePlayImpactSound(projectile.weaponType, pos)
        server.guidedProjectilePlayImpactFx(pos, impactLayer ~= "none" and impactLayer or "body")
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
        else
            local bodyT = GetBodyTransform(bodyId)
            local probes = server.guidedProjectileGetProbePoints(bodyT)
            local preCenter = projectile.prePhysicsCenterPos or probes.center
            projectile.distanceTravelled = (projectile.distanceTravelled or 0.0) + VecLength(VecSub(probes.center, preCenter))

            local currentPos = bodyT.pos
            local currentVel = projectile.ignoreGravity
                and (projectile.kinematicVelocity or Vec(0, 0, 0))
                or GetBodyVelocity(bodyId)
            server.netClientCall(
                "missile.update",
                0,
                "client.updateMissileVisual",
                projectile.id or 0,
                currentPos[1], currentPos[2], currentPos[3],
                currentVel[1], currentVel[2], currentVel[3]
            )

            local hit = _guidedProjectileResolveHit(projectile, probes)
            if hit ~= nil then
                _guidedProjectileHandleHit(projectile, hit.hitPos, hit.hitBody or 0)
                server.guidedProjectileRemoveAt(i)
            elseif (projectile.lifeRemain or 0.0) <= 0.0 or (projectile.distanceTravelled or 0.0) >= (projectile.maxRange or 0.0) then
                server.guidedProjectileRemoveAt(i)
            end
        end
    end
end
