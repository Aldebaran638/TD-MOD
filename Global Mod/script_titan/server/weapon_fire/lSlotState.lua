---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.lSlotState = server.lSlotState or {
    requestFire = false,
    slots = {},
    groups = {},
    nextGroupIndex = 1,
}

server.lSlotHudSyncState = server.lSlotHudSyncState or {
    lastHeats = nil,
    lastOverheated = nil,
    lastThresholds = nil,
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
    local requested = shipType or server.defaultShipType or "titan"
    return defs[requested] or defs[server.defaultShipType] or defs.titan or {}
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
        groupIndex = math.max(1, math.floor(tonumber(slotDef and slotDef.groupIndex) or 1)),
        firePosOffset = _lSlotCloneVec3(slotDef and slotDef.firePosOffset, 0, 0, -4),
        fireDirRelative = _lSlotCloneVec3(slotDef and slotDef.fireDirRelative, 0, 0, -1),
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
    sync.lastHeats = nil
    sync.lastOverheated = nil
    sync.lastThresholds = nil
    sync.lastSendTime = -1000.0
    sync.resetActive = false
    server.lSlotHudSyncState = sync
end

local function _lSlotEnsureGroupEntry(state, groupIndex)
    local groups = state.groups or {}
    local idx = math.max(1, math.floor(groupIndex or 1))
    if groups[idx] == nil then
        groups[idx] = {
            slotIndices = {},
        }
    end
    state.groups = groups
    return groups[idx]
end

local function _lSlotResolveGroupHudData(state)
    local groups = (state and state.groups) or {}
    local result = {}

    for groupIndex = 1, #groups do
        local entry = groups[groupIndex] or {}
        local slotIndices = entry.slotIndices or {}
        local groupHeat = 0.0
        local groupOverheated = false
        local groupThreshold = 100.0
        local hasSlot = false
        for i = 1, #slotIndices do
            local slot = ((state or {}).slots or {})[slotIndices[i]]
            if slot ~= nil and slot.config ~= nil and slot.runtime ~= nil then
                hasSlot = true
                groupHeat = math.max(groupHeat, slot.runtime.heat or 0.0)
                groupOverheated = groupOverheated or (slot.runtime.overheated and true or false)
                groupThreshold = math.max(1.0, slot.config.overheatThreshold or groupThreshold)
            end
        end

        if hasSlot then
            result[groupIndex] = {
                heat = groupHeat,
                overheated = groupOverheated,
                threshold = groupThreshold,
            }
        else
            result[groupIndex] = {
                heat = 0.0,
                overheated = false,
                threshold = 100.0,
            }
        end
    end

    return result
end

function server.lSlotStateInit(shipType)
    local shipDef = _lSlotResolveShipDefinition(shipType)
    local state = {
        requestFire = false,
        slots = {},
        groups = {},
        nextGroupIndex = 1,
    }

    local slotDefs = shipDef.lSlots or {}
    for i = 1, #slotDefs do
        local config = _lSlotBuildConfig(slotDefs[i])
        state.slots[i] = {
            config = config,
            runtime = _lSlotBuildRuntime(),
        }
        local groupEntry = _lSlotEnsureGroupEntry(state, config.groupIndex)
        groupEntry.slotIndices[#groupEntry.slotIndices + 1] = i
    end

    server.lSlotState = state
    server.lSlotHudSyncState = {
        lastHeats = nil,
        lastOverheated = nil,
        lastThresholds = nil,
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
    state.nextGroupIndex = 1
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

    sync.lastHeats = { 0.0, 0.0 }
    sync.lastOverheated = { false, false }
    sync.lastThresholds = nil
    sync.resetActive = true
    server.lSlotHudSyncState = sync
end

function server.lSlotStatePushHud(force)
    local state = server.lSlotState
    if state == nil or server.shipBody == nil or server.shipBody == 0 then
        server.lSlotStatePushHudReset(force)
        return
    end

    local groupHud = _lSlotResolveGroupHudData(state)
    if #groupHud <= 0 then
        server.lSlotStatePushHudReset(force)
        return
    end

    local sync = server.lSlotHudSyncState or {}
    local heat1 = ((groupHud[1] or {}).heat) or 0.0
    local heat2 = ((groupHud[2] or {}).heat) or 0.0
    local overheated1 = ((groupHud[1] or {}).overheated) and true or false
    local overheated2 = ((groupHud[2] or {}).overheated) and true or false
    local threshold1 = math.max(1.0, ((groupHud[1] or {}).threshold) or 100.0)
    local threshold2 = math.max(1.0, ((groupHud[2] or {}).threshold) or 100.0)
    local nowTime = _lSlotNow()

    local thresholdsChanged = force
        or sync.lastThresholds == nil
        or math.abs((((sync.lastThresholds or {})[1]) or 0.0) - threshold1) > 0.0001
        or math.abs((((sync.lastThresholds or {})[2]) or 0.0) - threshold2) > 0.0001

    if thresholdsChanged then
        ClientCall(0, "client.initLSlotHudState", server.shipBody or 0, threshold1, threshold2)
    end

    local shouldSendUpdate = force
        or sync.lastHeats == nil
        or math.abs((((sync.lastHeats or {})[1]) or 0.0) - heat1) > 0.0001
        or math.abs((((sync.lastHeats or {})[2]) or 0.0) - heat2) > 0.0001
        or (((sync.lastOverheated or {})[1]) ~= overheated1)
        or (((sync.lastOverheated or {})[2]) ~= overheated2)
        or ((nowTime - (sync.lastSendTime or -1000.0)) >= 0.5)

    if shouldSendUpdate then
        ClientCall(
            0,
            "client.updateLSlotHudState",
            server.shipBody or 0,
            heat1,
            overheated1 and 1 or 0,
            heat2,
            overheated2 and 1 or 0
        )
        sync.lastSendTime = nowTime
    end

    sync.lastHeats = { heat1, heat2 }
    sync.lastOverheated = { overheated1, overheated2 }
    sync.lastThresholds = { threshold1, threshold2 }
    sync.resetActive = false
    server.lSlotHudSyncState = sync
end
