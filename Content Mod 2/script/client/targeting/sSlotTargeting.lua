---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.sSlotTargetingConfig = client.sSlotTargetingConfig or {
    lockDistance = 660.0,
    lockHalfAngleDeg = 8.0,
    lockAcquireTime = 1.4,
    lockLoseGraceTime = 0.25,
    lockBoxMinSizePx = 20.0,
    lockBoxMaxSizePx = 60.0,
    lockBoxScale = 2400.0,
}

client.sSlotTargetingState = client.sSlotTargetingState or {
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

local function _sSlotClamp(v, a, b)
    if v < a then
        return a
    end
    if v > b then
        return b
    end
    return v
end

local function _sSlotResetState(state)
    state.active = false
    state.shipBody = 0
    state.lockCenterWorld = nil
    state.isProjectedVisible = false
    state.targetWorldPos = nil
    state.targetDistance = 0.0
    state.loseTimer = 0.0
    state.progress = 0.0
    state.state = "idle"
    state.candidateVehicleId = 0
    state.candidateBodyId = 0
    state.lockedVehicleId = 0
    state.lockedBodyId = 0
end

local function _sSlotClearTarget(state)
    state.targetWorldPos = nil
    state.targetDistance = 0.0
    state.isProjectedVisible = false
    state.loseTimer = 0.0
    state.progress = 0.0
    state.state = "idle"
    state.candidateVehicleId = 0
    state.candidateBodyId = 0
    state.lockedVehicleId = 0
    state.lockedBodyId = 0
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

local function _evaluateVehicleTarget(vehicleId, shipBody, shipPos, shipForward, centerLocal, camT, cfg)
    if vehicleId == nil or vehicleId == 0 then
        return nil
    end

    local targetBody = GetVehicleBody(vehicleId)
    local targetPos
    
    if targetBody ~= nil and targetBody ~= 0 and targetBody ~= shipBody then
        targetPos = _getBodyCenterWorld(targetBody)
        if targetPos == nil then
            return nil
        end
    else
        -- 处理没有body的载具
        targetPos = GetVehicleTransform(vehicleId).pos
        if targetPos == nil then
            return nil
        end
    end

    local toTarget = VecSub(targetPos, shipPos)
    local distance = VecLength(toTarget)
    if distance <= 0.001 or distance > (cfg.lockDistance or 0.0) then
        return nil
    end

    local dir = VecScale(toTarget, 1.0 / distance)
    local minCos = math.cos(math.rad(cfg.lockHalfAngleDeg or 0.0))
    if VecDot(shipForward, dir) < minCos then
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

local function _findBestVehicleTarget(shipBody, shipPos, shipForward, centerLocal, camT, cfg)
    local vehicles = FindVehicles("", true) or {}
    local best = nil

    for i = 1, #vehicles do
        local vehicleId = vehicles[i]
        local entry = _evaluateVehicleTarget(vehicleId, shipBody, shipPos, shipForward, centerLocal, camT, cfg)
        if entry ~= nil and (best == nil or entry.score < best.score) then
            best = entry
        end
    end

    return best
end

local function _resolveStickyTarget(state, shipBody, shipPos, shipForward, centerLocal, camT, cfg)
    local stickyVehicleId = 0
    if state.state == "locked" and state.lockedVehicleId ~= 0 then
        stickyVehicleId = state.lockedVehicleId
    elseif state.candidateVehicleId ~= 0 then
        stickyVehicleId = state.candidateVehicleId
    end

    if stickyVehicleId ~= 0 then
        local sticky = _evaluateVehicleTarget(stickyVehicleId, shipBody, shipPos, shipForward, centerLocal, camT, cfg)
        if sticky ~= nil then
            return sticky
        end
    end

    return _findBestVehicleTarget(shipBody, shipPos, shipForward, centerLocal, camT, cfg)
end

function client.sSlotTargetingTick(dt)
    local state = client.sSlotTargetingState
    local cfg = client.sSlotTargetingConfig

    local shipBody = _resolveControlledShipBody()
    local currentMode = (client.getShipMainWeaponMode ~= nil and shipBody ~= 0) and client.getShipMainWeaponMode(shipBody) or "xSlot"
    if shipBody == 0 or currentMode ~= "sSlot" then
        _sSlotResetState(state)
        return
    end

    state.active = true
    state.shipBody = shipBody

    local shipT = GetBodyTransform(shipBody)
    local shipPos = shipT.pos
    local shipForward = VecNormalize(TransformToParentVec(shipT, Vec(0, 0, -1)))
    local camT = GetCameraTransform()

    local centerDistance = math.max(12.0, math.min(cfg.lockDistance or 220.0, 100.0))
    local centerWorld = nil
    if client.shipCrosshairGetAimWorldPoint ~= nil then
        centerWorld = client.shipCrosshairGetAimWorldPoint(shipBody)
    end
    if centerWorld == nil then
        centerWorld = VecAdd(shipPos, VecScale(shipForward, centerDistance))
    end
    local centerLocal = TransformToLocalPoint(camT, centerWorld)
    if centerLocal[3] >= -0.01 then
        centerLocal = Vec(0, 0, -1)
    end
    state.lockCenterWorld = centerWorld

    local target = _resolveStickyTarget(state, shipBody, shipPos, shipForward, centerLocal, camT, cfg)
    if target == nil then
        if state.candidateVehicleId ~= 0 or state.lockedVehicleId ~= 0 then
            state.loseTimer = state.loseTimer + (dt or 0.0)
            if state.loseTimer > (cfg.lockLoseGraceTime or 0.0) then
                _sSlotClearTarget(state)
            end
        else
            _sSlotClearTarget(state)
        end
        return
    end

    state.active = true
    state.shipBody = shipBody
    state.lockCenterWorld = centerWorld
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
        state.progress = _sSlotClamp(state.progress + (dt or 0.0) / acquireTime, 0.0, 1.0)
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

function client.sSlotTargetingGetHudState()
    return client.sSlotTargetingState
end

function client.sSlotTargetingCanFire(shipBodyId)
    local state = client.sSlotTargetingState
    return state.active
        and state.shipBody == math.floor(shipBodyId or 0)
        and state.state == "locked"
        and state.lockedVehicleId ~= 0
end

function client.sSlotTargetingGetLockedVehicleId(shipBodyId)
    if not client.sSlotTargetingCanFire(shipBodyId) then
        return 0
    end
    return client.sSlotTargetingState.lockedVehicleId or 0
end

function client.sSlotTargetingGetSummary(shipBodyId)
    local state = client.sSlotTargetingState
    if not state.active or state.shipBody ~= math.floor(shipBodyId or 0) then
        return "NO TARGET", 0.0
    end
    if state.state == "locked" then
        return "LOCKED", 1.0
    end
    if state.candidateVehicleId ~= 0 then
        return string.format("LOCKING %d%%", math.floor((state.progress or 0.0) * 100 + 0.5)), state.progress or 0.0
    end
    return "NO TARGET", 0.0
end
