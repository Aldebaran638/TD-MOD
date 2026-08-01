---@diagnostic disable: undefined-global

client = client or {}

client.nativeVehicleHudState = client.nativeVehicleHudState or {
    pauseMenuRequested = false,
}

local function _nativeVehicleHudIsLocalShipControlled()
    local vehicle = GetPlayerVehicle()
    if vehicle == nil or vehicle == 0 then
        return false
    end

    local vehicleBody = GetVehicleBody(vehicle)
    local scriptBody = client.shipContextGetBody()
    if vehicleBody == nil or vehicleBody == 0 or scriptBody == 0 or vehicleBody ~= scriptBody then
        return false
    end

    return client.registryShipExists == nil or client.registryShipExists(scriptBody)
end

function client.nativeVehicleHudTick()
    local state = client.nativeVehicleHudState
    if not _nativeVehicleHudIsLocalShipControlled() then
        state.pauseMenuRequested = false
        return
    end

    -- The stock pause menu is rendered by the standard HUD. Keep that HUD
    -- visible for the duration of the Esc toggle instead of hiding it again
    -- on the next frame.
    if InputPressed("pause") or InputPressed("esc") then
        state.pauseMenuRequested = not state.pauseMenuRequested
    end
end

function client.nativeVehicleHudSuppressDraw()
    if not _nativeVehicleHudIsLocalShipControlled() then
        return
    end

    if client.nativeVehicleHudState.pauseMenuRequested then
        SetBool("hud.hide", false)
        return
    end

    -- The stock HUD is drawn after mod client.draw callbacks. This one-frame
    -- flag is consumed and reset by data/ui/hud.lua, so leaving the ship
    -- restores the native HUD automatically.
    SetBool("hud.hide", true)
end
