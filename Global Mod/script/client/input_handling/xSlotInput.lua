---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotInputState = client.xSlotInputState or {
    localPlayerId = nil,
}

local function _resolveLocalPlayerId()
    local state = client.xSlotInputState
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

function client.debugTestXSlotInputTick(dt)
end

function client.xSlotInputTick(dt)
    local _ = dt

    if not InputPressed("lmb") then
        return
    end

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

    client.registryShipSetXSlotsRequest(shipBody, 1)
end
