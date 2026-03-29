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
    tSlotColor = { 0.94, 0.20, 0.16, 0.98 },
    lSlotColor = { 1.0, 0.42, 0.12, 0.95 },
    mSlotColor = { 1.0, 0.84, 0.18, 0.95 },
    heatBgColor = { 0.14, 0.16, 0.18, 0.95 },
    heatFillColor = { 1.0, 0.72, 0.18, 0.96 },
    heatOverColor = { 1.0, 0.22, 0.10, 0.98 },
    lockFillColor = { 1.0, 0.82, 0.24, 0.96 },
    lockReadyColor = { 1.0, 0.24, 0.18, 0.98 },
}

client.mainWeaponHudState = client.mainWeaponHudState or {
    active = false,
    shipBody = 0,
    currentMainWeapon = "tSlot",
    lSlotHeatFraction1 = 0.0,
    targetLSlotHeatFraction1 = 0.0,
    lSlotHeatFraction2 = 0.0,
    targetLSlotHeatFraction2 = 0.0,
    lSlotOverheated1 = false,
    lSlotOverheated2 = false,
    tSlotFill1 = 1.0,
    tSlotFill2 = 1.0,
    tSlotPhase1 = "idle",
    tSlotPhase2 = "idle",
    sSlotProgress = 0.0,
    targetSSlotProgress = 0.0,
    sSlotStatus = "NO TARGET",
    sSlotFill1 = 1.0,
    sSlotFill2 = 1.0,
    sSlotFill3 = 1.0,
    sSlotFill4 = 1.0,
}

client.lSlotHudStateByShip = client.lSlotHudStateByShip or {}
client.tSlotHudStateByShip = client.tSlotHudStateByShip or {}
client.sSlotHudStateByShip = client.sSlotHudStateByShip or {}

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
            groups = {
                {
                    heat = 0.0,
                    overheated = false,
                    overheatThreshold = 100.0,
                },
                {
                    heat = 0.0,
                    overheated = false,
                    overheatThreshold = 100.0,
                },
            },
        }
        states[body] = hud
    end
    return hud
end

local function _getOrCreateTSlotHudState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local states = client.tSlotHudStateByShip
    local hud = states[body]
    if hud == nil then
        hud = {
            value1 = 0.0,
            value2 = 0.0,
            maxValue1 = 1.0,
            maxValue2 = 1.0,
            phase1 = "idle",
            phase2 = "idle",
        }
        states[body] = hud
    end
    return hud
end

function client.initLSlotHudState(shipBodyId, overheatThreshold1, overheatThreshold2)
    local hud = _getOrCreateLSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    hud.groups[1].overheatThreshold = math.max(1.0, tonumber(overheatThreshold1) or 100.0)
    hud.groups[2].overheatThreshold = math.max(1.0, tonumber(overheatThreshold2) or 100.0)
end

function client.updateLSlotHudState(shipBodyId, heat1, overheated1, heat2, overheated2)
    local hud = _getOrCreateLSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    hud.groups[1].heat = math.max(0.0, tonumber(heat1) or 0.0)
    hud.groups[1].overheated = (math.floor(overheated1 or 0) ~= 0)
    hud.groups[2].heat = math.max(0.0, tonumber(heat2) or 0.0)
    hud.groups[2].overheated = (math.floor(overheated2 or 0) ~= 0)
end

function client.resetLSlotHudState(shipBodyId)
    local hud = _getOrCreateLSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    for i = 1, 2 do
        hud.groups[i].heat = 0.0
        hud.groups[i].overheated = false
    end
end

function client.updateTSlotHudState(shipBodyId, value1, value2, maxValue1, maxValue2, phase1, phase2)
    local hud = _getOrCreateTSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    hud.value1 = math.max(0.0, tonumber(value1) or 0.0)
    hud.value2 = math.max(0.0, tonumber(value2) or 0.0)
    hud.maxValue1 = math.max(0.0, tonumber(maxValue1) or 0.0)
    hud.maxValue2 = math.max(0.0, tonumber(maxValue2) or 0.0)
    hud.phase1 = tostring(phase1 or "idle")
    hud.phase2 = tostring(phase2 or "idle")
end

local function _resolveTSlotFill(value, maxValue, phase)
    local maxV = math.max(0.0, tonumber(maxValue) or 0.0)
    local curr = math.max(0.0, tonumber(value) or 0.0)
    local p = tostring(phase or "idle")

    if p == "charging" or p == "decaying" or p == "charged" or p == "launching" then
        if maxV <= 0.0001 then
            return (p == "charged") and 1.0 or 0.0
        end
        return _mainWeaponHudClamp(curr / maxV, 0.0, 1.0)
    end

    if p == "cooldown" then
        if maxV <= 0.0001 then
            return 1.0
        end
        return _mainWeaponHudClamp(1.0 - (curr / maxV), 0.0, 1.0)
    end

    return 1.0
end

local function _tSlotPhasePriority(phase)
    local p = tostring(phase or "idle")
    if p == "charged" then return 6 end
    if p == "charging" then return 5 end
    if p == "launching" then return 4 end
    if p == "decaying" then return 3 end
    if p == "cooldown" then return 2 end
    return 1
end

local function _resolveTSlotTopStatus(state)
    local phase1 = tostring(state.tSlotPhase1 or "idle")
    local phase2 = tostring(state.tSlotPhase2 or "idle")
    local fill1 = tonumber(state.tSlotFill1) or 1.0
    local fill2 = tonumber(state.tSlotFill2) or 1.0

    local phase = phase1
    local fill = fill1
    if _tSlotPhasePriority(phase2) > _tSlotPhasePriority(phase1) or (_tSlotPhasePriority(phase2) == _tSlotPhasePriority(phase1) and fill2 > fill1) then
        phase = phase2
        fill = fill2
    end

    if phase == "charged" then
        return 1.0, "CHARGED"
    end
    if phase == "charging" then
        return fill, string.format("CHARGE %d%%", math.floor(fill * 100 + 0.5))
    end
    if phase == "launching" then
        return fill, string.format("FIRING %d%%", math.floor(fill * 100 + 0.5))
    end
    if phase == "decaying" then
        return fill, string.format("DECAY %d%%", math.floor(fill * 100 + 0.5))
    end
    if phase == "cooldown" then
        return fill, string.format("RECOVER %d%%", math.floor(fill * 100 + 0.5))
    end
    return 1.0, "READY"
end

local function _getOrCreateSSlotHudState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local states = client.sSlotHudStateByShip
    local hud = states[body]
    if hud == nil then
        hud = {
            cd1 = 0.0,
            cd2 = 0.0,
            cd3 = 0.0,
            cd4 = 0.0,
            maxCd1 = 1.0,
            maxCd2 = 1.0,
            maxCd3 = 1.0,
            maxCd4 = 1.0,
        }
        states[body] = hud
    end
    return hud
end

function client.updateSSlotHudState(shipBodyId, cd1, cd2, cd3, cd4, maxCd1, maxCd2, maxCd3, maxCd4)
    local hud = _getOrCreateSSlotHudState(shipBodyId)
    if hud == nil then
        return
    end
    hud.cd1 = math.max(0.0, tonumber(cd1) or 0.0)
    hud.cd2 = math.max(0.0, tonumber(cd2) or 0.0)
    hud.cd3 = math.max(0.0, tonumber(cd3) or 0.0)
    hud.cd4 = math.max(0.0, tonumber(cd4) or 0.0)
    hud.maxCd1 = math.max(0.0, tonumber(maxCd1) or 0.0)
    hud.maxCd2 = math.max(0.0, tonumber(maxCd2) or 0.0)
    hud.maxCd3 = math.max(0.0, tonumber(maxCd3) or 0.0)
    hud.maxCd4 = math.max(0.0, tonumber(maxCd4) or 0.0)
end

function client.mainWeaponHudTick(dt)
    local cfg = client.mainWeaponHudConfig
    local state = client.mainWeaponHudState

    local body = _resolveControlledShipBody()
    if body == 0 then
        state.active = false
        state.shipBody = 0
        state.targetLSlotHeatFraction1 = 0.0
        state.lSlotHeatFraction1 = 0.0
        state.targetLSlotHeatFraction2 = 0.0
        state.lSlotHeatFraction2 = 0.0
        state.currentMainWeapon = "tSlot"
        state.lSlotOverheated1 = false
        state.lSlotOverheated2 = false
        state.tSlotFill1 = 1.0
    state.tSlotFill2 = 1.0
    state.tSlotPhase1 = "idle"
    state.tSlotPhase2 = "idle"
        state.targetSSlotProgress = 0.0
        state.sSlotProgress = 0.0
        state.sSlotStatus = "NO TARGET"
        return
    end

    state.active = true
    state.shipBody = body
    if client.getShipMainWeaponMode ~= nil then
        state.currentMainWeapon = client.getShipMainWeaponMode(body)
    else
        state.currentMainWeapon = "tSlot"
    end

    local hud = client.lSlotHudStateByShip[body] or {
        groups = {
            {
                heat = 0.0,
                overheated = false,
                overheatThreshold = 100.0,
            },
            {
                heat = 0.0,
                overheated = false,
                overheatThreshold = 100.0,
            },
        },
    }
    local group1 = hud.groups[1] or { heat = 0.0, overheated = false, overheatThreshold = 100.0 }
    local group2 = hud.groups[2] or { heat = 0.0, overheated = false, overheatThreshold = 100.0 }
    local threshold1 = math.max(1.0, group1.overheatThreshold or 100.0)
    local threshold2 = math.max(1.0, group2.overheatThreshold or 100.0)
    state.targetLSlotHeatFraction1 = _mainWeaponHudClamp((group1.heat or 0.0) / threshold1, 0.0, 1.0)
    state.targetLSlotHeatFraction2 = _mainWeaponHudClamp((group2.heat or 0.0) / threshold2, 0.0, 1.0)
    state.lSlotHeatFraction1 = _mainWeaponHudSmooth(state.lSlotHeatFraction1, state.targetLSlotHeatFraction1, cfg.smoothSpeed, dt)
    state.lSlotHeatFraction2 = _mainWeaponHudSmooth(state.lSlotHeatFraction2, state.targetLSlotHeatFraction2, cfg.smoothSpeed, dt)
    state.lSlotOverheated1 = group1.overheated and true or false
    state.lSlotOverheated2 = group2.overheated and true or false

    local tHud = client.tSlotHudStateByShip[body] or {
        value1 = 0.0,
        value2 = 0.0,
        maxValue1 = 1.0,
        maxValue2 = 1.0,
        phase1 = "idle",
        phase2 = "idle",
    }
    state.tSlotPhase1 = tostring(tHud.phase1 or "idle")
    state.tSlotPhase2 = tostring(tHud.phase2 or "idle")
    state.tSlotFill1 = _resolveTSlotFill(tHud.value1, tHud.maxValue1, tHud.phase1)
    state.tSlotFill2 = _resolveTSlotFill(tHud.value2, tHud.maxValue2, tHud.phase2)

    if client.sSlotTargetingGetSummary ~= nil then
        local statusText, progress = client.sSlotTargetingGetSummary(body)
        state.sSlotStatus = statusText or "NO TARGET"
        state.targetSSlotProgress = _mainWeaponHudClamp(progress or 0.0, 0.0, 1.0)
    else
        state.sSlotStatus = "NO TARGET"
        state.targetSSlotProgress = 0.0
    end
    state.sSlotProgress = _mainWeaponHudSmooth(state.sSlotProgress, state.targetSSlotProgress, cfg.smoothSpeed, dt)



    local sHud = client.sSlotHudStateByShip[body] or {
        cd1 = 0.0,
        cd2 = 0.0,
        cd3 = 0.0,
        cd4 = 0.0,
        maxCd1 = 1.0,
        maxCd2 = 1.0,
        maxCd3 = 1.0,
        maxCd4 = 1.0,
    }
    local cd1 = math.max(0.0, sHud.cd1 or 0.0)
    local cd2 = math.max(0.0, sHud.cd2 or 0.0)
    local cd3 = math.max(0.0, sHud.cd3 or 0.0)
    local cd4 = math.max(0.0, sHud.cd4 or 0.0)
    local maxCd1 = math.max(0.0, sHud.maxCd1 or 0.0)
    local maxCd2 = math.max(0.0, sHud.maxCd2 or 0.0)
    local maxCd3 = math.max(0.0, sHud.maxCd3 or 0.0)
    local maxCd4 = math.max(0.0, sHud.maxCd4 or 0.0)

    if maxCd1 > 0.0001 then
        state.sSlotFill1 = _mainWeaponHudClamp(1.0 - (cd1 / maxCd1), 0.0, 1.0)
    else
        state.sSlotFill1 = 1.0
    end

    if maxCd2 > 0.0001 then
        state.sSlotFill2 = _mainWeaponHudClamp(1.0 - (cd2 / maxCd2), 0.0, 1.0)
    else
        state.sSlotFill2 = 1.0
    end

    if maxCd3 > 0.0001 then
        state.sSlotFill3 = _mainWeaponHudClamp(1.0 - (cd3 / maxCd3), 0.0, 1.0)
    else
        state.sSlotFill3 = 1.0
    end

    if maxCd4 > 0.0001 then
        state.sSlotFill4 = _mainWeaponHudClamp(1.0 - (cd4 / maxCd4), 0.0, 1.0)
    else
        state.sSlotFill4 = 1.0
    end
end

local function _resolveLSlotTopStatus(state)
    local fill1 = tonumber(state.lSlotHeatFraction1) or 0.0
    local fill2 = tonumber(state.lSlotHeatFraction2) or 0.0
    local text = string.format(
        "L1 %d%% / L2 %d%%",
        math.floor(fill1 * 100 + 0.5),
        math.floor(fill2 * 100 + 0.5)
    )
    return math.max(fill1, fill2), text
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

local function _drawXCooldownBar(x, y, w, h, fill, label, cfg, fillColor)
    local color = fillColor or cfg.tSlotColor
    UiPush()
        UiTranslate(x, y)
        UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
        UiFont("regular.ttf", cfg.valueSize)
        UiText(label)

        UiTranslate(24, 3)
        UiColor(cfg.heatBgColor[1], cfg.heatBgColor[2], cfg.heatBgColor[3], cfg.heatBgColor[4])
        UiRect(w, h)
        UiColor(color[1], color[2], color[3], color[4])
        UiRect(w * _mainWeaponHudClamp(fill or 0.0, 0.0, 1.0), h)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], 0.55)
        UiRectOutline(w, h, 1)
    UiPop()
end

function client.sSlotGetCooldown()
    local cooldown, maxCooldown = ClientCall(0, "server.sSlotGetCooldown")
    return tonumber(cooldown) or 0.0, tonumber(maxCooldown) or 10.0
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
    local currentMode = state.currentMainWeapon or "tSlot"

    local topFill, topText = _resolveTSlotTopStatus(state)
    local topColor = cfg.tSlotColor
    local titleText = "Perdition Beam"
    local modeText = "Main Weapon: T-Slot"

    if currentMode == "lSlot" then
        topFill, topText = _resolveLSlotTopStatus(state)
        topColor = (state.lSlotOverheated1 or state.lSlotOverheated2) and cfg.heatOverColor or cfg.heatFillColor
        titleText = "Kinetic Artillery"
        modeText = "Main Weapon: L-Slot"
    elseif currentMode == "mSlot" then
        topFill = state.sSlotProgress
        topText = state.sSlotStatus or "NO TARGET"
        topColor = (state.sSlotStatus == "LOCKED") and cfg.lockReadyColor or cfg.lockFillColor
        titleText = "Missile Battery"
        modeText = "Main Weapon: M-Slot"
    end

    UiPush()
        UiAlign("left top")
        UiTranslate(x, y)
        UiColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        UiRect(panelW, panelH)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
        UiRectOutline(panelW, panelH, 2)

        _drawTopBar(12, cfg.topBarOffsetY, cfg.topBarWidth, cfg.topBarHeight, topFill, topColor, topText, cfg)

        _drawWeaponIcon(12, 36, cfg.iconSize, cfg.tSlotColor, "T", currentMode == "tSlot", cfg)
        _drawWeaponIcon(46, 36, cfg.iconSize, cfg.lSlotColor, "L", currentMode == "lSlot", cfg)
        _drawWeaponIcon(80, 36, cfg.iconSize, cfg.mSlotColor, "M", currentMode == "mSlot", cfg)

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

        if currentMode == "tSlot" then
            _drawXCooldownBar(12, 82, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.tSlotFill1, "T1", cfg, cfg.tSlotColor)
            _drawXCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 82, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.tSlotFill2, "T2", cfg, cfg.tSlotColor)
        elseif currentMode == "mSlot" then
            _drawXCooldownBar(12, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.sSlotFill1, "M1", cfg, cfg.mSlotColor)
            _drawXCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.sSlotFill2, "M2", cfg, cfg.mSlotColor)
            _drawXCooldownBar(12, 96, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.sSlotFill3, "M3", cfg, cfg.mSlotColor)
            _drawXCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 96, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.sSlotFill4, "M4", cfg, cfg.mSlotColor)
        else
            _drawXCooldownBar(
                12,
                82,
                cfg.xCooldownBarWidth,
                cfg.xCooldownBarHeight,
                state.lSlotHeatFraction1,
                "L1",
                cfg,
                state.lSlotOverheated1 and cfg.heatOverColor or cfg.lSlotColor
            )
            _drawXCooldownBar(
                12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap,
                82,
                cfg.xCooldownBarWidth,
                cfg.xCooldownBarHeight,
                state.lSlotHeatFraction2,
                "L2",
                cfg,
                state.lSlotOverheated2 and cfg.heatOverColor or cfg.lSlotColor
            )
        end
    UiPop()
end
