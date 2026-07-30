---@diagnostic disable: undefined-global

client = client or {}

local _guidedReticleColors = {
    mSlot = { 0.96, 0.55, 0.18 },
    gSlot = { 0.24, 0.48, 1.00 },
    hSlot = { 0.95, 0.79, 0.20 },
}

local function _guidedCurrentMode()
    local body = client.shipCameraGetControlledBody ~= nil
        and (client.shipCameraGetControlledBody() or 0) or 0
    if body == 0 or client.getShipMainWeaponMode == nil then return "" end
    return client.getShipMainWeaponMode(body)
end

function client.guidedTargetingHudDraw()
    local mode = _guidedCurrentMode()
    if _guidedReticleColors[mode] == nil then return end
    local state = client.guidedTargetingGetHudState ~= nil
        and client.guidedTargetingGetHudState() or nil
    if state == nil or state.targetWorldPos == nil then return end
    local tx, ty = UiWorldToPixel(state.targetWorldPos)
    if tx == nil or ty == nil then return end
    local distance = math.max(0.001, state.targetDistance or 0.001)
    local size = math.max(
        client.guidedTargetingConfig.lockBoxMinSizePx or 20.0,
        math.min(
            client.guidedTargetingConfig.lockBoxMaxSizePx or 60.0,
            (client.guidedTargetingConfig.lockBoxScale or 2400.0) / distance
        )
    )
    client.targetLockReticleDraw(
        tx,
        ty,
        size,
        state.progress or 0.0,
        state.state or "idle",
        distance,
        _guidedReticleColors[mode]
    )
end
