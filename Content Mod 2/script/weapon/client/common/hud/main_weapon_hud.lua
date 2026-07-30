---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.mainWeaponHudConfig = client.mainWeaponHudConfig or {
    panelWidth = 350,
    panelHeight = 118,
    rightOffset = 24,
    topOffset = 566,
    helpPanelGap = 14,
    topBarWidth = 240,
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
    xSlotColor = { 0.62, 0.28, 0.96, 0.95 },
    lSlotColor = { 1.0, 0.42, 0.12, 0.95 },
    mSlotColor = { 1.0, 0.84, 0.18, 0.95 },
    gSlotColor = { 0.08, 0.25, 0.72, 0.95 },
    hSlotColor = { 0.95, 0.78, 0.18, 0.95 },
    heatBgColor = { 0.14, 0.16, 0.18, 0.95 },
    heatFillColor = { 1.0, 0.72, 0.18, 0.96 },
    heatOverColor = { 1.0, 0.22, 0.10, 0.98 },
    lockFillColor = { 1.0, 0.82, 0.24, 0.96 },
    lockReadyColor = { 1.0, 0.24, 0.18, 0.98 },
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
    xSlotPhase1 = "idle",
    xSlotPhase2 = "idle",
    xSlotFireMode = "aim",
    guidedProgress = 0.0,
    targetGuidedProgress = 0.0,
    guidedStatus = "NO TARGET",
    mSlotFill1 = 1.0,
    mSlotFill2 = 1.0,
    mSlotFill3 = 1.0,
    mSlotFill4 = 1.0,
    gSlotFill1 = 1.0,
    gSlotFill2 = 1.0,
    gSlotFill3 = 1.0,
    gSlotFill4 = 1.0,
    hSlotFill1 = 1.0,
    hSlotFill2 = 1.0,
    hSlotActive1 = false,
    hSlotActive2 = false,
    genericFill1 = 1.0,
    genericFill2 = 1.0,
    genericFill3 = 1.0,
    genericFill4 = 1.0,
    genericPhase1 = "idle",
    genericPhase2 = "idle",
    genericPhase3 = "idle",
    genericPhase4 = "idle",
}

client.lSlotHudStateByShip = client.lSlotHudStateByShip or {}
client.xSlotHudStateByShip = client.xSlotHudStateByShip or {}
client.mSlotHudStateByShip = client.mSlotHudStateByShip or {}
client.gSlotHudStateByShip = client.gSlotHudStateByShip or {}
client.hSlotHudStateByShip = client.hSlotHudStateByShip or {}
client.weaponGroupHudStateByShip = client.weaponGroupHudStateByShip or {}
client.hSlotDebugState = client.hSlotDebugState or {
    active = 0,
    lastReason = "none",
    slot1State = "none",
    slot1Life = -1.0,
    slot1Return = -1.0,
    slot2State = "none",
    slot2Life = -1.0,
    slot2Return = -1.0,
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

    local playerBody = GetVehicleBody(veh)
    local scriptBody = client.shipContextGetBody()
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

local function _resolveXSlotFill(value, maxValue, phase)
    local maxV = math.max(0.0, tonumber(maxValue) or 0.0)
    local curr = math.max(0.0, tonumber(value) or 0.0)
    local p = tostring(phase or "idle")

    if p == "charging" or p == "charged" or p == "launching" then
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
    if p == "heat" or p == "overheated" then
        if maxV <= 0.0001 then return 0.0 end
        return _mainWeaponHudClamp(curr / maxV, 0.0, 1.0)
    end

    return 1.0
end

function client.updateWeaponGroupHudState(
    shipBodyId,
    groupId,
    weaponType,
    value1, value2, value3, value4,
    maxValue1, maxValue2, maxValue3, maxValue4,
    phase1, phase2, phase3, phase4
)
    local body = math.floor(shipBodyId or 0)
    if body == 0 then return end
    client.weaponGroupHudStateByShip[body] = client.weaponGroupHudStateByShip[body] or {}
    client.weaponGroupHudStateByShip[body][tostring(groupId or "")] = {
        weaponType = tostring(weaponType or ""),
        values = {
            tonumber(value1) or 0.0, tonumber(value2) or 0.0,
            tonumber(value3) or 0.0, tonumber(value4) or 0.0,
        },
        maximums = {
            tonumber(maxValue1) or 0.0, tonumber(maxValue2) or 0.0,
            tonumber(maxValue3) or 0.0, tonumber(maxValue4) or 0.0,
        },
        phases = {
            tostring(phase1 or "idle"), tostring(phase2 or "idle"),
            tostring(phase3 or "idle"), tostring(phase4 or "idle"),
        },
    }
end

local function _resolveGenericTopStatus(state)
    local phase = "idle"
    local fill = 1.0
    local priority = { idle = 1, cooldown = 2, heat = 3, charging = 4, overheated = 5 }
    for i = 1, 4 do
        local candidate = tostring(state["genericPhase" .. tostring(i)] or "idle")
        local candidateFill = tonumber(state["genericFill" .. tostring(i)]) or 1.0
        if (priority[candidate] or 1) > (priority[phase] or 1) then
            phase = candidate
            fill = candidateFill
        elseif candidate == phase and candidate == "charging" and candidateFill > fill then
            fill = candidateFill
        elseif candidate == phase and candidate == "cooldown" and candidateFill < fill then
            fill = candidateFill
        elseif candidate == phase and (candidate == "heat" or candidate == "overheated")
            and candidateFill > fill then
            fill = candidateFill
        end
    end
    if phase == "charging" then
        return fill, string.format("CHARGE %d%%", math.floor(fill * 100 + 0.5))
    end
    if phase == "cooldown" then
        return fill, string.format("RECOVER %d%%", math.floor(fill * 100 + 0.5))
    end
    if phase == "overheated" then
        return fill, string.format("OVERHEAT %d%%", math.floor(fill * 100 + 0.5))
    end
    if phase == "heat" then
        return fill, string.format("HEAT %d%%", math.floor(fill * 100 + 0.5))
    end
    return 1.0, "READY"
end

local function _xSlotPhasePriority(phase)
    local p = tostring(phase or "idle")
    if p == "charged" then return 5 end
    if p == "charging" then return 4 end
    if p == "launching" then return 3 end
    if p == "cooldown" then return 2 end
    return 1
end

local function _resolveXSlotTopStatus(state)
    local phase1 = tostring(state.xSlotPhase1 or "idle")
    local phase2 = tostring(state.xSlotPhase2 or "idle")
    local fill1 = tonumber(state.xSlotFill1) or 1.0
    local fill2 = tonumber(state.xSlotFill2) or 1.0

    local phase = phase1
    local fill = fill1
    if _xSlotPhasePriority(phase2) > _xSlotPhasePriority(phase1) or (_xSlotPhasePriority(phase2) == _xSlotPhasePriority(phase1) and fill2 > fill1) then
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
    if phase == "cooldown" then
        return fill, string.format("RECOVER %d%%", math.floor(fill * 100 + 0.5))
    end
    return 1.0, "READY"
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

function client.updateXSlotHudState(shipBodyId, value1, value2, maxValue1, maxValue2, phase1, phase2)
    local hud = _getOrCreateXSlotHudState(shipBodyId)
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

local function _getOrCreateMSlotHudState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local states = client.mSlotHudStateByShip
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

local function _getOrCreateGSlotHudState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then return nil end
    local states = client.gSlotHudStateByShip
    local hud = states[body]
    if hud == nil then
        hud = {
            cd1 = 0.0, cd2 = 0.0, cd3 = 0.0, cd4 = 0.0,
            maxCd1 = 1.0, maxCd2 = 1.0, maxCd3 = 1.0, maxCd4 = 1.0,
        }
        states[body] = hud
    end
    return hud
end

local function _getOrCreateHSlotHudState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local states = client.hSlotHudStateByShip
    local hud = states[body]
    if hud == nil then
        hud = {
            cd1 = 0.0,
            cd2 = 0.0,
            maxCd1 = 1.0,
            maxCd2 = 1.0,
            active1 = false,
            active2 = false,
            dbgReason = "none",
            dbgS1State = "none",
            dbgS1Life = -1.0,
            dbgS1Return = -1.0,
            dbgS2State = "none",
            dbgS2Life = -1.0,
            dbgS2Return = -1.0,
        }
        states[body] = hud
    end
    return hud
end

function client.updateHSlotHudState(
    shipBodyId,
    cd1,
    cd2,
    maxCd1,
    maxCd2,
    active1,
    active2,
    dbgReason,
    dbgS1State,
    dbgS1Life,
    dbgS1Return,
    dbgS2State,
    dbgS2Life,
    dbgS2Return
)
    local hud = _getOrCreateHSlotHudState(shipBodyId)
    if hud == nil then
        return
    end

    hud.cd1 = math.max(0.0, tonumber(cd1) or 0.0)
    hud.cd2 = math.max(0.0, tonumber(cd2) or 0.0)
    hud.maxCd1 = math.max(0.0, tonumber(maxCd1) or 0.0)
    hud.maxCd2 = math.max(0.0, tonumber(maxCd2) or 0.0)
    hud.active1 = math.floor(active1 or 0) ~= 0
    hud.active2 = math.floor(active2 or 0) ~= 0
    hud.dbgReason = tostring(dbgReason or hud.dbgReason or "none")
    hud.dbgS1State = tostring(dbgS1State or hud.dbgS1State or "none")
    hud.dbgS1Life = tonumber(dbgS1Life) or hud.dbgS1Life or -1.0
    hud.dbgS1Return = tonumber(dbgS1Return) or hud.dbgS1Return or -1.0
    hud.dbgS2State = tostring(dbgS2State or hud.dbgS2State or "none")
    hud.dbgS2Life = tonumber(dbgS2Life) or hud.dbgS2Life or -1.0
    hud.dbgS2Return = tonumber(dbgS2Return) or hud.dbgS2Return or -1.0
end

function client.receiveHSlotDebugState(activeCount, lastReason, s1State, s1Life, s1Return, s2State, s2Life, s2Return)
    local d = client.hSlotDebugState or {}
    d.active = math.floor(activeCount or 0)
    d.lastReason = tostring(lastReason or "none")
    d.slot1State = tostring(s1State or "none")
    d.slot1Life = tonumber(s1Life) or -1.0
    d.slot1Return = tonumber(s1Return) or -1.0
    d.slot2State = tostring(s2State or "none")
    d.slot2Life = tonumber(s2Life) or -1.0
    d.slot2Return = tonumber(s2Return) or -1.0
    client.hSlotDebugState = d
end

function client.updateMSlotHudState(shipBodyId, cd1, cd2, cd3, cd4, maxCd1, maxCd2, maxCd3, maxCd4)
    local hud = _getOrCreateMSlotHudState(shipBodyId)
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

function client.updateGSlotHudState(shipBodyId, cd1, cd2, cd3, cd4, maxCd1, maxCd2, maxCd3, maxCd4)
    local hud = _getOrCreateGSlotHudState(shipBodyId)
    if hud == nil then return end
    hud.cd1 = math.max(0.0, tonumber(cd1) or 0.0)
    hud.cd2 = math.max(0.0, tonumber(cd2) or 0.0)
    hud.cd3 = math.max(0.0, tonumber(cd3) or 0.0)
    hud.cd4 = math.max(0.0, tonumber(cd4) or 0.0)
    hud.maxCd1 = math.max(0.0, tonumber(maxCd1) or 0.0)
    hud.maxCd2 = math.max(0.0, tonumber(maxCd2) or 0.0)
    hud.maxCd3 = math.max(0.0, tonumber(maxCd3) or 0.0)
    hud.maxCd4 = math.max(0.0, tonumber(maxCd4) or 0.0)
end

local function _updateGuidedSlotFills(state, prefix, hud)
    local source = hud or {}
    for i = 1, 4 do
        local cooldown = math.max(0.0, tonumber(source["cd" .. tostring(i)]) or 0.0)
        local maximum = math.max(0.0, tonumber(source["maxCd" .. tostring(i)]) or 0.0)
        local fill = 1.0
        if maximum > 0.0001 then
            fill = _mainWeaponHudClamp(1.0 - (cooldown / maximum), 0.0, 1.0)
        end
        state[prefix .. "SlotFill" .. tostring(i)] = fill
    end
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
        state.xSlotPhase1 = "idle"
        state.xSlotPhase2 = "idle"
        state.xSlotFireMode = "aim"
        state.targetGuidedProgress = 0.0
        state.guidedProgress = 0.0
        state.guidedStatus = "NO TARGET"
        state.hSlotFill1 = 1.0
        state.hSlotFill2 = 1.0
        state.hSlotActive1 = false
        state.hSlotActive2 = false
        for i = 1, 4 do
            state["genericFill" .. tostring(i)] = 1.0
            state["genericPhase" .. tostring(i)] = "idle"
        end
        return
    end

    state.active = true
    state.shipBody = body
    if client.getShipMainWeaponMode ~= nil then
        state.currentMainWeapon = client.getShipMainWeaponMode(body)
    else
        state.currentMainWeapon = "xSlot"
    end
    state.xSlotFireMode = client.getShipXSlotFireMode ~= nil and client.getShipXSlotFireMode(body) or "aim"

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
        value1 = 0.0,
        value2 = 0.0,
        maxValue1 = 1.0,
        maxValue2 = 1.0,
        phase1 = "idle",
        phase2 = "idle",
    }
    state.xSlotPhase1 = tostring(xHud.phase1 or "idle")
    state.xSlotPhase2 = tostring(xHud.phase2 or "idle")
    state.xSlotFill1 = _resolveXSlotFill(xHud.value1, xHud.maxValue1, xHud.phase1)
    state.xSlotFill2 = _resolveXSlotFill(xHud.value2, xHud.maxValue2, xHud.phase2)

    local genericHud = ((client.weaponGroupHudStateByShip[body] or {})[state.currentMainWeapon]) or {}
    local genericValues = genericHud.values or {}
    local genericMaximums = genericHud.maximums or {}
    local genericPhases = genericHud.phases or {}
    for i = 1, 4 do
        local phase = tostring(genericPhases[i] or "idle")
        state["genericPhase" .. tostring(i)] = phase
        state["genericFill" .. tostring(i)] = _resolveXSlotFill(
            genericValues[i] or 0.0,
            genericMaximums[i] or 0.0,
            phase
        )
    end

    if client.guidedTargetingGetSummary ~= nil then
        local statusText, progress = client.guidedTargetingGetSummary(body)
        state.guidedStatus = statusText or "NO TARGET"
        state.targetGuidedProgress = _mainWeaponHudClamp(progress or 0.0, 0.0, 1.0)
    else
        state.guidedStatus = "NO TARGET"
        state.targetGuidedProgress = 0.0
    end
    state.guidedProgress = _mainWeaponHudSmooth(state.guidedProgress, state.targetGuidedProgress, cfg.smoothSpeed, dt)



    _updateGuidedSlotFills(state, "m", client.mSlotHudStateByShip[body])
    _updateGuidedSlotFills(state, "g", client.gSlotHudStateByShip[body])

    local hHud = client.hSlotHudStateByShip[body] or {
        cd1 = 0.0,
        cd2 = 0.0,
        maxCd1 = 1.0,
        maxCd2 = 1.0,
        active1 = false,
        active2 = false,
    }

    if hHud.active1 then
        state.hSlotFill1 = 0.0
    elseif (hHud.maxCd1 or 0.0) > 0.0001 then
        state.hSlotFill1 = _mainWeaponHudClamp(1.0 - ((hHud.cd1 or 0.0) / (hHud.maxCd1 or 1.0)), 0.0, 1.0)
    else
        state.hSlotFill1 = 1.0
    end

    if hHud.active2 then
        state.hSlotFill2 = 0.0
    elseif (hHud.maxCd2 or 0.0) > 0.0001 then
        state.hSlotFill2 = _mainWeaponHudClamp(1.0 - ((hHud.cd2 or 0.0) / (hHud.maxCd2 or 1.0)), 0.0, 1.0)
    else
        state.hSlotFill2 = 1.0
    end

    state.hSlotActive1 = hHud.active1 and true or false
    state.hSlotActive2 = hHud.active2 and true or false

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

local function _drawWeaponCooldownBar(x, y, w, h, fill, label, cfg, fillColor)
    local color = fillColor or cfg.xSlotColor
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

function client.mainWeaponHudDraw()
    local cfg = client.mainWeaponHudConfig
    local state = client.mainWeaponHudState
    if not state.active then
        return
    end

    local panelW = cfg.panelWidth
    local panelH = cfg.panelHeight
    local x = UiWidth() - panelW - cfg.rightOffset
    local y = cfg.topOffset
    if client.shipHelpOverlayGetBottom ~= nil then
        y = client.shipHelpOverlayGetBottom() + cfg.helpPanelGap
    end
    local currentMode = state.currentMainWeapon or "xSlot"
    local weaponDefinition = client.getShipWeaponDefinition ~= nil
        and client.getShipWeaponDefinition(state.shipBody, currentMode) or {}
    local usesGenericRuntime = tostring(weaponDefinition.controllerType or "") == ""

    local topFill, topText = _resolveXSlotTopStatus(state)
    local topColor = cfg.xSlotColor
    local titleText = tostring(weaponDefinition.displayName or "Tachyon Lance")
    local englishNameText = tostring(weaponDefinition.englishName or "")
    local modeText = string.format("Main Weapon: X-Slot [%s]", string.upper(state.xSlotFireMode or "aim"))

    if usesGenericRuntime then
        topFill, topText = _resolveGenericTopStatus(state)
    end

    if currentMode == "lSlot" then
        if not usesGenericRuntime then
            topFill = state.heatFraction
            topText = state.overheated and "OVERHEAT" or string.format("HEAT %d%%", math.floor(state.heatFraction * 100 + 0.5))
        end
        if usesGenericRuntime then
            topColor = cfg.lSlotColor
        else
            topColor = state.overheated and cfg.heatOverColor or cfg.heatFillColor
        end
        modeText = "Main Weapon: L-Slot"
    elseif currentMode == "mSlot" then
        if not usesGenericRuntime then
            topFill = state.guidedProgress
            topText = state.guidedStatus or "NO TARGET"
        end
        if usesGenericRuntime then
            topColor = cfg.mSlotColor
        else
            topColor = (state.guidedStatus == "LOCKED") and cfg.lockReadyColor or cfg.lockFillColor
        end
        modeText = "Main Weapon: M-Slot"
    elseif currentMode == "gSlot" then
        if not usesGenericRuntime then
            topFill = state.guidedProgress
            topText = state.guidedStatus or "NO TARGET"
        end
        if usesGenericRuntime then
            topColor = cfg.gSlotColor
        else
            topColor = (state.guidedStatus == "LOCKED") and cfg.lockReadyColor or cfg.lockFillColor
        end
        modeText = "Main Weapon: G-Slot"
    elseif currentMode == "hSlot" then
        local anyActive = state.hSlotActive1 or state.hSlotActive2
        topFill = anyActive and 0.0 or math.max(state.hSlotFill1 or 0.0, state.hSlotFill2 or 0.0)
        topText = anyActive and "STRIKE CRAFT DEPLOYED" or "HANGAR READY"
        topColor = cfg.hSlotColor
        modeText = "Main Weapon: H-Slot"
    end
    if usesGenericRuntime then
        for i = 1, 4 do
            local phase = tostring(state["genericPhase" .. tostring(i)] or "")
            if phase == "overheated" then
                topColor = cfg.heatOverColor
                break
            elseif phase == "heat" then
                topColor = cfg.heatFillColor
            end
        end
    end

    UiPush()
        UiAlign("left top")
        UiTranslate(x, y)
        UiColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        UiRect(panelW, panelH)
        UiColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
        UiRectOutline(panelW, panelH, 2)

        _drawTopBar(12, cfg.topBarOffsetY, cfg.topBarWidth, cfg.topBarHeight, topFill, topColor, topText, cfg)

        _drawWeaponIcon(12, 36, cfg.iconSize, cfg.xSlotColor, "X", currentMode == "xSlot", cfg)
        _drawWeaponIcon(46, 36, cfg.iconSize, cfg.lSlotColor, "L", currentMode == "lSlot", cfg)
        _drawWeaponIcon(80, 36, cfg.iconSize, cfg.mSlotColor, "M", currentMode == "mSlot", cfg)
        _drawWeaponIcon(114, 36, cfg.iconSize, cfg.gSlotColor, "G", currentMode == "gSlot", cfg)
        _drawWeaponIcon(148, 36, cfg.iconSize, cfg.hSlotColor, "H", currentMode == "hSlot", cfg)

        UiPush()
            UiTranslate(190, 30)
            UiColor(cfg.textColor[1], cfg.textColor[2], cfg.textColor[3], cfg.textColor[4])
            UiFont("regular.ttf", cfg.labelSize)
            UiText(titleText)
        UiPop()

        if englishNameText ~= "" then
            UiPush()
                UiTranslate(190, 44)
                UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4] * 0.8)
                UiFont("regular.ttf", cfg.valueSize - 2)
                UiText(englishNameText)
            UiPop()
        end

        UiPush()
            UiTranslate(190, 56)
            UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
            UiFont("regular.ttf", cfg.valueSize)
            UiText(modeText)
        UiPop()

        if usesGenericRuntime then
            local slotLabel = string.upper(string.sub(currentMode, 1, 1))
            local slotColor = cfg.xSlotColor
            if currentMode == "lSlot" then slotColor = cfg.lSlotColor end
            if currentMode == "mSlot" then slotColor = cfg.mSlotColor end
            if currentMode == "gSlot" then slotColor = cfg.gSlotColor end
            local barCount = 0
            for i = 1, 4 do
                local groupHud = ((client.weaponGroupHudStateByShip[state.shipBody] or {})[currentMode]) or {}
                if tonumber((groupHud.maximums or {})[i]) ~= nil and tonumber((groupHud.maximums or {})[i]) > 0.0 then
                    barCount = i
                end
            end
            for i = 1, barCount do
                local column = (i - 1) % 2
                local row = math.floor((i - 1) / 2)
                local barX = 12 + column * (24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap)
                local barY = 76 + row * 20
                local phase = tostring(state["genericPhase" .. tostring(i)] or "")
                local barColor = slotColor
                if phase == "overheated" then
                    barColor = cfg.heatOverColor
                elseif phase == "heat" then
                    barColor = cfg.heatFillColor
                end
                _drawWeaponCooldownBar(
                    barX, barY, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight,
                    state["genericFill" .. tostring(i)],
                    slotLabel .. tostring(i), cfg, barColor
                )
            end
        elseif currentMode == "xSlot" then
            _drawWeaponCooldownBar(12, 82, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.xSlotFill1, "X1", cfg, cfg.xSlotColor)
            _drawWeaponCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 82, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.xSlotFill2, "X2", cfg, cfg.xSlotColor)
        elseif currentMode == "mSlot" or currentMode == "gSlot" then
            local prefix = currentMode == "mSlot" and "m" or "g"
            local label = currentMode == "mSlot" and "M" or "G"
            local color = currentMode == "mSlot" and cfg.mSlotColor or cfg.gSlotColor
            _drawWeaponCooldownBar(12, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state[prefix .. "SlotFill1"], label .. "1", cfg, color)
            _drawWeaponCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 76, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state[prefix .. "SlotFill2"], label .. "2", cfg, color)
            _drawWeaponCooldownBar(12, 96, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state[prefix .. "SlotFill3"], label .. "3", cfg, color)
            _drawWeaponCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 96, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state[prefix .. "SlotFill4"], label .. "4", cfg, color)
        elseif currentMode == "hSlot" then
            _drawWeaponCooldownBar(12, 82, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.hSlotFill1, state.hSlotActive1 and "H1*" or "H1", cfg, cfg.hSlotColor)
            _drawWeaponCooldownBar(12 + 24 + cfg.xCooldownBarWidth + cfg.xCooldownBarGap, 82, cfg.xCooldownBarWidth, cfg.xCooldownBarHeight, state.hSlotFill2, state.hSlotActive2 and "H2*" or "H2", cfg, cfg.hSlotColor)
        else
            UiPush()
                UiTranslate(12, 84)
                UiColor(cfg.subTextColor[1], cfg.subTextColor[2], cfg.subTextColor[3], cfg.subTextColor[4])
                UiFont("regular.ttf", cfg.valueSize)
                UiText("Thermal battery active")
            UiPop()
        end
    UiPop()
end
