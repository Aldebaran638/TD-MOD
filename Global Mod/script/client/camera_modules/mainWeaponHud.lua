---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponHudConfig = client.mainWeaponHudConfig or {
    panelWidth = 260,
    panelHeight = 110,
    rightOffset = 270,
    bottomOffset = 34,
    heatBarWidth = 180,
    heatBarHeight = 12,
    heatBarOffsetY = 12,
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
    xSlotColor = { 0.18, 0.82, 1.0, 0.95 },
    lSlotColor = { 1.0, 0.42, 0.12, 0.95 },
    heatBgColor = { 0.14, 0.16, 0.18, 0.95 },
    heatFillColor = { 1.0, 0.72, 0.18, 0.96 },
    heatOverColor = { 1.0, 0.22, 0.10, 0.98 },
}

client.mainWeaponHudState = client.mainWeaponHudState or {
    active = false,
    shipBody = 0,
    currentMainWeapon = "xSlot",
    heatFraction = 0.0,
    targetHeatFraction = 0.0,
    overheated = false,
    xSlotFill1 = 1.0,
    xSlotFill2 = 1.0,
}

client.lSlotHudStateByShip = client.lSlotHudStateByShip or {}
client.xSlotHudStateByShip = client.xSlotHudStateByShip or {}

local function _mainWeaponHudClamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function _mainWeaponHudSmooth(curr, target, speed, dt)
    local k = math.min(1.0, (speed or 8.0) * (dt or 0.0))
    return curr + (target - curr) * k
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

local function _getOrCreateLSlotHudState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local states = client.lSlotHudStateByShip
    local hud = states[body]
    if hud == nil then
        hud = {
            heat = 0.0,
            overheated = false,
            overheatThreshold = 100.0,
        }
        states[body] = hud
    end
    return hud
end

local function _getOrCreateXSlotHudState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local states = client.xSlotHudStateByShip
    local hud = states[body]
    if hud == nil then
        hud = {
            cd1 = 0.0,
            cd2 = 0.0,
            maxCd1 = 1.0,
            maxCd2 = 1.0,
        }
        states[body] = hud
    end
    return hud
end

function client.initLSlotHudState(shipBodyId, overheatThreshold)
    local hud = _getOrCreateLSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    hud.overheatThreshold = math.max(1.0, tonumber(overheatThreshold) or 100.0)
end

function client.updateLSlotHudState(shipBodyId, heat, overheated)
    local hud = _getOrCreateLSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    hud.heat = math.max(0.0, tonumber(heat) or 0.0)
    hud.overheated = (math.floor(overheated or 0) ~= 0)
end

function client.resetLSlotHudState(shipBodyId)
    local hud = _getOrCreateLSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    hud.heat = 0.0
    hud.overheated = false
end

function client.updateXSlotHudState(shipBodyId, cd1, cd2, maxCd1, maxCd2)
    local hud = _getOrCreateXSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    hud.cd1 = math.max(0.0, tonumber(cd1) or 0.0)
    hud.cd2 = math.max(0.0, tonumber(cd2) or 0.0)
    hud.maxCd1 = math.max(0.0, tonumber(maxCd1) or 0.0)
    hud.maxCd2 = math.max(0.0, tonumber(maxCd2) or 0.0)
end

function client.mainWeaponHudTick(dt)
    local cfg = client.mainWeaponHudConfig
    local state = client.mainWeaponHudState

    local body = _resolveControlledShipBody()
    if body == 0 then
        state.active = false
        state.shipBody = 0
        state.targetHeatFraction = 0.0
        state.heatFraction = 0.0
        state.currentMainWeapon = "xSlot"
        state.overheated = false
        state.xSlotFill1 = 1.0
        state.xSlotFill2 = 1.0
        return
    end

    state.active = true
    state.shipBody = body
    if client.getShipMainWeaponMode ~= nil then
        state.currentMainWeapon = client.getShipMainWeaponMode(body)
    else
        state.currentMainWeapon = "xSlot"
    end

    local hud = client.lSlotHudStateByShip[body] or {
        heat = 0.0,
        overheated = false,
        overheatThreshold = 100.0,
    }
    local threshold = math.max(1.0, hud.overheatThreshold or 100.0)
    local displayHeat = hud.heat or 0.0
    state.targetHeatFraction = _mainWeaponHudClamp(displayHeat / threshold, 0.0, 1.0)
    state.heatFraction = _mainWeaponHudSmooth(state.heatFraction, state.targetHeatFraction, cfg.smoothSpeed, dt)
    state.overheated = hud.overheated and true or false

    local xHud = client.xSlotHudStateByShip[body] or {
        cd1 = 0.0,
        cd2 = 0.0,
        maxCd1 = 1.0,
        maxCd2 = 1.0,
    }
    local cd1 = math.max(0.0, xHud.cd1 or 0.0)
    local cd2 = math.max(0.0, xHud.cd2 or 0.0)
    local maxCd1 = math.max(0.0, xHud.maxCd1 or 0.0)
    local maxCd2 = math.max(0.0, xHud.maxCd2 or 0.0)

    if maxCd1 > 0.0001 then
        state.xSlotFill1 = _mainWeaponHudClamp(1.0 - (cd1 / maxCd1), 0.0, 1.0)
    else
        state.xSlotFill1 = 1.0
    end

    if maxCd2 > 0.0001 then
        state.xSlotFill2 = _mainWeaponHudClamp(1.0 - (cd2 / maxCd2), 0.0, 1.0)
    else
        state.xSlotFill2 = 1.0
    end
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
        UiColor(cfg.xSlotColor[1], cfg.xSlotColor[2], cfg.xSlotColor[3], cfg.xSlotColor[4])
        UiRect(w * _mainWeaponHudClamp(fill or 0.0, 0.0, 1.0), h)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], 0.55)
        UiRectOutline(w, h, 1)
    UiPop()
end

local function _drawWeaponIcon(x, y, size, fillColor, label, selected, borderColor, inactiveColor)
    UiPush()
        UiTranslate(x, y)
        UiColor(fillColor[1], fillColor[2], fillColor[3], selected and fillColor[4] or 0.35)
        UiRect(size, size)
        UiColor(borderColor[1], borderColor[2], borderColor[3], selected and 0.75 or 0.22)
        UiRectOutline(size, size, 2)
        UiColor(1, 1, 1, selected and 1.0 or 0.72)
        UiFont("regular.ttf", math.floor(size * 0.48))
        UiAlign("center middle")
        UiTranslate(size * 0.5, size * 0.54)
        UiText(label)
    UiPop()
end

function client.mainWeaponHudDraw()
    local cfg = client.mainWeaponHudConfig
    local state = client.mainWeaponHudState
    if not state.active then
        return
    end

    local panelW = cfg.panelWidth
    local panelH = cfg.panelHeight
    local x = UiWidth() - panelW - cfg.rightOffset
    local y = UiHeight() - panelH - cfg.bottomOffset
    local currentMode = state.currentMainWeapon or "xSlot"

    UiPush()
        UiAlign("left top")
        UiTranslate(x, y)
        UiColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        UiRect(panelW, panelH)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
        UiRectOutline(panelW, panelH, 2)

        UiPush()
            UiTranslate(12, cfg.heatBarOffsetY)
            UiColor(cfg.heatBgColor[1], cfg.heatBgColor[2], cfg.heatBgColor[3], cfg.heatBgColor[4])
            UiRect(cfg.heatBarWidth, cfg.heatBarHeight)

            local fill = cfg.heatFillColor
            if state.overheated then
                fill = cfg.heatOverColor
            end
            UiColor(fill[1], fill[2], fill[3], fill[4])
            UiRect(cfg.heatBarWidth * state.heatFraction, cfg.heatBarHeight)

            UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], 0.55)
            UiRectOutline(cfg.heatBarWidth, cfg.heatBarHeight, 1)
        UiPop()

        UiPush()
            UiTranslate(198, cfg.heatBarOffsetY - 4)
            UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
            UiFont("regular.ttf", cfg.valueSize)
            if state.overheated then
                UiText("OVERHEAT")
            else
                UiText(string.format("HEAT %d%%", math.floor(state.heatFraction * 100 + 0.5)))
            end
        UiPop()

        _drawWeaponIcon(12, 36, cfg.iconSize, cfg.xSlotColor, "X", currentMode == "xSlot", cfg.borderColor, cfg.inactiveColor)
        _drawWeaponIcon(46, 36, cfg.iconSize, cfg.lSlotColor, "L", currentMode == "lSlot", cfg.borderColor, cfg.inactiveColor)

        UiPush()
            UiTranslate(84, 34)
            UiColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
            UiFont("regular.ttf", cfg.labelSize)
            if currentMode == "lSlot" then
                UiText("Kinetic Artillery")
            else
                UiText("Tachyon Lance")
            end
        UiPop()

        UiPush()
            UiTranslate(84, 54)
            UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
            UiFont("regular.ttf", cfg.valueSize)
            UiText((currentMode == "lSlot") and "Main Weapon: L-Slot" or "Main Weapon: X-Slot")
        UiPop()

        _drawXCooldownBar(12, 78, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.xSlotFill1, "X1", cfg)
        _drawXCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 78, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.xSlotFill2, "X2", cfg)
    UiPop()
end
