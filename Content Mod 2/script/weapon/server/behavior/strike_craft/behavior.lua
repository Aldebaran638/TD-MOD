---@diagnostic disable: undefined-global

server = server or {}

local function _fireStrikeCraft(context)
    if server.hSlotControlSetFireRequested == nil then return false end
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
