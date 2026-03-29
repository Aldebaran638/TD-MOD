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
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    return defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

local function _lSlotResolveWeaponDefinition(weaponType)
    local defs = lSlotWeaponRegistryData or {}
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
        or ((nowTime - (sync.lastSendTime or -1000.0)) >= 0.5)

    if shouldSend then
        ClientCall(0, "client.resetLSlotHudState", server.shipBody or 0)
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
    if slot1 == nil or slot1.config == nil or slot1.runtime == nil or server.shipBody == nil or server.shipBody == 0 then
        server.lSlotStatePushHudReset(force)
        return
    end

    local sync = server.lSlotHudSyncState or {}
    local heat = slot1.runtime.heat or 0.0
    local overheated = slot1.runtime.overheated and true or false
    local threshold = math.max(1.0, slot1.config.overheatThreshold or 100.0)
    local nowTime = _lSlotNow()

    if force or sync.lastThreshold == nil or math.abs((sync.lastThreshold or 0.0) - threshold) > 0.0001 then
        ClientCall(0, "client.initLSlotHudState", server.shipBody or 0, threshold)
    end

    local shouldSendUpdate = force
        or sync.lastHeat == nil
        or math.abs((sync.lastHeat or 0.0) - heat) > 0.0001
        or sync.lastOverheated ~= overheated
        or ((nowTime - (sync.lastSendTime or -1000.0)) >= 0.5)

    if shouldSendUpdate then
        ClientCall(0, "client.updateLSlotHudState", server.shipBody or 0, heat, overheated and 1 or 0)
        sync.lastSendTime = nowTime
    end

    sync.lastHeat = heat
    sync.lastOverheated = overheated
    sync.lastThreshold = threshold
    sync.resetActive = false
    server.lSlotHudSyncState = sync
end
