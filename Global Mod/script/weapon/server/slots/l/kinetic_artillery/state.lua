---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.lSlotState = server.lSlotState or {
    requestFire = false,
    slots = {},
}

server.lSlotHudSyncState = server.lSlotHudSyncState or {
    lastHeat = nil,
    lastOverheated = nil,
    lastThreshold = nil,
    lastSendTime = -1000.0,
    resetActive = false,
}

local function _lSlotCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = t.x or defaultX or 0.0,
        y = t.y or defaultY or 0.0,
        z = t.z or defaultZ or 0.0,
    }
end

local function _lSlotResolveShipDefinition(shipType)
    local contextType = server.shipContextGetType()
    return shipDefinitionGet(shipType or contextType, contextType)
end

local function _lSlotResolveWeaponDefinition(weaponType)
    local defs = weaponData or {}
    local requested = weaponType or "kineticArtillery"
    return defs[requested] or defs.kineticArtillery or {}
end

local function _lSlotBuildConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "none")
    local weaponDef = _lSlotResolveWeaponDefinition(weaponType)
    return {
        weaponType = weaponType,
        firePosOffset = _lSlotCloneVec3(slotDef and slotDef.firePosOffset, 0, 0, -4),
        fireDirRelative = _lSlotCloneVec3(slotDef and slotDef.fireDirRelative, 0, 0, -1),
        fireDeviationAngle = math.max(0.0, tonumber(slotDef and slotDef.fireDeviationAngle) or 0.0),
        aimMode = tostring((slotDef and slotDef.aimMode) or "fixed"),
        cooldown = weaponDef.cooldown or 0.0,
        maxRange = weaponDef.maxRange or 0.0,
        heatPerShot = weaponDef.heatPerShot or 0.0,
        heatDissipationPerSecond = weaponDef.heatDissipationPerSecond or 0.0,
        overheatThreshold = weaponDef.overheatThreshold or 0.0,
        recoverThreshold = weaponDef.recoverThreshold or 0.0,
        aimControlMode = tostring(weaponDef.aimControlMode or "fixed"),
        aimLimitDeg = tonumber(weaponDef.aimLimitDeg) or 0.0,
        aimPitchOffsetDeg = tonumber(weaponDef.aimPitchOffsetDeg) or 0.0,
    }
end

local function _lSlotBuildRuntime()
    return {
        heat = 0.0,
        overheated = false,
        cooldownRemain = 0.0,
    }
end

local function _lSlotNow()
    return (GetTime ~= nil) and GetTime() or 0.0
end

function server.lSlotStateMarkHudDirty()
    local sync = server.lSlotHudSyncState or {}
    sync.lastHeat = nil
    sync.lastOverheated = nil
    sync.lastThreshold = nil
    sync.lastSendTime = -1000.0
    sync.resetActive = false
    server.lSlotHudSyncState = sync
end

function server.lSlotStateInit(shipType)
    local shipDef = _lSlotResolveShipDefinition(shipType)
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        shipDef = server.shipSlotLoadoutResolveShipDefinition(shipType) or shipDef
    end
    local state = {
        requestFire = false,
        slots = {},
    }

    local slotDefs = shipDef.lSlots or {}
    for i = 1, #slotDefs do
        state.slots[i] = {
            config = _lSlotBuildConfig(slotDefs[i]),
            runtime = _lSlotBuildRuntime(),
        }
    end

    server.lSlotState = state
    server.lSlotHudSyncState = {
        lastHeat = nil,
        lastOverheated = nil,
        lastThreshold = nil,
        lastSendTime = -1000.0,
        resetActive = false,
    }
    server.lSlotStateMarkHudDirty()
    return state
end

function server.lSlotStateSetRequestFire(active)
    if server.lSlotState == nil then
        return
    end
    server.lSlotState.requestFire = active and true or false
end

function server.lSlotStateConsumeRequestFire()
    if server.lSlotState == nil then
        return false
    end
    local requested = server.lSlotState.requestFire and true or false
    server.lSlotState.requestFire = false
    return requested
end

function server.lSlotStateNeedsTick()
    local state = server.lSlotState or {}
    local body = server.shipContextGetBody()
    if body ~= 0 and server.shipRuntimeGetDriverPlayerId(body) > 0 then
        return true
    end
    if state.requestFire then return true end
    for _, slot in ipairs(state.slots or {}) do
        local runtime = slot.runtime or {}
        if (tonumber(runtime.heat) or 0.0) > 0.0
            or (tonumber(runtime.cooldownRemain) or 0.0) > 0.0
            or runtime.overheated then
            return true
        end
    end
    return false
end

function server.lSlotStateResetRuntime()
    local state = server.lSlotState
    if state == nil then
        return
    end

    state.requestFire = false
    local slots = state.slots or {}
    for i = 1, #slots do
        local runtime = (slots[i] and slots[i].runtime) or nil
        if runtime ~= nil then
            runtime.heat = 0.0
            runtime.overheated = false
            runtime.cooldownRemain = 0.0
        end
    end
    server.lSlotStateMarkHudDirty()
end

function server.lSlotStatePushHudReset(force)
    local sync = server.lSlotHudSyncState or {}
    local nowTime = _lSlotNow()
    local shouldSend = force
        or (not sync.resetActive)
        or ((nowTime - (sync.lastSendTime or -1000.0)) >= 1.0)

    if shouldSend then
        local shipBody = server.shipContextGetBody()
        local playerId = server.netResolveShipDriver(shipBody)
        if playerId <= 0 then return end
        server.netClientCall(
            "hud.lslot",
            playerId,
            "client.resetLSlotHudState",
            shipBody
        )
        sync.lastSendTime = nowTime
    end

    sync.lastHeat = 0.0
    sync.lastOverheated = false
    sync.lastThreshold = nil
    sync.resetActive = true
    server.lSlotHudSyncState = sync
end

function server.lSlotStatePushHud(force)
    local state = server.lSlotState
    local slot1 = (state and state.slots and state.slots[1]) or nil
    local shipBody = server.shipContextGetBody()
    if slot1 == nil or slot1.config == nil or slot1.runtime == nil or shipBody == 0 then
        server.lSlotStatePushHudReset(force)
        return
    end

    local sync = server.lSlotHudSyncState or {}
    local heat = server.netSyncQuantize(slot1.runtime.heat or 0.0, 0.1)
    local overheated = slot1.runtime.overheated and true or false
    local threshold = math.max(1.0, slot1.config.overheatThreshold or 100.0)
    local nowTime = _lSlotNow()

    local playerId = server.netResolveShipDriver(shipBody)
    if playerId <= 0 then return end

    if force or sync.lastThreshold == nil
        or math.abs((sync.lastThreshold or 0.0) - threshold) > 0.0001 then
        server.netClientCall(
            "hud.lslot",
            playerId,
            "client.initLSlotHudState",
            shipBody,
            threshold
        )
    end

    local shouldSendUpdate = force
        or sync.lastHeat == nil
        or sync.lastOverheated ~= overheated
        or (
            math.abs((sync.lastHeat or 0.0) - heat) > 0.0001
            and (nowTime - (sync.lastSendTime or -1000.0)) >= 0.2
        )
        or ((nowTime - (sync.lastSendTime or -1000.0)) >= 1.0)

    if shouldSendUpdate then
        server.netClientCall(
            "hud.lslot",
            playerId,
            "client.updateLSlotHudState",
            shipBody,
            heat,
            overheated and 1 or 0
        )
        sync.lastSendTime = nowTime
    end

    sync.lastHeat = heat
    sync.lastOverheated = overheated
    sync.lastThreshold = threshold
    sync.resetActive = false
    server.lSlotHudSyncState = sync
end
