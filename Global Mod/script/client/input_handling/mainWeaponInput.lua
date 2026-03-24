---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponInputState = client.mainWeaponInputState or {
    localPlayerId = nil,
}

local function _resolveMainWeaponLocalPlayerId()
    local state = client.mainWeaponInputState
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

function client.mainWeaponInputTick(dt)
    local _ = dt
    local localPlayerId = _resolveMainWeaponLocalPlayerId()
    if localPlayerId == nil then
        return
    end

    local veh = GetPlayerVehicle(localPlayerId)
    if veh == nil or veh == 0 then
        return
    end

    local body = GetVehicleBody(veh)
    local shipBody = client.shipBody
    if body == nil or body == 0 or shipBody == nil or shipBody == 0 or body ~= shipBody then
        return
    end
    if not client.registryShipExists(shipBody) then
        return
    end

    if InputPressed("q") then
        client.registryShipSetMainWeaponToggleRequest(shipBody, 1)
    end

    if InputPressed("lmb") then
        client.registryShipSetMainWeaponFireRequest(shipBody, 1)
    end
end
