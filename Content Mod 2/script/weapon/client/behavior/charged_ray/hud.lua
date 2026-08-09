---@diagnostic disable: undefined-global

client = client or {}

function client.xSlotLockHudDraw()
    local body = client.shipCameraGetControlledBody ~= nil
        and (client.shipCameraGetControlledBody() or 0) or 0
    if body == 0
        or client.getShipMainWeaponMode == nil
        or client.getShipWeaponDefinition == nil
        or tostring((client.getShipWeaponDefinition(
            body,
            client.getShipMainWeaponMode(body)
        ) or {}).controllerType or "") ~= "chargedRay"
        or client.getShipWeaponFireMode == nil
        or client.getShipWeaponFireMode(body) ~= "lock" then
        return
    end
    local getHudState = client.chargedRayTargetingGetHudState
        or client.xSlotTargetingGetHudState
    local state = getHudState ~= nil and getHudState() or nil
    if state == nil or state.targetWorldPos == nil then return end
    local targetingConfig = client.chargedRayTargetingConfig
        or client.xSlotTargetingConfig
    local tx, ty = UiWorldToPixel(state.targetWorldPos)
    if tx == nil or ty == nil then return end
    local distance = math.max(0.001, state.targetDistance or 0.001)
    local size = math.max(
        targetingConfig.lockBoxMinSizePx or 20.0,
        math.min(
            targetingConfig.lockBoxMaxSizePx or 60.0,
            (targetingConfig.lockBoxScale or 2400.0) / distance
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

client.chargedRayLockHudDraw = client.xSlotLockHudDraw
