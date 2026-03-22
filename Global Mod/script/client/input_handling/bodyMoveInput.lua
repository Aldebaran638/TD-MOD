---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local moveRequestKeepAliveInterval = 0.2

client.bodyMoveInputState = client.bodyMoveInputState or {
    localPlayerId = nil,
    lastMoveState = -1,
    lastShipBodyId = 0,
    lastSyncAt = -1000,
}

local function _resolveLocalPlayerId()
    local state = client.bodyMoveInputState
    if state.localPlayerId ~= nil and state.localPlayerId ~= 0 then
        return state.localPlayerId
    end

    local pid = GetLocalPlayer()
    if pid ~= nil and pid ~= -1 and pid ~= 0 then
        state.localPlayerId = pid
        return pid
    end

    return nil
end

function client.debugTestBodyMoveInputTick(dt)
end

function client.bodyMoveInputTick(dt)
    local _ = dt
    local state = client.bodyMoveInputState

    local localPlayerId = _resolveLocalPlayerId()
    if localPlayerId == nil then
        return
    end

    local veh = GetPlayerVehicle(localPlayerId)
    if veh == nil or veh == 0 then
        return
    end

    local body = GetVehicleBody(veh)
    if body == nil or body == 0 then
        return
    end

    local shipBody = client.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end

    if body ~= shipBody then
        return
    end

    if not client.registryShipExists(shipBody) then
        return
    end

    local wDown = InputDown("w") and true or false
    local sDown = InputDown("s") and true or false

    local moveState = 0
    if wDown then
        moveState = 1
    elseif sDown then
        moveState = 2
    end

    local now = (GetTime ~= nil) and GetTime() or 0
    local changed = (moveState ~= state.lastMoveState) or (shipBody ~= state.lastShipBodyId)
    local keepAliveDue = (now - (state.lastSyncAt or -1000)) >= moveRequestKeepAliveInterval
    if (not changed) and (not keepAliveDue) then
        return
    end

    state.lastMoveState = moveState
    state.lastShipBodyId = shipBody
    state.lastSyncAt = now

    client.registryShipSetMoveRequestState(shipBody, moveState)
end
