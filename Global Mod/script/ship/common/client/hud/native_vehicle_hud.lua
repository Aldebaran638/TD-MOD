---@diagnostic disable: undefined-global

client = client or {}

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

function client.nativeVehicleHudSuppressDraw()
    if not _nativeVehicleHudIsLocalShipControlled() then
        return
    end

    -- The stock HUD is drawn after mod client.draw callbacks. This one-frame
    -- flag is consumed and reset by data/ui/hud.lua, so leaving the ship
    -- restores the native HUD automatically.
    SetBool("hud.hide", true)
end
