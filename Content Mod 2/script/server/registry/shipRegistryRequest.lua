---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local function _isPlayerDrivingShip(playerId, shipBodyId)
    if playerId == nil or shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    if IsPlayerValid ~= nil and (not IsPlayerValid(playerId)) then
        return false
    end

    local veh = GetPlayerVehicle(playerId)
    if veh == nil or veh == 0 then
        return false
    end

    local playerVehicleBody = GetVehicleBody(veh)
    if playerVehicleBody == shipBodyId then
        return true
    end

    local shipVeh = GetBodyVehicle(shipBodyId)
    if shipVeh ~= nil and shipVeh ~= 0 and shipVeh == veh then
        return true
    end

    return false
end

local function _canAcceptShipRequest(playerId, shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    if server.registryShipExists ~= nil and (not server.registryShipExists(shipBodyId)) then
        return false
    end
    if not _isPlayerDrivingShip(playerId, shipBodyId) then
        return false
    end
    return true
end

function server.shipRequestMainWeaponFire(playerId, shipBodyId, request)
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return
    end

    local value = (math.floor(request or 0) ~= 0)
    if server.mainWeaponRequestSetFireRequested ~= nil then
        server.mainWeaponRequestSetFireRequested(value)
    end
end

function server.shipRequestMainWeaponToggle(playerId, shipBodyId, request)
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return
    end

    local value = (math.floor(request or 0) ~= 0)
    if server.mainWeaponRequestSetToggleRequested ~= nil then
        server.mainWeaponRequestSetToggleRequested(value)
    end
end

function server.shipRequestXWeaponHold(playerId, shipBodyId, request)
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end
    if server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBodyId) ~= "xSlot" then
        return false
    end

    if server.xSlotStateSetHoldRequested ~= nil then
        server.xSlotStateSetHoldRequested(math.floor(request or 0) ~= 0)
    end
    return true
end

function server.shipRequestXWeaponRelease(playerId, shipBodyId)
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end
    if server.shipRuntimeGetCurrentMainWeapon ~= nil and server.shipRuntimeGetCurrentMainWeapon(shipBodyId) ~= "xSlot" then
        return false
    end

    if server.xSlotStateSetHoldRequested ~= nil then
        server.xSlotStateSetHoldRequested(false)
    end
    if server.xSlotStateSetReleaseRequested ~= nil then
        server.xSlotStateSetReleaseRequested(true)
    end
    return true
end

function server.shipRequestSWeaponFire(playerId, shipBodyId, targetVehicleId)
    if server.shipBody == nil or server.shipBody == 0 or server.shipBody ~= shipBodyId then
        return false
    end
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    if server.shipRuntimeGetCurrentMainWeapon ~= nil then
        local current = server.shipRuntimeGetCurrentMainWeapon(shipBodyId)
        if current ~= "sSlot" then
            return false
        end
    end

    local vehicleId = math.floor(targetVehicleId or 0)
    if vehicleId <= 0 then
        return false
    end

    local targetBody = GetVehicleBody(vehicleId)

    server.sSlotLastFireRequest = {
        shipBodyId = shipBodyId,
        targetVehicleId = vehicleId,
        targetBodyId = targetBody or 0,
        requestedAt = (GetTime ~= nil) and GetTime() or 0.0,
    }
    return true
end

function server.shipRequestMoveState(playerId, shipBodyId, moveState)
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return
    end

    local state = math.floor(moveState or 0)
    if state < 0 then
        state = 0
    end
    if state > 2 then
        state = 2
    end

    if server.shipRuntimeSetMoveRequestState ~= nil then
        server.shipRuntimeSetMoveRequestState(shipBodyId, state)
    end
end

function server.shipRequestRotationError(playerId, shipBodyId, pitchError, yawError)
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    local pe = tonumber(pitchError) or 0.0
    local ye = tonumber(yawError) or 0.0
    if pe ~= pe or pe == math.huge or pe == -math.huge then
        pe = 0.0
    end
    if ye ~= ye or ye == math.huge or ye == -math.huge then
        ye = 0.0
    end

    if server.shipRuntimeSetRotationError ~= nil then
        server.shipRuntimeSetRotationError(shipBodyId, pe, ye)
    end
    return true
end

function server.shipRequestWeaponAim(playerId, shipBodyId, active, localYaw, localPitch)
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    local aimActive = math.floor(active or 0) ~= 0
    local yawValue = tonumber(localYaw) or 0.0
    local pitchValue = tonumber(localPitch) or 0.0
    if yawValue ~= yawValue or yawValue == math.huge or yawValue == -math.huge then
        yawValue = 0.0
    end
    if pitchValue ~= pitchValue or pitchValue == math.huge or pitchValue == -math.huge then
        pitchValue = 0.0
    end

    if server.shipRuntimeSetWeaponAim ~= nil then
        server.shipRuntimeSetWeaponAim(shipBodyId, aimActive, yawValue, pitchValue)
    end
    return true
end

function server.shipRequestRollError(playerId, shipBodyId, rollError)
    if not _canAcceptShipRequest(playerId, shipBodyId) then
        return false
    end

    local re = tonumber(rollError) or 0.0
    if re ~= re or re == math.huge or re == -math.huge then
        re = 0.0
    end

    if server.shipRuntimeSetRollError ~= nil then
        server.shipRuntimeSetRollError(shipBodyId, re)
    end
    return true
end
