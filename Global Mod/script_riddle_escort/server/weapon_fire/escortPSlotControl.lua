---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local function _escortPSlotVec3TableToVec(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return Vec(t.x or defaultX or 0, t.y or defaultY or 0, t.z or defaultZ or 0)
end

local function _escortPSlotSafeNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _escortPSlotApplyFireDeviation(dir, deviationAngleDeg)
    local maxAngleDeg = math.max(0.0, tonumber(deviationAngleDeg) or 0.0)
    local forward = _escortPSlotSafeNormalize(dir, Vec(0, 0, -1))
    if maxAngleDeg <= 0.0001 then
        return forward
    end

    local tangent = VecSub(Vec(0, 1, 0), VecScale(forward, VecDot(Vec(0, 1, 0), forward)))
    if VecLength(tangent) < 0.0001 then
        tangent = VecSub(Vec(1, 0, 0), VecScale(forward, VecDot(Vec(1, 0, 0), forward)))
    end
    tangent = _escortPSlotSafeNormalize(tangent, Vec(1, 0, 0))
    local bitangent = _escortPSlotSafeNormalize(VecCross(forward, tangent), Vec(0, 0, 1))

    local maxAngleRad = math.rad(maxAngleDeg)
    local cosTheta = 1.0 - math.random() * (1.0 - math.cos(maxAngleRad))
    local sinTheta = math.sqrt(math.max(0.0, 1.0 - cosTheta * cosTheta))
    local phi = math.random() * math.pi * 2.0
    local lateral = VecAdd(VecScale(tangent, math.cos(phi)), VecScale(bitangent, math.sin(phi)))
    return _escortPSlotSafeNormalize(
        VecAdd(VecScale(forward, cosTheta), VecScale(lateral, sinTheta)),
        forward
    )
end

local function _resolveEscortPForwardAimPointLocal(shipBody, shipT, maxRange)
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

local function _computeEscortPFireDirLocal(slotConfig, forwardAimPointLocal)
    local mountPos = _escortPSlotVec3TableToVec(slotConfig.firePosOffset, 0, 0, -4)
    local defaultDir = _escortPSlotVec3TableToVec(slotConfig.fireDirRelative, 0, 0, -1)
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

local function _escortPUpdateSlotRuntime(slot, dt)
    local config = slot.config or {}
    local runtime = slot.runtime or {}

    runtime.heat = math.max(0.0, (runtime.heat or 0.0) - math.max(0.0, config.heatDissipationPerSecond or 0.0) * dt)
    runtime.cooldownRemain = math.max(0.0, (runtime.cooldownRemain or 0.0) - dt)

    local overheated = runtime.overheated and true or false
    local overheatThreshold = config.overheatThreshold or 0.0
    local recoverThreshold = config.recoverThreshold or 0.0
    if overheated and runtime.heat <= recoverThreshold then
        runtime.overheated = false
    elseif (not overheated) and overheatThreshold > 0.0 and runtime.heat >= overheatThreshold then
        runtime.overheated = true
    end
end

local function _escortPSlotGroupReady(state, group)
    local slots = (state and state.slots) or {}
    local slotIndices = (group and group.slotIndices) or {}
    local foundUsable = false
    for i = 1, #slotIndices do
        local slot = slots[slotIndices[i]] or {}
        local config = slot.config or {}
        local runtime = slot.runtime or {}
        local weaponType = tostring(config.weaponType or "none")
        if weaponType ~= "" and weaponType ~= "none" then
            foundUsable = true
            if (runtime.overheated and true or false) or (runtime.cooldownRemain or 0.0) > 0.0 then
                return false
            end
        end
    end
    return foundUsable
end

local function _escortPSlotResolveNextReadyGroup(state)
    local groups = (state and state.groups) or {}
    local groupCount = #groups
    if groupCount <= 0 then
        return nil, nil
    end
    local startIndex = math.max(1, math.min(state.nextGroupIndex or 1, groupCount))
    for offset = 0, groupCount - 1 do
        local idx = ((startIndex - 1 + offset) % groupCount) + 1
        local group = groups[idx]
        if _escortPSlotGroupReady(state, group) then
            return idx, group
        end
    end
    return nil, nil
end

local function _escortPSlotFindPrimarySlot(state, group)
    local slots = (state and state.slots) or {}
    local slotIndices = (group and group.slotIndices) or {}
    for i = 1, #slotIndices do
        local slot = slots[slotIndices[i]]
        if slot ~= nil and slot.config ~= nil and slot.runtime ~= nil then
            local weaponType = tostring(slot.config.weaponType or "none")
            if weaponType ~= "" and weaponType ~= "none" then
                return slot
            end
        end
    end
    return nil
end

function server.escortPSlotControlTick(dt)
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        server.escortPSlotStatePushHudReset(false)
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        server.escortPSlotStatePushHudReset(false)
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        server.escortPSlotStateSetRequestFire(false)
        server.escortPSlotStateResetRuntime()
        server.escortPSlotStatePushHudReset(true)
        return
    end

    local state = server.escortPSlotState
    local slots = (state and state.slots) or {}
    if #slots <= 0 then
        server.escortPSlotStatePushHudReset(false)
        return
    end

    for i = 1, #slots do
        _escortPUpdateSlotRuntime(slots[i], dt)
    end

    if not server.escortPSlotStateConsumeRequestFire() then
        server.escortPSlotStatePushHud(false)
        return
    end

    local currentMode = server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBody) or "pSlot"
    if currentMode ~= "pSlot" then
        server.escortPSlotStatePushHud(false)
        return
    end

    local selectedGroupIndex, selectedGroup = _escortPSlotResolveNextReadyGroup(state)
    if selectedGroupIndex == nil or selectedGroup == nil then
        server.escortPSlotStatePushHud(false)
        return
    end

    local shipT = GetBodyTransform(shipBody)
    local primarySlot = _escortPSlotFindPrimarySlot(state, selectedGroup)
    if primarySlot == nil then
        server.escortPSlotStatePushHud(false)
        return
    end

    local primaryConfig = primarySlot.config or {}
    local forwardAimPointLocal = _resolveEscortPForwardAimPointLocal(shipBody, shipT, math.max(1.0, primaryConfig.maxRange or 1.0))
    local fired = false
    local slotIndices = selectedGroup.slotIndices or {}
    for i = 1, #slotIndices do
        local slot = slots[slotIndices[i]] or {}
        local slotConfig = slot.config or {}
        local slotRuntime = slot.runtime or {}
        local slotWeaponType = slotConfig.weaponType or "none"
        if slotWeaponType ~= "" and slotWeaponType ~= "none"
            and (not (slotRuntime.overheated and true or false))
            and (slotRuntime.cooldownRemain or 0.0) <= 0.0 then
            local firePosOffset = _escortPSlotVec3TableToVec(slotConfig.firePosOffset, 0, 0, -4)
            local firePointWorld = TransformToParentPoint(shipT, firePosOffset)
            local fireDirLocal = _computeEscortPFireDirLocal(slotConfig, forwardAimPointLocal)
            local fireDirWorld = TransformToParentVec(shipT, fireDirLocal)
            fireDirWorld = _escortPSlotSafeNormalize(fireDirWorld, TransformToParentVec(shipT, Vec(0, 0, -1)))
            fireDirWorld = _escortPSlotApplyFireDeviation(fireDirWorld, slotConfig.fireDeviationAngle)
            if VecLength(fireDirWorld) >= 0.0001 then
                server.escortPProjectileManagerSpawnProjectile(shipBody, slotWeaponType, firePointWorld, fireDirWorld)
                fired = true
                slotRuntime.heat = (slotRuntime.heat or 0.0) + (slotConfig.heatPerShot or 0.0)
                slotRuntime.cooldownRemain = math.max(0.0, slotConfig.cooldown or 0.0)
                if (slotConfig.overheatThreshold or 0.0) > 0.0 and slotRuntime.heat >= (slotConfig.overheatThreshold or 0.0) then
                    slotRuntime.overheated = true
                end
            end
        end
    end

    if fired then
        local groupCount = #((state and state.groups) or {})
        if groupCount > 0 then
            state.nextGroupIndex = (selectedGroupIndex % groupCount) + 1
        end
    end
    server.escortPSlotStatePushHud(true)
end
