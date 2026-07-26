---@diagnostic disable: undefined-global

server = server or {}

#include "weapon/server/slots/h/gamma_strike_craft/flight_v2_common.lua"
#include "weapon/server/slots/h/gamma_strike_craft/flight_v2_navigation.lua"
#include "weapon/server/slots/h/gamma_strike_craft/flight_v2_control.lua"

local function _fireStrikeCraft(context)
    if server.hSlotControlSetFireRequested == nil then return false end
    if server.hSlotV2Install ~= nil then
        server.hSlotV2Install()
    end
    server.hSlotLastFireRequest = {
        shipBodyId = context.shipBodyId,
        targetVehicleId = context.targetVehicleId,
        targetBodyId = context.targetBodyId,
        requestedAt = (GetTime ~= nil) and GetTime() or 0.0,
    }
    server.hSlotControlSetFireRequested(true)
    return true
end

server.weaponBehaviorRegister("strikeCraft", { fire = _fireStrikeCraft })
