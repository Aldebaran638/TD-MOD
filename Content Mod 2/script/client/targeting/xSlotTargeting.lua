---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotTargetingConfig = client.xSlotTargetingConfig or {
    lockDistance = 660.0,
    lockHalfAngleDeg = 8.0,
    lockAcquireTime = 1.4,
    lockLoseGraceTime = 0.25,
    lockBoxMinSizePx = 20.0,
    lockBoxMaxSizePx = 60.0,
    lockBoxScale = 2400.0,
}

client.xSlotTargetingState = client.xSlotTargetingState or {
    active = false,
    shipBody = 0,
    candidateVehicleId = 0,
    candidateBodyId = 0,
    lockedVehicleId = 0,
    lockedBodyId = 0,
    progress = 0.0,
    state = "idle",
    loseTimer = 0.0,
    targetWorldPos = nil,
    targetDistance = 0.0,
    lockCenterWorld = nil,
    isProjectedVisible = false,
}

local function _xSlotClamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function _xSlotResetState(state)
    state.active = false
    state.shipBody = 0
    state.candidateVehicleId = 0
    state.candidateBodyId = 0
    state.lockedVehicleId = 0
    state.lockedBodyId = 0
    state.progress = 0.0
    state.state = "idle"
    state.loseTimer = 0.0
    state.targetWorldPos = nil
    state.targetDistance = 0.0
    state.lockCenterWorld = nil
    state.isProjectedVisible = false
end

local function _xSlotClearTarget(state)
    state.candidateVehicleId = 0
    state.candidateBodyId = 0
    state.lockedVehicleId = 0
    state.lockedBodyId = 0
    state.progress = 0.0
    state.state = "idle"
    state.loseTimer = 0.0
    state.targetWorldPos = nil
    state.targetDistance = 0.0
    state.isProjectedVisible = false
end

local function _resolveControlledShipBody()
    if client.shipCameraGetControlledBody ~= nil then
        local body = client.shipCameraGetControlledBody()
        if body ~= nil and body ~= 0 then
            return body
        end
    end

    local veh = GetPlayerVehicle()
    if veh == nil or veh == 0 then
        return 0
    end

    local body = GetVehicleBody(veh)
    local scriptBody = client.shipBody or 0
    if body == nil or body == 0 or scriptBody == 0 or body ~= scriptBody then
        return 0
    end
    if client.registryShipExists ~= nil and (not client.registryShipExists(body)) then
        return 0
    end
    return body
end

local function _getBodyCenterWorld(bodyId)
    if bodyId == nil or bodyId == 0 then
        return nil
    end
    local bodyT = GetBodyTransform(bodyId)
    local centerLocal = GetBodyCenterOfMass(bodyId)
    return TransformToParentPoint(bodyT, centerLocal)
end

local function _getVehicleAimWorld(vehicleId)
    if vehicleId == nil or vehicleId == 0 then
        return nil, 0
    end
    local targetBody = GetVehicleBody(vehicleId)
    if targetBody ~= nil and targetBody ~= 0 then
        return _getBodyCenterWorld(targetBody), targetBody
    end
    local vehicleT = GetVehicleTransform(vehicleId)
    if vehicleT == nil then
        return nil, 0
    end
    return vehicleT.pos, 0
end

local function _getProjectedOffsetSq(worldPos, centerLocal, camT)
    local targetLocal = TransformToLocalPoint(camT, worldPos)
    if targetLocal[3] >= -0.01 then
        return nil
    end
    local centerDepth = -centerLocal[3]
    local targetDepth = -targetLocal[3]
    if centerDepth <= 0.01 or targetDepth <= 0.01 then
        return nil
    end
    local dx = (targetLocal[1] / targetDepth) - (centerLocal[1] / centerDepth)
    local dy = (targetLocal[2] / targetDepth) - (centerLocal[2] / centerDepth)
    return dx * dx + dy * dy
end

local function _safeNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _resolveXSlotFireOriginLocal(shipBody)
    local shipType = "enigmaticCruiser"
    if client.registryShipGetShipType ~= nil then
        local resolvedType = tostring(client.registryShipGetShipType(shipBody) or "")
        if resolvedType ~= "" then
            shipType = resolvedType
        end
    end

    local defs = shipTypeRegistryData or {}
    local shipDef = defs[shipType] or defs.enigmaticCruiser or {}
    local xSlots = shipDef.xSlots or {}
    local sx, sy, sz = 0.0, 0.0, 0.0
    local count = 0

    for i = 1, #xSlots do
        local slot = xSlots[i] or {}
        if tostring(slot.weaponType or "tachyonLance") == "tachyonLance" then
            local firePos = slot.firePosOffset or {}
            sx = sx + (tonumber(firePos.x) or 0.0)
            sy = sy + (tonumber(firePos.y) or 0.0)
            sz = sz + (tonumber(firePos.z) or -4.0)
            count = count + 1
        end
    end

    if count <= 0 then
        return Vec(0, 0, -4)
    end

    return Vec(sx / count, sy / count, sz / count)
end

local function _shipForwardAngleAllows(shipBody, targetPos, aimLimitDeg)
    local shipT = GetBodyTransform(shipBody)
    local fireOriginWorld = TransformToParentPoint(shipT, _resolveXSlotFireOriginLocal(shipBody))
    local shipForward = _safeNormalize(TransformToParentVec(shipT, Vec(0, 0, -1)), Vec(0, 0, -1))
    local toTarget = VecSub(targetPos, fireOriginWorld)
    local distance = VecLength(toTarget)
    if distance <= 0.001 then
        return false
    end
    local dir = VecScale(toTarget, 1.0 / distance)
    local minCos = math.cos(math.rad(math.max(0.0, aimLimitDeg or 0.0)))
    return VecDot(shipForward, dir) >= minCos
end

local function _resolveXSlotAimLimit(shipBody)
    local defs = weaponData or {}
    local xWeapon = defs.tachyonLance or {}
    return tonumber(xWeapon.aimLimitDeg) or 0.0
end

local function _evaluateVehicleTarget(vehicleId, shipBody, aimOrigin, aimForward, centerLocal, camT, cfg, aimLimitDeg)
    if vehicleId == nil or vehicleId == 0 then
        return nil
    end

    local ownVehicleId = GetBodyVehicle(shipBody)
    if ownVehicleId ~= nil and ownVehicleId ~= 0 and vehicleId == ownVehicleId then
        return nil
    end

    local targetPos, targetBody = _getVehicleAimWorld(vehicleId)
    if targetPos == nil then
        return nil
    end
    if targetBody ~= nil and targetBody ~= 0 and targetBody == shipBody then
        return nil
    end

    local toTarget = VecSub(targetPos, aimOrigin)
    local distance = VecLength(toTarget)
    if distance <= 0.001 or distance > (cfg.lockDistance or 0.0) then
        return nil
    end

    local dir = VecScale(toTarget, 1.0 / distance)
    local minCos = math.cos(math.rad(cfg.lockHalfAngleDeg or 0.0))
    if VecDot(aimForward, dir) < minCos then
        return nil
    end
    if not _shipForwardAngleAllows(shipBody, targetPos, aimLimitDeg) then
        return nil
    end

    local offsetSq = _getProjectedOffsetSq(targetPos, centerLocal, camT)
    if offsetSq == nil then
        return nil
    end

    return {
        vehicleId = vehicleId,
        bodyId = targetBody or 0,
        targetPos = targetPos,
        distance = distance,
        score = offsetSq,
    }
end

local function _findBestVehicleTarget(shipBody, aimOrigin, aimForward, centerLocal, camT, cfg, aimLimitDeg)
    local vehicles = FindVehicles("", true) or {}
    local best = nil
    for i = 1, #vehicles do
        local entry = _evaluateVehicleTarget(vehicles[i], shipBody, aimOrigin, aimForward, centerLocal, camT, cfg, aimLimitDeg)
        if entry ~= nil and (best == nil or entry.score < best.score) then
            best = entry
        end
    end
    return best
end

local function _resolveStickyTarget(state, shipBody, aimOrigin, aimForward, centerLocal, camT, cfg, aimLimitDeg)
    local stickyVehicleId = 0
    if state.state == "locked" and state.lockedVehicleId ~= 0 then
        stickyVehicleId = state.lockedVehicleId
    elseif state.candidateVehicleId ~= 0 then
        stickyVehicleId = state.candidateVehicleId
    end

    if stickyVehicleId ~= 0 then
        local sticky = _evaluateVehicleTarget(stickyVehicleId, shipBody, aimOrigin, aimForward, centerLocal, camT, cfg, aimLimitDeg)
        if sticky ~= nil then
            return sticky
        end
    end
    return _findBestVehicleTarget(shipBody, aimOrigin, aimForward, centerLocal, camT, cfg, aimLimitDeg)
end

function client.xSlotTargetingTick(dt)
    local state = client.xSlotTargetingState
    local cfg = client.xSlotTargetingConfig
    local shipBody = _resolveControlledShipBody()
    local currentMode = (client.getShipMainWeaponMode ~= nil and shipBody ~= 0) and client.getShipMainWeaponMode(shipBody) or "xSlot"
    local fireMode = (client.getShipXSlotFireMode ~= nil and shipBody ~= 0) and client.getShipXSlotFireMode(shipBody) or "aim"
    if shipBody == 0 or currentMode ~= "xSlot" or fireMode ~= "lock" then
        _xSlotResetState(state)
        return
    end

    state.active = true
    state.shipBody = shipBody

    local shipT = GetBodyTransform(shipBody)
    local shipPos = shipT.pos
    local shipForward = _safeNormalize(TransformToParentVec(shipT, Vec(0, 0, -1)), Vec(0, 0, -1))
    local camT = GetCameraTransform()
    local camPos = camT.pos
    local camForward = _safeNormalize(TransformToParentVec(camT, Vec(0, 0, -1)), shipForward)
    local useCameraCone = client.shipCamera ~= nil and (client.shipCamera.rearFreelookActive or client.shipCamera.frontFreelookActive)

    local aimOrigin = shipPos
    local aimForward = shipForward
    if useCameraCone then
        aimOrigin = camPos
        aimForward = camForward
    end

    local centerDistance = math.max(12.0, math.min(cfg.lockDistance or 220.0, 100.0))
    local centerWorld = nil
    if useCameraCone then
        centerWorld = VecAdd(aimOrigin, VecScale(aimForward, centerDistance))
    elseif client.shipCrosshairGetAimWorldPoint ~= nil then
        centerWorld = client.shipCrosshairGetAimWorldPoint(shipBody)
    end
    if centerWorld == nil then
        centerWorld = VecAdd(aimOrigin, VecScale(aimForward, centerDistance))
    end
    local centerLocal = TransformToLocalPoint(camT, centerWorld)
    if centerLocal[3] >= -0.01 then
        centerLocal = Vec(0, 0, -1)
    end
    state.lockCenterWorld = centerWorld

    local aimLimitDeg = _resolveXSlotAimLimit(shipBody)
    local target = _resolveStickyTarget(state, shipBody, aimOrigin, aimForward, centerLocal, camT, cfg, aimLimitDeg)
    if target == nil then
        if state.candidateVehicleId ~= 0 or state.lockedVehicleId ~= 0 then
            state.loseTimer = state.loseTimer + (dt or 0.0)
            if state.loseTimer > (cfg.lockLoseGraceTime or 0.0) then
                _xSlotClearTarget(state)
            end
        else
            _xSlotClearTarget(state)
        end
        return
    end

    state.loseTimer = 0.0
    state.targetWorldPos = target.targetPos
    state.targetDistance = target.distance
    state.isProjectedVisible = true

    local changedTarget = target.vehicleId ~= state.candidateVehicleId
    if changedTarget then
        state.candidateVehicleId = target.vehicleId
        state.candidateBodyId = target.bodyId
        state.lockedVehicleId = 0
        state.lockedBodyId = 0
        state.progress = 0.0
        state.state = "acquiring"
    elseif state.state == "locked" then
        state.lockedVehicleId = target.vehicleId
        state.lockedBodyId = target.bodyId
    else
        local acquireTime = math.max(0.001, cfg.lockAcquireTime or 1.0)
        state.progress = _xSlotClamp(state.progress + (dt or 0.0) / acquireTime, 0.0, 1.0)
        if state.progress >= 1.0 then
            state.progress = 1.0
            state.state = "locked"
            state.lockedVehicleId = target.vehicleId
            state.lockedBodyId = target.bodyId
        else
            state.state = "acquiring"
        end
    end

    if state.state == "locked" then
        state.progress = 1.0
        state.candidateVehicleId = target.vehicleId
        state.candidateBodyId = target.bodyId
        state.lockedVehicleId = target.vehicleId
        state.lockedBodyId = target.bodyId
    end
end

function client.xSlotTargetingGetHudState()
    return client.xSlotTargetingState
end

function client.xSlotTargetingHasLockedTarget(shipBodyId)
    local state = client.xSlotTargetingState
    return state.active and state.shipBody == math.floor(shipBodyId or 0) and state.state == "locked" and state.lockedVehicleId ~= 0
end

function client.xSlotTargetingGetLockedTargetWorld(shipBodyId)
    if not client.xSlotTargetingHasLockedTarget(shipBodyId) then
        return nil
    end
    return client.xSlotTargetingState.targetWorldPos
end