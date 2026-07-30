---@diagnostic disable: undefined-global

client = client or {}

function client.xSlotLockHudDraw()
    local body = client.shipCameraGetControlledBody ~= nil
        and (client.shipCameraGetControlledBody() or 0) or 0
    if body == 0
        or client.getShipMainWeaponMode == nil
        or client.getShipMainWeaponMode(body) ~= "xSlot"
        or client.getShipXSlotFireMode == nil
        or client.getShipXSlotFireMode(body) ~= "lock" then
        return
    end
    local state = client.xSlotTargetingGetHudState ~= nil
        and client.xSlotTargetingGetHudState() or nil
    if state == nil or state.targetWorldPos == nil then return end
    local tx, ty = UiWorldToPixel(state.targetWorldPos)
    if tx == nil or ty == nil then return end
    local distance = math.max(0.001, state.targetDistance or 0.001)
    local size = math.max(
        client.xSlotTargetingConfig.lockBoxMinSizePx or 20.0,
        math.min(
            client.xSlotTargetingConfig.lockBoxMaxSizePx or 60.0,
            (client.xSlotTargetingConfig.lockBoxScale or 2400.0) / distance
        )
    )
    client.targetLockReticleDraw(
        tx,
        ty,
        size,
        state.progress or 0.0,
        state.state or "idle",
        distance,
        { 0.66, 0.34, 1.00 }
    )
end
