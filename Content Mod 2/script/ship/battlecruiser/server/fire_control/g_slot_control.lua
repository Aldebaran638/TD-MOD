---@diagnostic disable: undefined-global

server = server or {}

function server.gSlotControlInit(shipType)
    return server.guidedSlotGroupInit("gSlot", "gSlots", "client.updateGSlotHudState", shipType)
end

function server.gSlotControlResetRuntime()
    server.guidedSlotGroupReset("gSlot")
end

function server.gSlotControlSetFireRequest(shipBodyId, targetVehicleId, targetBodyId)
    return server.guidedSlotGroupSetFireRequest("gSlot", shipBodyId, targetVehicleId, targetBodyId)
end

function server.gSlotControlTick(dt)
    server.guidedSlotGroupTick("gSlot", dt)
end
