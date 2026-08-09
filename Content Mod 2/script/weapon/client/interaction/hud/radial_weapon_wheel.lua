---@diagnostic disable: undefined-global

client = client or {}

local _twoPi = math.pi * 2.0
local _selectionAngle = math.pi
local _rotationSpeed = 12.0
local _defaultAccentColor = { 0.54, 0.90, 0.82, 0.80 }
local _defaultSelectedFrameColor = { 0.72, 0.98, 0.90, 0.94 }
local _defaultMissingItemColor = { 0.32, 0.42, 0.44, 0.80 }

local function _wrapAngle(angle)
    local value = tonumber(angle) or 0.0
    while value > math.pi do value = value - _twoPi end
    while value < -math.pi do value = value + _twoPi end
    return value
end

local function _smoothAngle(current, target, dt)
    local delta = _wrapAngle(target - current)
    local blend = 1.0 - math.exp(-_rotationSpeed * math.max(0.0, tonumber(dt) or 0.0))
    return current + delta * blend
end

local function _drawRadialSegment(x, y, angle, length, thickness)
    UiPush()
        UiTranslate(x, y)
        UiRotate(math.deg(angle) + 90.0)
        UiTranslate(-length * 0.5, -thickness * 0.5)
        UiRect(length, thickness)
    UiPop()
end

local function _drawRing(cx, cy, radius, segments, gap, thickness, color, phase)
    local circumference = _twoPi * radius
    local segmentLength = math.max(2.0, circumference / segments - gap)
    UiColor(color[1], color[2], color[3], color[4])
    for index = 1, segments do
        local angle = (index - 1) * _twoPi / segments + phase
        local x = cx + math.cos(angle) * radius
        local y = cy + math.sin(angle) * radius
        _drawRadialSegment(x, y, angle, segmentLength, thickness)
    end
end

local function _drawTicks(cx, cy, outerRadius, count, color, phase)
    UiColor(color[1], color[2], color[3], color[4])
    for index = 1, count do
        local angle = (index - 1) * _twoPi / count + phase
        local length = (index % 4 == 1) and 8.0 or 4.0
        local x = cx + math.cos(angle) * outerRadius
        local y = cy + math.sin(angle) * outerRadius
        _drawRadialSegment(x, y, angle, length, 1.0)
    end
end

local function _drawHub(cx, cy, size, color)
    UiPush()
        UiTranslate(cx, cy)
        UiAlign("center middle")
        UiColor(color[1], color[2], color[3], color[4])
        UiRectOutline(size, size, 1)
        UiRotate(45)
        UiRect(size * 0.42, size * 0.42)
        UiRotate(-45)
        UiRect(size, 1)
        UiRect(1, size)
    UiPop()
end

local function _drawItem(item, x, y, selected, config)
    local entry = item or {}
    local accentColor = config.accentColor or _defaultAccentColor
    local selectedFrameColor = config.selectedFrameColor or _defaultSelectedFrameColor
    local missingItemColor = config.missingItemColor or _defaultMissingItemColor
    local color = entry.color or accentColor
    local baseSize = tonumber(config.itemSize) or 24.0
    local size = selected and (tonumber(config.selectedItemSize) or 46.0) or baseSize
    local alpha = selected and 1.0 or 0.58
    local iconPath = tostring(entry.iconPath or "")

    UiPush()
        UiTranslate(x, y)
        UiAlign("center middle")
        if selected then
            UiColor(color[1], color[2], color[3], 0.20)
            UiRect(size + 16.0, size + 16.0)
            UiColor(selectedFrameColor[1], selectedFrameColor[2],
                selectedFrameColor[3], selectedFrameColor[4])
            UiRectOutline(size + 14.0, size + 14.0, 2)
            UiColor(color[1], color[2], color[3], 0.34)
            UiRectOutline(size + 7.0, size + 7.0, 1)
        end

        if iconPath ~= "" then
            -- Preserve the source PNG colors; alpha still communicates focus.
            UiColor(1.0, 1.0, 1.0, alpha)
            UiImageBox(iconPath, size, size, 0, 0)
        else
            UiColor(missingItemColor[1], missingItemColor[2],
                missingItemColor[3], selected and 0.88 or 0.30)
            UiRect(size * 0.72, size * 0.72)
        end

        UiColor(1.0, 1.0, 1.0, selected and 0.98 or 0.60)
        UiFont("regular.ttf", selected and 11 or 9)
        UiAlign("center middle")
        UiTranslate(0, size * 0.62)
        UiText(tostring(entry.label or "?"))
    UiPop()
end

function client.radialWeaponWheelCreateState()
    return {
        rotation = 0.0,
        targetRotation = 0.0,
        selectedId = "",
        initialized = false,
        time = 0.0,
    }
end

function client.radialWeaponWheelReset(state)
    local wheel = state or client.radialWeaponWheelCreateState()
    wheel.rotation = 0.0
    wheel.targetRotation = 0.0
    wheel.selectedId = ""
    wheel.initialized = false
    wheel.time = 0.0
    return wheel
end

function client.radialWeaponWheelUpdate(state, items, selectedId, dt)
    local wheel = state or client.radialWeaponWheelCreateState()
    local entries = items or {}
    local selected = tostring(selectedId or "")
    local selectedIndex = 1
    for index, item in ipairs(entries) do
        if tostring((item or {}).id or "") == selected then
            selectedIndex = index
            break
        end
    end

    local step = #entries > 0 and _twoPi / #entries or _twoPi
    local itemAngle = (selectedIndex - 1) * step
    local target = _selectionAngle - itemAngle
    if not wheel.initialized then
        wheel.rotation = target
        wheel.targetRotation = target
        wheel.initialized = true
    else
        wheel.targetRotation = wheel.rotation + _wrapAngle(target - wheel.rotation)
        wheel.rotation = _smoothAngle(wheel.rotation, wheel.targetRotation, dt)
    end
    wheel.selectedId = selected
    wheel.time = (tonumber(wheel.time) or 0.0) + math.max(0.0, tonumber(dt) or 0.0)
    return wheel
end

function client.radialWeaponWheelDraw(state, items, x, y, config)
    local wheel = state or client.radialWeaponWheelCreateState()
    local cfg = config or {}
    local entries = items or {}
    local cx = tonumber(x) or 0.0
    local cy = tonumber(y) or 0.0
    local radius = tonumber(cfg.radius) or 56.0
    local phase = (tonumber(wheel.time) or 0.0) * 0.16
    local rotation = tonumber(wheel.rotation) or 0.0

    UiPush()
        _drawRing(cx, cy, radius + 8.0, 28, 4.0, 2.0,
            cfg.outerRingColor or { 0.12, 0.74, 0.70, 0.48 }, phase)
        _drawRing(cx, cy, radius - 8.0, 18, 5.0, 1.0,
            cfg.innerRingColor or { 0.54, 0.90, 0.82, 0.34 }, -phase * 1.4)
        _drawTicks(cx, cy, radius + 12.0, 16,
            cfg.tickColor or { 0.62, 0.92, 0.86, 0.42 }, phase)
        _drawHub(cx, cy, tonumber(cfg.hubSize) or 22.0,
            cfg.hubColor or { 0.64, 0.94, 0.88, 0.72 })

        for index, item in ipairs(entries) do
            local angle = rotation + (index - 1) * _twoPi / math.max(1, #entries)
            local itemX = cx + math.cos(angle) * radius
            local itemY = cy + math.sin(angle) * radius
            local selected = tostring((item or {}).id or "") == wheel.selectedId
            _drawItem(item, itemX, itemY, selected, cfg)
        end
    UiPop()
end
