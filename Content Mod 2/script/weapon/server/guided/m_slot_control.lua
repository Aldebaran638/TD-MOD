---@diagnostic disable: undefined-global

server = server or {}

function server.mSlotControlInit(shipType)
    return server.guidedSlotGroupInit("mSlot", "mSlots", "client.updateMSlotHudState", shipType)
end

function server.mSlotControlResetRuntime()
    server.guidedSlotGroupReset("mSlot")
end

function server.mSlotControlSetFireRequest(shipBodyId, targetVehicleId, targetBodyId)
    return server.guidedSlotGroupSetFireRequest("mSlot", shipBodyId, targetVehicleId, targetBodyId)
end

function server.mSlotControlTick(dt)
    server.guidedSlotGroupTick("mSlot", dt)
end
