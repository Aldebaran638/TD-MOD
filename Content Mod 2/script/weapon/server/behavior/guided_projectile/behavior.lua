---@diagnostic disable: undefined-global

server = server or {}

local function _fireGuided(context)
    if server.guidedSlotGroupSetFireRequest == nil then return false end
    return server.guidedSlotGroupSetFireRequest(
        context.groupId,
        context.shipBodyId,
        context.targetVehicleId,
        context.targetBodyId
    )
end

server.weaponBehaviorRegister("guidedProjectile", { fire = _fireGuided })

