---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotLockHudConfig = client.xSlotLockHudConfig or {
    boxThickness = 2.0,
    boxCornerFraction = 0.28,
    acquiringColor = { 0.20, 0.82, 1.00, 0.95 },
    lockedColor = { 1.0, 0.24, 0.18, 0.98 },
}

local function _drawHudLine(x1, y1, x2, y2, thickness, color)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        return
    end

    UiPush()
        UiTranslate(x1, y1)
        UiRotate(math.deg(math.atan(dy, dx)))
        UiColor(color[1], color[2], color[3], color[4])
        UiRect(len, thickness)
    UiPop()
end

local function _drawLockBox(cx, cy, size, progress, stateName, cfg)
    local half = size * 0.5
    local corner = math.max(4.0, size * (cfg.boxCornerFraction or 0.28) * math.max(progress, 0.25))
    local color = cfg.acquiringColor
    if stateName == "locked" then
        color = cfg.lockedColor
        corner = math.max(4.0, size * (cfg.boxCornerFraction or 0.28))
    end

    local t = cfg.boxThickness or 2.0
    local left = cx - half
    local right = cx + half
    local top = cy - half
    local bottom = cy + half

    _drawHudLine(left, top, left + corner, top, t, color)
    _drawHudLine(left, top, left, top + corner, t, color)
    _drawHudLine(right - corner, top, right, top, t, color)
    _drawHudLine(right, top, right, top + corner, t, color)
    _drawHudLine(left, bottom - corner, left, bottom, t, color)
    _drawHudLine(left, bottom, left + corner, bottom, t, color)
    _drawHudLine(right - corner, bottom, right, bottom, t, color)
    _drawHudLine(right, bottom - corner, right, bottom, t, color)
end

function client.xSlotLockHudDraw()
    local body = client.shipCameraGetControlledBody ~= nil and (client.shipCameraGetControlledBody() or 0) or 0
    if body == 0 then
        return
    end
    if client.getShipMainWeaponMode == nil or client.getShipMainWeaponMode(body) ~= "xSlot" then
        return
    end
    if client.getShipXSlotFireMode == nil or client.getShipXSlotFireMode(body) ~= "lock" then
        return
    end

    local state = client.xSlotTargetingGetHudState ~= nil and client.xSlotTargetingGetHudState() or nil
    if state == nil or state.targetWorldPos == nil then
        return
    end

    local tx, ty = UiWorldToPixel(state.targetWorldPos)
    if tx == nil or ty == nil then
        return
    end

    local cfg = client.xSlotLockHudConfig
    local targetDistance = math.max(0.001, state.targetDistance or 0.001)
    local size = math.min(
        client.xSlotTargetingConfig.lockBoxMaxSizePx or 60.0,
        math.max(
            client.xSlotTargetingConfig.lockBoxMinSizePx or 20.0,
            (client.xSlotTargetingConfig.lockBoxScale or 2400.0) / targetDistance
        )
    )

    _drawLockBox(tx, ty, size, state.progress or 0.0, state.state or "idle", cfg)
end