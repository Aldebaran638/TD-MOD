---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local function _escortSSlotVec3TableToVec(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return Vec(t.x or defaultX or 0, t.y or defaultY or 0, t.z or defaultZ or 0)
end

local function _escortSSlotSafeNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _escortSSlotApplyRandomTrajectory(dir, angleDeg)
    local maxAngleDeg = math.max(0.0, tonumber(angleDeg) or 0.0)
    local forward = _escortSSlotSafeNormalize(dir, Vec(0, 0, -1))
    if maxAngleDeg <= 0.0001 then
        return forward
    end

    local tangent = VecSub(Vec(0, 1, 0), VecScale(forward, VecDot(Vec(0, 1, 0), forward)))
    if VecLength(tangent) < 0.0001 then
        tangent = VecSub(Vec(1, 0, 0), VecScale(forward, VecDot(Vec(1, 0, 0), forward)))
    end
    tangent = _escortSSlotSafeNormalize(tangent, Vec(1, 0, 0))
    local bitangent = _escortSSlotSafeNormalize(VecCross(forward, tangent), Vec(0, 0, 1))

    local maxAngleRad = math.rad(maxAngleDeg)
    local cosTheta = 1.0 - math.random() * (1.0 - math.cos(maxAngleRad))
    local sinTheta = math.sqrt(math.max(0.0, 1.0 - cosTheta * cosTheta))
    local phi = math.random() * math.pi * 2.0
    local lateral = VecAdd(VecScale(tangent, math.cos(phi)), VecScale(bitangent, math.sin(phi)))
    return _escortSSlotSafeNormalize(
        VecAdd(VecScale(forward, cosTheta), VecScale(lateral, sinTheta)),
        forward
    )
end

local function _resolveEscortSSlotWeaponSettings(weaponType)
    local defs = weaponData or {}
    local resolvedWeaponType = weaponType or "gammaLaser"
    return defs[resolvedWeaponType] or defs.gammaLaser or {}
end

local function _resolveEscortSTargetShieldRadius(targetBody, fallbackShipType)
    local radiusFallback = 7.0
    local fallbackType = fallbackShipType or "riddle_escort"
    local fallbackShipData = (shipData and shipData[fallbackType]) or (shipData and shipData.riddle_escort) or {}
    if fallbackShipData.shieldRadius ~= nil then
        radiusFallback = fallbackShipData.shieldRadius
    end

    if targetBody == nil or targetBody == 0 then
        return radiusFallback
    end

    if server.registryShipGetShieldRadius ~= nil then
        local radius = server.registryShipGetShieldRadius(targetBody, fallbackType) or 0.0
        if radius > 0.0 then
            return radius
        end
    end

    local targetType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(targetBody) or fallbackType
    local targetTypeData = (shipData and shipData[targetType]) or (shipData and shipData[fallbackType]) or {}
    return tonumber(targetTypeData.shieldRadius) or radiusFallback
end

local function _resolveEscortSForwardAimPointLocal(shipBody, shipT, maxRange)
    if shipBody == nil or shipBody == 0 then
        return nil
    end
    local rayOriginLocal = Vec(0, 0, -2)
    local rayDirLocal = Vec(0, 0, -1)
    local rayOriginWorld = TransformToParentPoint(shipT, rayOriginLocal)
    local rayDirWorld = TransformToParentVec(shipT, rayDirLocal)
    local rayDirLen = VecLength(rayDirWorld)
    if rayDirLen < 0.0001 then
        return nil
    end
    rayDirWorld = VecScale(rayDirWorld, 1.0 / rayDirLen)

    QueryRequire("physical")
    QueryRejectBody(shipBody)
    local hit, hitDist = QueryRaycast(rayOriginWorld, rayDirWorld, maxRange)
    if not hit then
        return nil
    end

    local hitPointWorld = VecAdd(rayOriginWorld, VecScale(rayDirWorld, hitDist))
    return TransformToLocalPoint(shipT, hitPointWorld)
end

local function _computeEscortSFireDirLocal(slotConfig, forwardAimPointLocal)
    local mountPos = _escortSSlotVec3TableToVec(slotConfig.firePosOffset, 0, 0, -4)
    local defaultDir = _escortSSlotVec3TableToVec(slotConfig.fireDirRelative, 0, 0, -1)
    local aimMode = slotConfig.aimMode or "fixed"

    if forwardAimPointLocal ~= nil then
        local dirToAimPoint = VecSub(forwardAimPointLocal, mountPos)
        local dirToAimPointLen = VecLength(dirToAimPoint)
        if dirToAimPointLen >= 0.0001 then
            return VecScale(dirToAimPoint, 1.0 / dirToAimPointLen)
        end
    end

    if aimMode ~= "forwardConvergeByRange" then
        return defaultDir
    end

    local maxRange = math.max(1.0, slotConfig.maxRange or 1.0)
    local offsetX = mountPos[1] or 0.0
    local offsetY = mountPos[2] or 0.0
    local horizontal = math.sqrt(math.max(0.0, maxRange * maxRange - offsetX * offsetX))
    local aimPoint = Vec(0, offsetY, -horizontal)
    local dir = VecSub(aimPoint, mountPos)
    local dirLen = VecLength(dir)
    if dirLen < 0.0001 then
        return defaultDir
    end

    return VecScale(dir, 1.0 / dirLen)
end

local function _escortSSlotChooseReadySlot(state)
    local slots = (state and state.slots) or {}
    local count = #slots
    if count <= 0 then
        return nil, nil
    end

    local startIndex = math.max(1, math.min(count, math.floor(state.nextSlotIndex or 1)))
    for offset = 0, count - 1 do
        local idx = ((startIndex - 1 + offset) % count) + 1
        local slot = slots[idx]
        local runtime = (slot or {}).runtime or {}
        local config = (slot or {}).config or {}
        if tostring(config.weaponType or "none") ~= "none" and (runtime.cooldownRemain or 0.0) <= 0.0 then
            return idx, slot
        end
    end
    return nil, nil
end

function server.escortSSlot_computeHitResult(shipBodyId, firePosOffset, fireDirRelative, weaponType)
    local function _raySphereEntryT(origin, dirUnit, center, radius)
        local oc = VecSub(origin, center)
        local b = 2.0 * VecDot(oc, dirUnit)
        local c = VecDot(oc, oc) - radius * radius
        local disc = b * b - 4.0 * c
        if disc < 0.0 then
            return nil
        end
        local s = math.sqrt(disc)
        local t1 = (-b - s) * 0.5
        local t2 = (-b + s) * 0.5
        if t1 >= 0.0 then return t1 end
        if t2 >= 0.0 then return t2 end
        return nil
    end

    if shipBodyId == nil or shipBodyId == 0 or firePosOffset == nil or fireDirRelative == nil then
        return Vec(0, 0, 0), 0, false, false, Vec(0, 1, 0)
    end

    local shipT = GetBodyTransform(shipBodyId)
    local origin = TransformToParentPoint(shipT, firePosOffset)
    local dir = TransformToParentVec(shipT, fireDirRelative)
    dir = _escortSSlotSafeNormalize(dir, TransformToParentVec(shipT, Vec(0, 0, -1)))

    local weaponSettings = _resolveEscortSSlotWeaponSettings(weaponType)
    local maxRange = math.max(1.0, tonumber(weaponSettings.maxRange) or 1.0)

    QueryRequire("physical")
    QueryRejectBody(shipBodyId)
    local hit, dist, normal, shape = QueryRaycast(origin, dir, maxRange)
    if not hit then
        return VecAdd(origin, VecScale(dir, maxRange)), 0, false, false, dir
    end

    local endPos = VecAdd(origin, VecScale(dir, dist))
    if shape == nil or shape == 0 then
        return endPos, 0, true, false, normal or dir
    end

    local targetBody = GetShapeBody(shape)
    if targetBody ~= nil and targetBody ~= 0 and server.registryShipExists(targetBody) then
        local bodyT = GetBodyTransform(targetBody)
        local comLocal = GetBodyCenterOfMass(targetBody)
        local center = TransformToParentPoint(bodyT, comLocal)
        local shieldRadius = _resolveEscortSTargetShieldRadius(targetBody, server.defaultShipType or "riddle_escort")
        local entryT = _raySphereEntryT(origin, dir, center, shieldRadius)
        if entryT ~= nil and entryT <= maxRange then
            endPos = VecAdd(origin, VecScale(dir, entryT))
        end
        return endPos, targetBody, true, true, normal or dir
    end

    return endPos, 0, true, false, normal or dir
end

function server.escortSSlot_applyHitResult(endPos, hitTarget, isHit, isHitStellarisBody, weaponType)
    local renderResult = {
        didHitShield = false,
        impactLayer = "none",
    }
    if not isHit then
        return renderResult
    end

    if isHitStellarisBody then
        local resolvedDefaultShipType = server.defaultShipType or "riddle_escort"
        if not server.registryShipEnsure(hitTarget, resolvedDefaultShipType, resolvedDefaultShipType) then
            return renderResult
        end
        if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(hitTarget) then
            renderResult.impactLayer = "environment"
            return renderResult
        end

        local targetShipType = server.registryShipGetShipType ~= nil and server.registryShipGetShipType(hitTarget) or resolvedDefaultShipType
        local targetShieldHP, targetArmorHP, targetBodyHP = server.registryShipGetHP(hitTarget)
        if targetShieldHP == nil or targetArmorHP == nil or targetBodyHP == nil then
            return renderResult
        end

        local targetShipData = (shipData and shipData[targetShipType]) or (shipData and shipData[resolvedDefaultShipType]) or {}
        local targetWeaponData = _resolveEscortSSlotWeaponSettings(weaponType)
        local damageMin = tonumber(targetWeaponData.damageMin) or 0
        local damageMax = tonumber(targetWeaponData.damageMax) or damageMin
        if damageMax < damageMin then
            damageMax = damageMin
        end

        local rawRemain = damageMin
        if damageMax > damageMin then
            rawRemain = math.random(damageMin, damageMax)
        end

        local function _applyLayerOverflow(layerName, currentHp, damageFix)
            local hp = currentHp or 0
            local fix = tonumber(damageFix) or 1.0
            if hp <= 0 or rawRemain <= 0 or fix <= 0 then
                return hp
            end

            local potential = rawRemain * fix
            local consumedRaw = 0
            if potential < hp then
                hp = hp - potential
                consumedRaw = rawRemain
            else
                consumedRaw = hp / fix
                hp = 0
            end

            rawRemain = math.max(0.0, rawRemain - consumedRaw)
            if renderResult.impactLayer == "none" then
                renderResult.impactLayer = layerName
            end
            if layerName == "shield" then
                renderResult.didHitShield = true
            end
            return hp
        end

        targetShieldHP = _applyLayerOverflow("shield", targetShieldHP or 0, targetWeaponData.shieldFix)
        targetArmorHP = _applyLayerOverflow("armor", targetArmorHP or 0, targetWeaponData.armorFix)
        targetBodyHP = _applyLayerOverflow("body", targetBodyHP or 0, targetWeaponData.bodyFix)

        local maxShield = tonumber(targetShipData.maxShieldHP) or targetShieldHP or 0
        local maxArmor = tonumber(targetShipData.maxArmorHP) or targetArmorHP or 0
        local maxBody = tonumber(targetShipData.maxBodyHP) or targetBodyHP or 0
        if targetShieldHP > maxShield then targetShieldHP = maxShield end
        if targetArmorHP > maxArmor then targetArmorHP = maxArmor end
        if targetBodyHP > maxBody then targetBodyHP = maxBody end
        server.registryShipSetHP(hitTarget, targetShieldHP, targetArmorHP, targetBodyHP)
        return renderResult
    else
        -- 对于非群星body，伽马激光和高射炮产生小型爆炸
        local weaponSettings = _resolveEscortSSlotWeaponSettings(weaponType)
        if weaponType == "gammaLaser" or weaponType == "flakCannon" then
            Explosion(endPos, 0.1)  -- 0.1半径的小型爆炸
        end
        renderResult.impactLayer = "environment"
        return renderResult
    end
end

local function _escortSSlotBroadcastLaunch(shipBodyId, slotIndex, weaponType, firePointWorld, hitPointWorld, renderHitResult, hitTarget, isHit, isHitStellarisBody, normal)
    server.escortSSlotRenderPushEvent(shipBodyId, {
        eventType = "launch_start",
        slotIndex = slotIndex,
        weaponType = weaponType,
        firePoint = firePointWorld,
        hitPoint = hitPointWorld,
        didHit = isHit,
        didHitStellarisBody = isHitStellarisBody,
        didHitShield = renderHitResult.didHitShield,
        hitTargetBodyId = hitTarget or 0,
        normal = normal or Vec(0, 1, 0),
        impactLayer = renderHitResult.impactLayer or "none",
        incrementShotId = 1,
    })
end

function server.escortSSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end

    local state = server.escortSSlotState
    local slots = (state and state.slots) or {}
    if #slots <= 0 then
        return
    end

    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.escortSSlotStateResetRuntime()
        server.escortSSlotStatePushHud(true)
        return
    end

    for i = 1, #slots do
        local runtime = (slots[i] or {}).runtime or {}
        runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - (dt or 0.0))
    end

    if not server.escortSSlotStateConsumeRequestFire() then
        server.escortSSlotStatePushHud(false)
        return
    end

    local currentMode = server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBody) or "sSlot"
    if currentMode ~= "sSlot" then
        server.escortSSlotStatePushHud(false)
        return
    end

    local slotIndex, slotEntry = _escortSSlotChooseReadySlot(state)
    if slotIndex == nil or slotEntry == nil then
        server.escortSSlotStatePushHud(false)
        return
    end

    local shipT = GetBodyTransform(shipBody)
    local slotConfig = slotEntry.config or {}
    local slotRuntime = slotEntry.runtime or {}
    local firePosOffset = _escortSSlotVec3TableToVec(slotConfig.firePosOffset, 0, 0, -4)
    local forwardAimPointLocal = _resolveEscortSForwardAimPointLocal(shipBody, shipT, math.max(1.0, slotConfig.maxRange or 1.0))
    local fireDirLocal = _computeEscortSFireDirLocal(slotConfig, forwardAimPointLocal)
    local fireDirWorld = _escortSSlotSafeNormalize(TransformToParentVec(shipT, fireDirLocal), TransformToParentVec(shipT, Vec(0, 0, -1)))
    fireDirWorld = _escortSSlotApplyRandomTrajectory(fireDirWorld, slotConfig.randomTrajectoryAngle)
    local firePointWorld = TransformToParentPoint(shipT, firePosOffset)

    local endPos, hitTarget, isHit, isHitStellarisBody, normal = server.escortSSlot_computeHitResult(shipBody, firePosOffset, fireDirLocal, slotConfig.weaponType)
    local renderHitResult = server.escortSSlot_applyHitResult(endPos, hitTarget, isHit, isHitStellarisBody, slotConfig.weaponType)
    _escortSSlotBroadcastLaunch(shipBody, slotIndex, slotConfig.weaponType, firePointWorld, endPos, renderHitResult, hitTarget, isHit, isHitStellarisBody, normal)

    slotRuntime.cooldownRemain = math.max(0.0, tonumber(slotConfig.cooldown) or 0.0)
    state.nextSlotIndex = (slotIndex % #slots) + 1
    server.escortSSlotStatePushHud(true)
end
