---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local _sSlotClosestPointDist = 0.14
local _sSlotSweepRadius = 0.32

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
    local pos = hitPos or server.sSlotGetBodyCenterWorld(missile.bodyId) or Vec(0, 0, 0)
    local bodyId = hitBody or 0

    if bodyId ~= 0 and server.registryShipExists(bodyId) and not server.registryShipIsBodyDead(bodyId) then
        local impactLayer = _sSlotApplyShipDamage(bodyId, missile)
        server.sSlotPlayImpactSound(pos)
        server.sSlotPlayImpactFx(pos, impactLayer ~= "none" and impactLayer or "body")
        return
    end

    if bodyId ~= 0 then
        server.sSlotPlayImpactSound(pos)
        Explosion(pos, 1.0)
    end
end

function server.sSlotColliderPostUpdate()
    local active = (server.sSlotState or {}).activeMissiles or {}
    local i = #active
    while i >= 1 do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId == 0 or not IsHandleValid(bodyId) then
            server.sSlotRemoveMissileAt(i)
        else
            local bodyT = GetBodyTransform(bodyId)
            local probes = server.sSlotGetProbePoints(bodyT)
            local preCenter = missile.prePhysicsCenterPos or probes.center
            missile.distanceTravelled = (missile.distanceTravelled or 0.0) + VecLength(VecSub(probes.center, preCenter))

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
                server.sSlotRemoveMissileAt(i)
            elseif (missile.lifeRemain or 0.0) <= 0.0 or (missile.distanceTravelled or 0.0) >= (missile.maxRange or 0.0) then
                server.sSlotRemoveMissileAt(i)
            end
        end

        i = i - 1
    end
end
