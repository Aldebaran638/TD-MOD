---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.weaponConfigurationBindingState = client.weaponConfigurationBindingState or {
    shipType = "",
    shipBody = 0,
    snapshot = nil,
    serverProfile = nil,
    complete = false,
    requestPending = false,
    retryRemain = 0.0,
}

function client.weaponConfigurationBindingInit(shipType, shipBody)
    local state = client.weaponConfigurationBindingState
    state.shipType = tostring(shipType or client.shipContextGetType())
    state.shipBody = math.floor(shipBody or 0)
    state.snapshot = client.weaponLocalConfigRead(state.shipType)
    state.serverProfile = nil
    local definition = (shipTypeRegistryData or {})[state.shipType] or {}
    state.complete = definition.playerConfigurable == false
    state.requestPending = false
    state.retryRemain = 0.0
end

local function _weaponConfigurationIsLocalDriver(shipBody)
    local playerId = GetLocalPlayer()
    local vehicle = GetPlayerVehicle(playerId)
    if vehicle == nil or vehicle == 0 then return false, playerId end
    if GetVehicleBody(vehicle) ~= shipBody then return false, playerId end
    if IsPlayerVehicleDriver ~= nil and not IsPlayerVehicleDriver(vehicle, playerId) then
        return false, playerId
    end
    return true, playerId
end

function client.weaponConfigurationBindingResult(shipBody, resultCode)
    local state = client.weaponConfigurationBindingState
    if math.floor(shipBody or 0) ~= math.floor(state.shipBody or 0) then return end
    state.requestPending = false
    if math.floor(resultCode or 0) ~= 0 then
        state.complete = true
    else
        state.retryRemain = 0.5
    end
end

function client.weaponConfigurationBindingTick(dt)
    local state = client.weaponConfigurationBindingState
    if state.complete or state.snapshot == nil or state.shipBody == 0 then return end

    state.retryRemain = math.max(0.0, (state.retryRemain or 0.0) - (dt or 0.0))
    if state.requestPending or state.retryRemain > 0.0 then return end

    local isDriver, playerId = _weaponConfigurationIsLocalDriver(state.shipBody)
    if not isDriver then return end

    local snapshot = state.snapshot or {}
    local loadout = snapshot.loadout or {}
    local componentPayload =
        shipComponentEncodeLoadout(snapshot.componentLoadout or {})
    state.requestPending = true
    state.retryRemain = 1.0
    ServerCall(
        "server.shipWeaponBindLocalConfiguration",
        playerId,
        state.shipBody,
        state.shipType,
        tostring(snapshot.configurationId or ""),
        tostring(loadout.T or ""),
        tostring(loadout.X or ""),
        tostring(loadout.L or ""),
        tostring(loadout.L2 or loadout.L or ""),
        tostring(loadout.M or ""),
        tostring(loadout.G or ""),
        tostring(loadout.H or ""),
        tostring(loadout.P or ""),
        componentPayload
    )
end
