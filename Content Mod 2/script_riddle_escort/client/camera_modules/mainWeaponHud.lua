---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponHudConfig = client.mainWeaponHudConfig or {
    panelWidth = 290,
    panelHeight = 118,
    rightOffset = 270,
    bottomOffset = 34,
    topBarWidth = 190,
    topBarHeight = 12,
    topBarOffsetY = 12,
    xCooldownBarWidth = 72,
    xCooldownBarHeight = 8,
    xCooldownBarGap = 12,
    iconSize = 26,
    labelSize = 18,
    valueSize = 14,
    smoothSpeed = 8.0,

    bgColor = { 0.06, 0.07, 0.09, 0.78 },
    borderColor = { 1.0, 1.0, 1.0, 0.30 },
    textColor = { 0.95, 0.96, 0.98, 1.0 },
    subTextColor = { 0.78, 0.82, 0.86, 0.92 },
    inactiveColor = { 0.22, 0.25, 0.30, 0.95 },
    sColor = { 1.0, 0.84, 0.18, 0.95 },
    pColor = { 0.30, 0.96, 0.45, 0.95 },
    gColor = { 0.78, 0.30, 1.0, 0.95 },
    heatBgColor = { 0.14, 0.16, 0.18, 0.95 },
    heatFillColor = { 1.0, 0.72, 0.18, 0.96 },
    heatOverColor = { 1.0, 0.22, 0.10, 0.98 },
    lockFillColor = { 1.0, 0.82, 0.24, 0.96 },
    lockReadyColor = { 1.0, 0.24, 0.18, 0.98 },
}

client.mainWeaponHudState = client.mainWeaponHudState or {
    active = false,
    shipBody = 0,
    currentMainWeapon = "sSlot",
}

client.escortSHudByShip = client.escortSHudByShip or {}
client.escortPHudByShip = client.escortPHudByShip or {}
client.escortGHudByShip = client.escortGHudByShip or {}

local function _clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function _resolveControlledShipBody()
    if client.shipCameraGetControlledBody ~= nil then
        local body = client.shipCameraGetControlledBody()
        if body ~= nil and body ~= 0 then
            return body
        end
    end

    local veh = GetPlayerVehicle()
    if veh == nil or veh == 0 then
        local localPlayerId = GetLocalPlayer()
        if localPlayerId ~= nil and localPlayerId ~= 0 then
            veh = GetPlayerVehicle(localPlayerId)
        end
    end
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

function client.updateEscortSHudState(shipBodyId, cd1, cd2, cd3, cd4, maxCd1, maxCd2, maxCd3, maxCd4)
    client.escortSHudByShip[math.floor(shipBodyId or 0)] = {
        cd = { tonumber(cd1) or 0.0, tonumber(cd2) or 0.0, tonumber(cd3) or 0.0, tonumber(cd4) or 0.0 },
        maxCd = { tonumber(maxCd1) or 0.0, tonumber(maxCd2) or 0.0, tonumber(maxCd3) or 0.0, tonumber(maxCd4) or 0.0 },
    }
end

function client.updateEscortPHudState(shipBodyId, heat1, over1, threshold1, heat2, over2, threshold2)
    client.escortPHudByShip[math.floor(shipBodyId or 0)] = {
        heat = { tonumber(heat1) or 0.0, tonumber(heat2) or 0.0 },
        overheated = { math.floor(over1 or 0) ~= 0, math.floor(over2 or 0) ~= 0 },
        threshold = { tonumber(threshold1) or 100.0, tonumber(threshold2) or 100.0 },
    }
end

function client.resetEscortPHudState(shipBodyId)
    client.escortPHudByShip[math.floor(shipBodyId or 0)] = {
        heat = { 0.0, 0.0 },
        overheated = { false, false },
        threshold = { 100.0, 100.0 },
    }
end

function client.updateEscortGHudState(shipBodyId, cd1, cd2, cd3, maxCd1, maxCd2, maxCd3)
    client.escortGHudByShip[math.floor(shipBodyId or 0)] = {
        cd = { tonumber(cd1) or 0.0, tonumber(cd2) or 0.0, tonumber(cd3) or 0.0 },
        maxCd = { tonumber(maxCd1) or 0.0, tonumber(maxCd2) or 0.0, tonumber(maxCd3) or 0.0 },
    }
end

function client.mainWeaponHudTick(dt)
    local _ = dt
    local state = client.mainWeaponHudState
    local body = _resolveControlledShipBody()
    if body == 0 then
        state.active = false
        state.shipBody = 0
        state.currentMainWeapon = "sSlot"
        return
    end

    state.active = true
    state.shipBody = body
    if client.getShipMainWeaponMode ~= nil then
        state.currentMainWeapon = client.getShipMainWeaponMode(body)
    end
end

local function _mainWeaponHudClamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function _drawWeaponIcon(x, y, size, fillColor, label, selected, cfg)
    UiPush()
        UiTranslate(x, y)
        UiColor(fillColor[1], fillColor[2], fillColor[3], selected and fillColor[4] or 0.35)
        UiRect(size, size)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], selected and 0.75 or 0.22)
        UiRectOutline(size, size, 2)
        UiColor(1, 1, 1, selected and 1.0 or 0.72)
        UiFont("regular.ttf", math.floor(size * 0.48))
        UiAlign("center middle")
        UiTranslate(size * 0.5, size * 0.54)
        UiText(label)
    UiPop()
end

local function _drawTopBar(x, y, width, height, fillFraction, fillColor, text, cfg)
    UiPush()
        UiTranslate(x, y)
        UiColor(cfg.heatBgColor[1], cfg.heatBgColor[2], cfg.heatBgColor[3], cfg.heatBgColor[4])
        UiRect(width, height)
        UiColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
        UiRect(width * _mainWeaponHudClamp(fillFraction or 0.0, 0.0, 1.0), height)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], 0.55)
        UiRectOutline(width, height, 1)
    UiPop()

    UiPush()
        UiTranslate(x + width + 10, y - 4)
        UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
        UiFont("regular.ttf", cfg.valueSize)
        UiText(text)
    UiPop()
end

local function _drawXCooldownBar(x, y, w, h, fill, label, cfg)
    UiPush()
        UiTranslate(x, y)
        UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
        UiFont("regular.ttf", cfg.valueSize)
        UiText(label)

        UiTranslate(24, 3)
        UiColor(cfg.heatBgColor[1], cfg.heatBgColor[2], cfg.heatBgColor[3], cfg.heatBgColor[4])
        UiRect(w, h)
        UiColor(cfg.sColor[1], cfg.sColor[2], cfg.sColor[3], cfg.sColor[4])
        UiRect(w * _mainWeaponHudClamp(fill or 0.0, 0.0, 1.0), h)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], 0.55)
        UiRectOutline(w, h, 1)
    UiPop()
end

local function _drawPCooldownBar(x, y, w, h, fill, label, cfg)
    UiPush()
        UiTranslate(x, y)
        UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
        UiFont("regular.ttf", cfg.valueSize)
        UiText(label)

        UiTranslate(24, 3)
        UiColor(cfg.heatBgColor[1], cfg.heatBgColor[2], cfg.heatBgColor[3], cfg.heatBgColor[4])
        UiRect(w, h)
        UiColor(cfg.pColor[1], cfg.pColor[2], cfg.pColor[3], cfg.pColor[4])
        UiRect(w * _mainWeaponHudClamp(fill or 0.0, 0.0, 1.0), h)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], 0.55)
        UiRectOutline(w, h, 1)
    UiPop()
end

local function _drawGCooldownBar(x, y, w, h, fill, label, cfg)
    UiPush()
        UiTranslate(x, y)
        UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
        UiFont("regular.ttf", cfg.valueSize)
        UiText(label)

        UiTranslate(24, 3)
        UiColor(cfg.heatBgColor[1], cfg.heatBgColor[2], cfg.heatBgColor[3], cfg.heatBgColor[4])
        UiRect(w, h)
        UiColor(cfg.gColor[1], cfg.gColor[2], cfg.gColor[3], cfg.gColor[4])
        UiRect(w * _mainWeaponHudClamp(fill or 0.0, 0.0, 1.0), h)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], 0.55)
        UiRectOutline(w, h, 1)
    UiPop()
end

function client.mainWeaponHudDraw()
    local state = client.mainWeaponHudState
    if not state.active then
        return
    end

    local cfg = client.mainWeaponHudConfig
    local panelW = cfg.panelWidth
    local panelH = cfg.panelHeight
    local x = UiWidth() - panelW - cfg.rightOffset
    local y = UiHeight() - panelH - cfg.bottomOffset
    local currentMode = state.currentMainWeapon or "sSlot"

    local topFill = 0
    local topText = ""
    local topColor = cfg.sColor
    local titleText = "Gamma Laser"
    local modeText = "Main Weapon: S-Slot"

    if currentMode == "pSlot" then
        topFill = 0
        topText = "READY"
        topColor = cfg.pColor
        titleText = "Nanite Flak Battery"
        modeText = "Main Weapon: P-Slot"
    elseif currentMode == "gSlot" then
        topFill = 0
        topText = "READY"
        topColor = cfg.gColor
        titleText = "Destroyer Missiles"
        modeText = "Main Weapon: G-Slot"
    end

    UiPush()
        UiAlign("left top")
        UiTranslate(x, y)
        UiColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        UiRect(panelW, panelH)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
        UiRectOutline(panelW, panelH, 2)

        _drawTopBar(12, cfg.topBarOffsetY, cfg.topBarWidth, cfg.topBarHeight, topFill, topColor, topText, cfg)

        _drawWeaponIcon(12, 36, cfg.iconSize, cfg.sColor, "S", currentMode == "sSlot", cfg)
        _drawWeaponIcon(46, 36, cfg.iconSize, cfg.pColor, "P", currentMode == "pSlot", cfg)
        _drawWeaponIcon(80, 36, cfg.iconSize, cfg.gColor, "G", currentMode == "gSlot", cfg)

        UiPush()
            UiTranslate(118, 34)
            UiColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
            UiFont("regular.ttf", cfg.labelSize)
            UiText(titleText)
        UiPop()

        UiPush()
            UiTranslate(118, 54)
            UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
            UiFont("regular.ttf", cfg.valueSize)
            UiText(modeText)
        UiPop()

        if currentMode == "sSlot" then
            local hud = client.escortSHudByShip[state.shipBody] or { cd = { 0, 0, 0, 0 }, maxCd = { 1, 1, 1, 1 } }
            local fills = {}
            for i = 1, 4 do
                local maxCd = math.max(0.0001, hud.maxCd[i] or 1.0)
                fills[i] = 1.0 - _mainWeaponHudClamp((hud.cd[i] or 0.0) / maxCd, 0.0, 1.0)
            end
            _drawXCooldownBar(12, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[1], "S1", cfg)
            _drawXCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[2], "S2", cfg)
            _drawXCooldownBar(12, 96, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[3], "S3", cfg)
            _drawXCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 96, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[4], "S4", cfg)
        elseif currentMode == "pSlot" then
            local hud = client.escortPHudByShip[state.shipBody] or { heat = { 0, 0 }, overheated = { false, false }, threshold = { 100, 100 } }
            local fills = {}
            for i = 1, 2 do
                local threshold = math.max(1.0, hud.threshold[i] or 100.0)
                fills[i] = _mainWeaponHudClamp((hud.heat[i] or 0.0) / threshold, 0.0, 1.0)
            end
            _drawPCooldownBar(12, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[1], "P1", cfg)
            _drawPCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[2], "P2", cfg)
        else
            local hud = client.escortGHudByShip[state.shipBody] or { cd = { 0, 0, 0 }, maxCd = { 1, 1, 1 } }
            local fills = {}
            for i = 1, 3 do
                local maxCd = math.max(0.0001, hud.maxCd[i] or 1.0)
                fills[i] = 1.0 - _mainWeaponHudClamp((hud.cd[i] or 0.0) / maxCd, 0.0, 1.0)
            end
            _drawGCooldownBar(12, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[1], "G1", cfg)
            _drawGCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[2], "G2", cfg)
            _drawGCooldownBar(12, 96, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, fills[3], "G3", cfg)
        end
    UiPop()
end
