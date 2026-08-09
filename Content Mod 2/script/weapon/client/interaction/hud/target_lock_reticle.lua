---@diagnostic disable: undefined-global

client = client or {}

local function _reticleClamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or 0.0))
end

local function _reticleLine(x1, y1, x2, y2, thickness, color, alpha)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.01 then return end
    UiPush()
        UiTranslate(x1, y1)
        UiRotate(math.deg(math.atan2(dy, dx)))
        UiColor(color[1], color[2], color[3], alpha)
        UiRect(length, thickness)
    UiPop()
end

local function _reticleArc(cx, cy, radius, progress, color, locked)
    local segmentCount = 28
    local filled = locked and segmentCount
        or math.floor(_reticleClamp(progress, 0.0, 1.0) * segmentCount + 0.5)
    for index = 0, segmentCount - 1 do
        local startAngle = -math.pi * 0.5
            + (index / segmentCount) * math.pi * 2.0
        local endAngle = startAngle + math.pi * 2.0 / segmentCount * 0.62
        local alpha = index < filled and 0.92 or 0.12
        local thickness = index < filled and 2.2 or 1.0
        _reticleLine(
            cx + math.cos(startAngle) * radius,
            cy + math.sin(startAngle) * radius,
            cx + math.cos(endAngle) * radius,
            cy + math.sin(endAngle) * radius,
            thickness,
            color,
            alpha
        )
    end
end

local function _reticleCorners(cx, cy, half, length, color, alpha)
    local thickness = 2.0
    _reticleLine(cx - half, cy - half, cx - half + length, cy - half,
        thickness, color, alpha)
    _reticleLine(cx - half, cy - half, cx - half, cy - half + length,
        thickness, color, alpha)
    _reticleLine(cx + half - length, cy - half, cx + half, cy - half,
        thickness, color, alpha)
    _reticleLine(cx + half, cy - half, cx + half, cy - half + length,
        thickness, color, alpha)
    _reticleLine(cx - half, cy + half - length, cx - half, cy + half,
        thickness, color, alpha)
    _reticleLine(cx - half, cy + half, cx - half + length, cy + half,
        thickness, color, alpha)
    _reticleLine(cx + half - length, cy + half, cx + half, cy + half,
        thickness, color, alpha)
    _reticleLine(cx + half, cy + half - length, cx + half, cy + half,
        thickness, color, alpha)
end

function client.targetLockReticleDraw(
    centerX,
    centerY,
    targetSize,
    progress,
    stateName,
    distance,
    color
)
    local p = _reticleClamp(progress, 0.0, 1.0)
    local locked = tostring(stateName or "") == "locked"
    local baseSize = _reticleClamp(targetSize, 30.0, 76.0)
    local settle = locked and 0.0 or (1.0 - p) * 13.0
    local half = baseSize * 0.5 + settle
    local radius = half + 10.0
    local theme = color or { 0.34, 0.82, 1.0 }
    local pulse = locked
        and (0.82 + math.sin(((GetTime ~= nil) and GetTime() or 0.0) * 8.0) * 0.12)
        or 0.78

    _reticleArc(centerX, centerY, radius, p, theme, locked)
    _reticleCorners(
        centerX,
        centerY,
        half,
        math.max(7.0, baseSize * 0.20),
        theme,
        pulse
    )

    UiPush()
        UiTranslate(centerX, centerY)
        UiAlign("center middle")
        UiColor(theme[1], theme[2], theme[3], locked and pulse or 0.45)
        if locked then
            UiRotate(45)
            UiRect(5, 5)
        else
            UiRect(3, 3)
        end
    UiPop()

    local status = locked and "目标锁定 / LOCKED"
        or string.format("锁定 %d%% / LOCKING", math.floor(p * 100 + 0.5))
    local rangeText = string.format("%.0f m", math.max(0.0, distance or 0.0))
    UiPush()
        UiTranslate(centerX, centerY + half + 17.0)
        UiAlign("center top")
        UiFont("regular.ttf", 11)
        UiColor(theme[1], theme[2], theme[3], locked and 0.96 or 0.76)
        UiText(status)
        UiTranslate(0, 14)
        UiFont("regular.ttf", 9)
        UiColor(theme[1], theme[2], theme[3], 0.50)
        UiText(rangeText)
    UiPop()
end
