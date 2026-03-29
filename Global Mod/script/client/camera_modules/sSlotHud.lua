---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.sSlotHudConfig = client.sSlotHudConfig or {
    ringThickness = 2.0,
    ringSegments = 40,
    boxThickness = 2.0,
    boxCornerFraction = 0.28,
    acquiringColor = { 1.0, 0.82, 0.24, 0.95 },
    lockedColor = { 1.0, 0.24, 0.18, 0.98 },
}

local function _sSlotHudClamp(v, a, b)
    if v < a then
        return a
    end
    if v > b then
        return b
    end
    return v
end

local function _drawHudLine(x1, y1, x2, y2, thickness, color)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        return
    end

    UiPush()
        UiTranslate(x1, y1)
        UiRotate(math.deg(math.atan2(dy, dx)))
        UiColor(color[1], color[2], color[3], color[4])
        UiRect(len, thickness)
    UiPop()
end

local function _drawLockRing(cx, cy, radius, cfg, color)
    local segments = math.max(12, math.floor(cfg.ringSegments or 40))
    local thickness = cfg.ringThickness or 2.0

    for i = 0, segments - 1 do
        local a0 = (i / segments) * math.pi * 2.0
        local a1 = ((i + 1) / segments) * math.pi * 2.0
        local x1 = cx + math.cos(a0) * radius
        local y1 = cy + math.sin(a0) * radius
        local x2 = cx + math.cos(a1) * radius
        local y2 = cy + math.sin(a1) * radius
        _drawHudLine(x1, y1, x2, y2, thickness, color)
    end
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

local function _resolveCurrentMode()
    local body = 0
    if client.shipCameraGetControlledBody ~= nil then
        body = client.shipCameraGetControlledBody() or 0
    end
    if body == 0 then
        body = client.shipBody or 0
    end
    if body == 0 or client.getShipMainWeaponMode == nil then
        return "xSlot"
    end
    return client.getShipMainWeaponMode(body)
end

local function _resolveAimRingCenter(state)
    if state ~= nil and state.lockCenterWorld ~= nil then
        local sx, sy = UiWorldToPixel(state.lockCenterWorld)
        if sx ~= nil and sy ~= nil then
            return sx, sy
        end
    end

    if state ~= nil and state.shipBody ~= nil and state.shipBody ~= 0 and client.shipCrosshairGetAimWorldPoint ~= nil then
        local worldPoint = client.shipCrosshairGetAimWorldPoint(state.shipBody)
        if worldPoint ~= nil then
            local sx, sy = UiWorldToPixel(worldPoint)
            if sx ~= nil and sy ~= nil then
                return sx, sy
            end
        end
    end

    return UiWidth() * 0.5, UiHeight() * 0.5
end

function client.sSlotHudDraw()
    if _resolveCurrentMode() ~= "sSlot" then
        return
    end

    local state = client.sSlotTargetingGetHudState ~= nil and client.sSlotTargetingGetHudState() or nil
    local cfg = client.sSlotHudConfig
    if state == nil then
        return
    end

    local centerX, centerY = _resolveAimRingCenter(state)

    local fov = 70.0
    if client.shipCamera ~= nil and tonumber(client.shipCamera.fov) ~= nil then
        fov = tonumber(client.shipCamera.fov) or fov
    end
    local halfAngle = math.rad(client.sSlotTargetingConfig.lockHalfAngleDeg or 8.0)
    local ringRadius = (UiHeight() * 0.5) * math.tan(halfAngle) / math.tan(math.rad(fov * 0.5))
    ringRadius = math.max(12.0, ringRadius)

    -- 暂时屏蔽锁定圆圈
    -- _drawLockRing(centerX, centerY, ringRadius, cfg, cfg.acquiringColor)

    if state.targetWorldPos == nil then
        return
    end

    local tx, ty = UiWorldToPixel(state.targetWorldPos)
    if tx == nil or ty == nil then
        return
    end

    local size = client.sSlotTargetingConfig.lockBoxMinSizePx or 20.0
    if (state.targetDistance or 0.0) > 0.001 then
        size = _sSlotHudClamp(
            (client.sSlotTargetingConfig.lockBoxScale or 2400.0) / state.targetDistance,
            client.sSlotTargetingConfig.lockBoxMinSizePx or 20.0,
            client.sSlotTargetingConfig.lockBoxMaxSizePx or 60.0
        )
    end

    _drawLockBox(tx, ty, size, state.progress or 0.0, state.state or "idle", cfg)
end
