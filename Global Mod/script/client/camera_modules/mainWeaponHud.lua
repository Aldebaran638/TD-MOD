---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponHudConfig = client.mainWeaponHudConfig or {
    panelWidth = 260,
    panelHeight = 62,
    bottomOffset = 122,
    heatBarWidth = 180,
    heatBarHeight = 12,
    heatBarOffsetY = 34,
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
}

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

    local body = GetVehicleBody(veh)
    if body == nil or body == 0 then
        return 0
    end

    if client.registryShipExists ~= nil and (not client.registryShipExists(body)) then
        return 0
    end

    return body
end

local function _resolveLSlotOverheatThreshold(snapshot)
    local lSlots = (snapshot and snapshot.lSlots) or {}
    local weaponType = ((lSlots[1] or {}).weaponType) or "kineticArtillery"
    local defs = lSlotWeaponRegistryData or {}
    local weaponDef = defs[weaponType] or defs.kineticArtillery or {}
    return math.max(1.0, weaponDef.overheatThreshold or 100.0)
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
        return
    end

    local snapshot = client.registryShipGetSnapshot(body)
    if snapshot == nil then
        state.active = false
        state.shipBody = 0
        return
    end

    state.active = true
    state.shipBody = body
    state.currentMainWeapon = snapshot.currentMainWeapon or "xSlot"

    local threshold = _resolveLSlotOverheatThreshold(snapshot)
    state.targetHeatFraction = _mainWeaponHudClamp((snapshot.lSlotsHeat or 0.0) / threshold, 0.0, 1.0)
    state.heatFraction = _mainWeaponHudSmooth(state.heatFraction, state.targetHeatFraction, cfg.smoothSpeed, dt)
    state.overheated = (snapshot.lSlotsOverheated or 0) ~= 0
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
    local x = UiCenter() - panelW * 0.5
    local y = UiHeight() - cfg.bottomOffset
    local currentMode = state.currentMainWeapon or "xSlot"

    UiPush()
        UiAlign("left top")
        UiTranslate(x, y)
        UiColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        UiRect(panelW, panelH)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
        UiRectOutline(panelW, panelH, 2)

        _drawWeaponIcon(12, 10, cfg.iconSize, cfg.xSlotColor, "X", currentMode == "xSlot", cfg.borderColor, cfg.inactiveColor)
        _drawWeaponIcon(46, 10, cfg.iconSize, cfg.lSlotColor, "L", currentMode == "lSlot", cfg.borderColor, cfg.inactiveColor)

        UiPush()
            UiTranslate(84, 8)
            UiColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
            UiFont("regular.ttf", cfg.labelSize)
            if currentMode == "lSlot" then
                UiText("Kinetic Artillery")
            else
                UiText("Tachyon Lance")
            end
        UiPop()

        UiPush()
            UiTranslate(84, 28)
            UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
            UiFont("regular.ttf", cfg.valueSize)
            UiText((currentMode == "lSlot") and "Main Weapon: L-Slot" or "Main Weapon: X-Slot")
        UiPop()

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
    UiPop()
end
