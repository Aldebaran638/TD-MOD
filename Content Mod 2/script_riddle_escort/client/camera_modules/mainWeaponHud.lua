---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponHudConfig = client.mainWeaponHudConfig or {
    panelWidth = 292,
    panelHeight = 128,
    rightOffset = 272,
    bottomOffset = 34,
    bgColor = { 0.06, 0.07, 0.09, 0.78 },
    borderColor = { 1.0, 1.0, 1.0, 0.26 },
    textColor = { 0.95, 0.96, 0.98, 1.0 },
    inactiveColor = { 0.24, 0.27, 0.31, 0.95 },
    sColor = { 1.0, 0.90, 0.48, 0.98 },
    pColor = { 0.30, 0.96, 0.45, 0.98 },
    gColor = { 0.78, 0.30, 1.0, 0.98 },
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

local function _drawBox(x, y, w, h, color)
    UiPush()
        UiTranslate(x, y)
        UiColor(color[1], color[2], color[3], color[4])
        UiRect(w, h)
    UiPop()
end

local function _drawText(x, y, text, size, color)
    UiPush()
        UiTranslate(x, y)
        UiFont("regular.ttf", size)
        UiColor(color[1], color[2], color[3], color[4])
        UiText(text)
    UiPop()
end

local function _drawCooldownRow(x, y, label, fills, color, cfg)
    _drawText(x, y, label, 18, cfg.textColor)
    local barX = x + 32
    for i = 1, #fills do
        local bx = barX + (i - 1) * 58
        _drawBox(bx, y + 2, 48, 10, cfg.inactiveColor)
        _drawBox(bx, y + 2, 48 * _clamp(fills[i] or 0.0, 0.0, 1.0), 10, color)
    end
end

function client.mainWeaponHudDraw()
    local state = client.mainWeaponHudState
    if not state.active then
        return
    end

    local cfg = client.mainWeaponHudConfig
    local x = UiWidth() - cfg.rightOffset
    local y = UiHeight() - cfg.bottomOffset - cfg.panelHeight

    _drawBox(x, y, cfg.panelWidth, cfg.panelHeight, cfg.bgColor)
    _drawBox(x, y, cfg.panelWidth, 2, cfg.borderColor)
    _drawBox(x, y + cfg.panelHeight - 2, cfg.panelWidth, 2, cfg.borderColor)

    _drawText(x + 12, y + 12, "RIDDLE ESCORT", 20, cfg.textColor)
    _drawText(x + 14, y + 38, "S", 24, state.currentMainWeapon == "sSlot" and cfg.sColor or cfg.inactiveColor)
    _drawText(x + 54, y + 38, "P", 24, state.currentMainWeapon == "pSlot" and cfg.pColor or cfg.inactiveColor)
    _drawText(x + 94, y + 38, "G", 24, state.currentMainWeapon == "gSlot" and cfg.gColor or cfg.inactiveColor)

    if state.currentMainWeapon == "sSlot" then
        local hud = client.escortSHudByShip[state.shipBody] or { cd = { 0, 0, 0, 0 }, maxCd = { 1, 1, 1, 1 } }
        local fills = {}
        for i = 1, 4 do
            local maxCd = math.max(0.0001, hud.maxCd[i] or 1.0)
            fills[i] = 1.0 - _clamp((hud.cd[i] or 0.0) / maxCd, 0.0, 1.0)
        end
        _drawCooldownRow(x + 12, y + 72, "S", fills, cfg.sColor, cfg)
    elseif state.currentMainWeapon == "pSlot" then
        local hud = client.escortPHudByShip[state.shipBody] or { heat = { 0, 0 }, overheated = { false, false }, threshold = { 100, 100 } }
        local fills = {}
        for i = 1, 2 do
            local threshold = math.max(1.0, hud.threshold[i] or 100.0)
            fills[i] = _clamp((hud.heat[i] or 0.0) / threshold, 0.0, 1.0)
        end
        _drawCooldownRow(x + 12, y + 72, "P", fills, cfg.pColor, cfg)
    else
        local hud = client.escortGHudByShip[state.shipBody] or { cd = { 0, 0, 0 }, maxCd = { 1, 1, 1 } }
        local fills = {}
        for i = 1, 3 do
            local maxCd = math.max(0.0001, hud.maxCd[i] or 1.0)
            fills[i] = 1.0 - _clamp((hud.cd[i] or 0.0) / maxCd, 0.0, 1.0)
        end
        _drawCooldownRow(x + 12, y + 72, "G", fills, cfg.gColor, cfg)
    end
end
