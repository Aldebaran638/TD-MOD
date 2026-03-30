---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.escortPProjectileManagerState = server.escortPProjectileManagerState or {
    nextId = 1,
    active = {},
}

local registryShipIndexRoot = "StellarisShips/server/ships/index"

local function _resolveEscortPProjectileWeaponSettings(weaponType)
    local defs = escortPSlotWeaponRegistryData or {}
    local resolvedWeaponType = weaponType or "naniteFlakBattery"
    return defs[resolvedWeaponType] or defs.naniteFlakBattery or {}
end

local function _safeNormalizeEscortPProjectile(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _segmentPointDistanceSqEscortP(a, b, p)
    local ab = VecSub(b, a)
    local abLenSq = VecDot(ab, ab)
    if abLenSq < 0.0001 then
        local ap = VecSub(p, a)
        return VecDot(ap, ap)
    end
    local t = VecDot(VecSub(p, a), ab) / abLenSq
    if t < 0.0 then
        t = 0.0
    elseif t > 1.0 then
        t = 1.0
    end
    local closest = VecAdd(a, VecScale(ab, t))
    local diff = VecSub(p, closest)
    return VecDot(diff, diff)
end

local function _segmentSphereEntryTEscortP(a, b, center, radius)
    local d = VecSub(b, a)
    local f = VecSub(a, center)
    local aa = VecDot(d, d)
    if aa < 0.000001 then
        return nil
    end
    local bb = 2.0 * VecDot(f, d)
    local cc = VecDot(f, f) - radius * radius
    local disc = bb * bb - 4.0 * aa * cc
    if disc < 0.0 then
        return nil
    end
    local root = math.sqrt(disc)
    local inv = 1.0 / (2.0 * aa)
    local t1 = (-bb - root) * inv
    local t2 = (-bb + root) * inv
    if t1 >= 0.0 and t1 <= 1.0 then
        return t1
    end
    if t2 >= 0.0 and t2 <= 1.0 then
        return t2
    end
    return nil
end

local function _escortPRemoveProjectileAt(index)
    local active = server.escortPProjectileManagerState.active
    local last = #active
    if index < 1 or index > last then
        return
    end
    active[index] = active[last]
    active[last] = nil
end

local function _escortPFinishProjectileVisual(projectileId, mode, hitPos)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.finishProjectileVisual", projectileId, mode or "none", p[1], p[2], p[3])
end

local function _escortPPlayProjectileFireSound(firePos)
    local p = firePos or Vec(0, 0, 0)
    ClientCall(0, "client.playEscortPFireSound", p[1], p[2], p[3])
end

local function _escortPPlayProjectileHitSound(hitPos)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playEscortPHitSound", p[1], p[2], p[3])
end

local function _escortPPlayShieldImpactFx(hitTargetBodyId, hitPos)
    local p = hitPos or Vec(0, 0, 0)
    ClientCall(0, "client.playProjectileShieldImpactFx", hitTargetBodyId or 0, p[1], p[2], p[3])
end

local function _escortPApplyProjectileShipDamage(hitBody, weaponType)
    if hitBody == nil or hitBody == 0 or not server.registryShipExists(hitBody) then
        return {
            didDamage = false,
            didHitShield = false,
            impactLayer = "none",
        }
    end

    local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(hitBody) or (server.defaultShipType or "riddle_escort")
    local targetShieldHP, targetArmorHP, targetBodyHP = server.registryShipGetHP(hitBody)
    if targetShieldHP == nil or targetArmorHP == nil or targetBodyHP == nil then
        return {
            didDamage = false,
            didHitShield = false,
            impactLayer = "none",
        }
    end

    local resolvedDefaultShipType = server.defaultShipType or "riddle_escort"
    local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[resolvedDefaultShipType]) or {}
    local weaponDataDef = _resolveEscortPProjectileWeaponSettings(weaponType)
    local rawRemain = weaponDataDef.damage or 0.0
    local result = {
        didDamage = false,
        didHitShield = false,
        impactLayer = "none",
    }

    local function _applyLayer(layerName, currentHp, damageFix)
        local hp = currentHp or 0.0
        local fix = damageFix or 1.0
        if hp <= 0 or rawRemain <= 0 or fix <= 0 then
            return hp
        end

        local potential = rawRemain * fix
        local consumedRaw = 0.0
        if potential < hp then
            hp = hp - potential
            consumedRaw = rawRemain
        else
            consumedRaw = hp / fix
            hp = 0.0
        end

        rawRemain = rawRemain - consumedRaw
        if rawRemain < 0 then
            rawRemain = 0
        end

        if result.impactLayer == "none" then
            result.impactLayer = layerName
        end
        if layerName == "shield" then
            result.didHitShield = true
        end
        result.didDamage = true
        return hp
    end

    targetShieldHP = _applyLayer("shield", targetShieldHP or 0.0, weaponDataDef.shieldFix)
    targetArmorHP = _applyLayer("armor", targetArmorHP or 0.0, weaponDataDef.armorFix)
    targetBodyHP = _applyLayer("body", targetBodyHP or 0.0, weaponDataDef.bodyFix)

    local maxShield = targetShipData.maxShieldHP or targetShieldHP or 0
    local maxArmor = targetShipData.maxArmorHP or targetArmorHP or 0
    local maxBody = targetShipData.maxBodyHP or targetBodyHP or 0
    if targetShieldHP > maxShield then targetShieldHP = maxShield end
    if targetArmorHP > maxArmor then targetArmorHP = maxArmor end
    if targetBodyHP > maxBody then targetBodyHP = maxBody end
    server.registryShipSetHP(hitBody, targetShieldHP, targetArmorHP, targetBodyHP)
    return result
end

local function _resolveEscortPShieldHit(projectile, startPos, endPos, settings)
    local bestHit = nil
    local count = GetInt(registryShipIndexRoot .. "/count")
    for i = 1, count do
        local bodyId = GetInt(registryShipIndexRoot .. "/" .. tostring(i) .. "/bodyId")
        if bodyId ~= nil and bodyId ~= 0 and bodyId ~= projectile.ownerShipBody and server.registryShipExists(bodyId) then
            local shieldHP, _, bodyHP = server.registryShipGetHP(bodyId)
            if shieldHP ~= nil and bodyHP ~= nil and bodyHP > 0 and shieldHP > 0 then
                local shieldRadius = 0.0
                if server.registryShipGetShieldRadius ~= nil then
                    shieldRadius = server.registryShipGetShieldRadius(bodyId, server.defaultShipType or "riddle_escort") or 0.0
                end
                if shieldRadius > 0.0 then
                    local bodyT = GetBodyTransform(bodyId)
                    local centerLocal = GetBodyCenterOfMass(bodyId)
                    local centerWorld = TransformToParentPoint(bodyT, centerLocal)
                    local coarseRadius = shieldRadius + (settings.projectileRadius or 0.0)
                    if _segmentPointDistanceSqEscortP(startPos, endPos, centerWorld) <= coarseRadius * coarseRadius then
                        local entryT = _segmentSphereEntryTEscortP(startPos, endPos, centerWorld, shieldRadius)
                        if entryT ~= nil and (bestHit == nil or entryT < bestHit.t) then
                            bestHit = {
                                t = entryT,
                                bodyId = bodyId,
                                hitPos = VecAdd(startPos, VecScale(VecSub(endPos, startPos), entryT)),
                            }
                        end
                    end
                end
            end
        end
    end
    return bestHit
end

local function _resolveEscortPBodyHit(projectile, startPos, endPos)
    local seg = VecSub(endPos, startPos)
    local segLen = VecLength(seg)
    if segLen < 0.0001 then
        return nil
    end

    local dir = VecScale(seg, 1.0 / segLen)
    QueryRequire("physical")
    QueryRejectBody(projectile.ownerShipBody)
    local hit, dist, normal, shape = QueryRaycast(startPos, dir, segLen)
    if not hit then
        return nil
    end

    local hitPos = VecAdd(startPos, VecScale(dir, dist))
    local hitBody = 0
    if shape ~= nil and shape ~= 0 then
        hitBody = GetShapeBody(shape) or 0
    end

    return {
        hitPos = hitPos,
        hitBody = hitBody,
        normal = normal or dir,
    }
end

function server.escortPProjectileManagerSpawnProjectile(ownerShipBody, weaponType, firePointWorld, fireDirWorld)
    local settings = _resolveEscortPProjectileWeaponSettings(weaponType)
    local dir = _safeNormalizeEscortPProjectile(fireDirWorld, Vec(0, 0, -1))
    local projectileId = server.escortPProjectileManagerState.nextId
    server.escortPProjectileManagerState.nextId = projectileId + 1

    local projectile = {
        id = projectileId,
        position = Vec(firePointWorld[1], firePointWorld[2], firePointWorld[3]),
        lastPosition = Vec(firePointWorld[1], firePointWorld[2], firePointWorld[3]),
        velocity = VecScale(dir, settings.projectileSpeed or 0.0),
        lifeRemain = settings.projectileLifetime or 0.0,
        ownerShipBody = ownerShipBody,
        weaponType = weaponType,
    }

    table.insert(server.escortPProjectileManagerState.active, projectile)
    _escortPPlayProjectileFireSound(projectile.position)
    ClientCall(
        0,
        "client.spawnProjectileVisual",
        projectileId,
        weaponType or "",
        projectile.position[1], projectile.position[2], projectile.position[3],
        projectile.velocity[1], projectile.velocity[2], projectile.velocity[3],
        projectile.lifeRemain
    )
    return projectileId
end

function server.escortPProjectileManagerTick(dt)
    local active = server.escortPProjectileManagerState.active
    local i = #active
    while i >= 1 do
        local projectile = active[i]
        local settings = _resolveEscortPProjectileWeaponSettings(projectile.weaponType)
        local stepDt = math.min(math.max(projectile.lifeRemain or 0.0, 0.0), math.max(dt or 0.0, 0.0))
        if stepDt <= 0.0 then
            _escortPFinishProjectileVisual(projectile.id, "none", projectile.position)
            _escortPRemoveProjectileAt(i)
        else
            projectile.lastPosition = Vec(projectile.position[1], projectile.position[2], projectile.position[3])
            projectile.position = VecAdd(projectile.position, VecScale(projectile.velocity, stepDt))
            projectile.lifeRemain = (projectile.lifeRemain or 0.0) - dt

            local shieldHit = _resolveEscortPShieldHit(projectile, projectile.lastPosition, projectile.position, settings)
            if shieldHit ~= nil then
                _escortPApplyProjectileShipDamage(shieldHit.bodyId, projectile.weaponType)
                _escortPFinishProjectileVisual(projectile.id, "impact", shieldHit.hitPos)
                _escortPPlayProjectileHitSound(shieldHit.hitPos)
                _escortPPlayShieldImpactFx(shieldHit.bodyId, shieldHit.hitPos)
                _escortPRemoveProjectileAt(i)
            else
                local bodyHit = _resolveEscortPBodyHit(projectile, projectile.lastPosition, projectile.position)
                if bodyHit ~= nil then
                    local shouldPlayImpact = false
                    local shouldExplode = false
                    local hitBody = bodyHit.hitBody or 0
                    if hitBody ~= 0 and server.registryShipExists(hitBody) then
                        if server.registryShipIsBodyDead(hitBody) then
                            shouldPlayImpact = true
                        else
                            local damageResult = _escortPApplyProjectileShipDamage(hitBody, projectile.weaponType)
                            if damageResult.didDamage then
                                shouldPlayImpact = true
                            end
                            if damageResult.didHitShield then
                                _escortPPlayShieldImpactFx(hitBody, bodyHit.hitPos)
                            end
                        end
                    else
                        shouldPlayImpact = true
                        shouldExplode = (tonumber(settings.explosionRadius) or 0.0) > 0.01
                    end

                    if shouldExplode then
                        Explosion(bodyHit.hitPos, settings.explosionRadius or 2.0)
                    end

                    if shouldPlayImpact then
                        _escortPPlayProjectileHitSound(bodyHit.hitPos)
                        _escortPFinishProjectileVisual(projectile.id, "impact", bodyHit.hitPos)
                    else
                        _escortPFinishProjectileVisual(projectile.id, "none", bodyHit.hitPos)
                    end
                    _escortPRemoveProjectileAt(i)
                elseif projectile.lifeRemain <= 0.0 then
                    _escortPFinishProjectileVisual(projectile.id, "none", projectile.position)
                    _escortPRemoveProjectileAt(i)
                end
            end
        end
        i = i - 1
    end
end
