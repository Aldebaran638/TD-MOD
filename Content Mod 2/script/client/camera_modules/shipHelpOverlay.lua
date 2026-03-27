---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.shipHelpOverlayConfig = client.shipHelpOverlayConfig or {
    width = 380,
    rightOffset = 24,
    topOffset = 170,
    titleSize = 20,
    textSize = 16,
    keyWidth = 86,
    rowGap = 12,

    bgColor = { 0.05, 0.07, 0.09, 0.76 },
    borderColor = { 1.0, 1.0, 1.0, 0.22 },
    titleColor = { 1.0, 0.96, 0.90, 1.0 },
    textColor = { 0.90, 0.93, 0.96, 0.98 },
    keyColor = { 0.30, 0.84, 1.0, 1.0 },
    subColor = { 0.72, 0.80, 0.88, 0.95 },
}

client.shipHelpOverlayState = client.shipHelpOverlayState or {
    visible = true,
}

local shipHelpOverlayRows = {
    {
        key = "AUTO",
        title = "Ship hover",
        subtitle = "The ship hovers automatically",
    },
    {
        key = "W / S",
        title = "Move",
        subtitle = "Move forward / backward",
    },
    {
        key = "MOUSE",
        title = "Aim",
        subtitle = "Mouse controls ship facing",
    },
    {
        key = "LMB",
        title = "Fire",
        subtitle = "Left click to fire",
    },
    {
        key = "RMB / Q\n/ U",
        title = "Camera / Weapon / Help",
        subtitle = "Right click changes camera, Q swaps weapons\nU toggles help",
    },
}

local function _shipHelpResolveControlledShipBody()
    if client.shipCameraGetControlledBody ~= nil then
        local body = client.shipCameraGetControlledBody()
        if body ~= nil and body ~= 0 then
            return body
        end
    end

    local veh = GetPlayerVehicle()
    if veh == nil or veh == 0 then
        return 0
    end

    local playerBody = GetVehicleBody(veh)
    local scriptBody = client.shipBody or 0
    if scriptBody == 0 or playerBody == nil or playerBody == 0 or playerBody ~= scriptBody then
        return 0
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(scriptBody)) then
        return 0
    end

    return scriptBody
end

local function _countLines(text)
    local count = 1
    local s = tostring(text or "")
    for _ in string.gmatch(s, "\n") do
        count = count + 1
    end
    return count
end

local function _shipHelpDrawTextBlock(x, y, text, fontSize, color)
    local lineHeight = fontSize + 4
    local lineIndex = 0
    local content = tostring(text or "") .. "\n"

    for line in string.gmatch(content, "(.-)\n") do
        UiPush()
            UiTranslate(x, y + lineIndex * lineHeight)
            UiColor(color[1], color[2], color[3], color[4])
            UiFont("regular.ttf", fontSize)
            UiText(line)
        UiPop()

        lineIndex = lineIndex + 1
    end

    return lineIndex * lineHeight
end

local function _shipHelpMeasureTextBlock(fontSize, text)
    return _countLines(text) * (fontSize + 4)
end

local function _shipHelpMeasureRow(row, cfg)
    local keyHeight = _shipHelpMeasureTextBlock(cfg.textSize, row.key)
    local titleHeight = _shipHelpMeasureTextBlock(cfg.textSize, row.title)
    local subtitleHeight = _shipHelpMeasureTextBlock(cfg.textSize - 2, row.subtitle)

    local contentHeight = titleHeight + subtitleHeight
    if keyHeight > contentHeight then
        return keyHeight
    end
    return contentHeight
end

local function _shipHelpDrawRow(y, row, cfg)
    local contentX = 14 + cfg.keyWidth + 12
    local titleHeight = _shipHelpMeasureTextBlock(cfg.textSize, row.title)
    local subtitleY = y + titleHeight

    _shipHelpDrawTextBlock(14, y, row.key, cfg.textSize, cfg.keyColor)
    _shipHelpDrawTextBlock(contentX, y, row.title, cfg.textSize, cfg.textColor)
    _shipHelpDrawTextBlock(contentX, subtitleY, row.subtitle, cfg.textSize - 2, cfg.subColor)

    return _shipHelpMeasureRow(row, cfg)
end

local function _shipHelpComputePanelHeight(cfg)
    local height = 48
    for i = 1, #shipHelpOverlayRows do
        height = height + _shipHelpMeasureRow(shipHelpOverlayRows[i], cfg) + cfg.rowGap
    end
    return height + 14
end

function client.shipHelpOverlayTick(dt)
    local _ = dt
    if InputPressed("u") then
        client.shipHelpOverlayState.visible = not client.shipHelpOverlayState.visible
    end
end

function client.shipHelpOverlayDraw()
    local state = client.shipHelpOverlayState
    if not state.visible then
        return
    end

    if _shipHelpResolveControlledShipBody() == 0 then
        return
    end

    local cfg = client.shipHelpOverlayConfig
    local panelW = cfg.width
    local panelH = _shipHelpComputePanelHeight(cfg)
    local x = UiWidth() - panelW - cfg.rightOffset
    local y = cfg.topOffset

    UiPush()
        UiAlign("left top")
        UiTranslate(x, y)
        UiColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        UiRect(panelW, panelH)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
        UiRectOutline(panelW, panelH, 2)

        UiPush()
            UiTranslate(14, 12)
            UiColor(cfg.titleColor[1], cfg.titleColor[2], cfg.titleColor[3], cfg.titleColor[4])
            UiFont("regular.ttf", cfg.titleSize)
            UiText("Ship Controls")
        UiPop()

        local rowY = 48
        for i = 1, #shipHelpOverlayRows do
            rowY = rowY + _shipHelpDrawRow(rowY, shipHelpOverlayRows[i], cfg) + cfg.rowGap
        end
    UiPop()
end
