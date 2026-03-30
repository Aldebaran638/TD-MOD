---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.escortPSlotState = server.escortPSlotState or {
    requestFire = false,
    slots = {},
    groups = {},
    nextGroupIndex = 1,
}

local function _escortPSlotCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = tonumber(t.x) or defaultX or 0.0,
        y = tonumber(t.y) or defaultY or 0.0,
        z = tonumber(t.z) or defaultZ or 0.0,
    }
end

local function _escortPSlotResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "riddle_escort"
    return defs[requested] or defs[server.defaultShipType] or defs.riddle_escort or {}
end

local function _escortPSlotResolveWeaponDefinition(weaponType)
    local defs = escortPSlotWeaponRegistryData or {}
    local requested = weaponType or "naniteFlakBattery"
    return defs[requested] or defs.naniteFlakBattery or {}
end

local function _escortPSlotBuildConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "none")
    local weaponDef = _escortPSlotResolveWeaponDefinition(weaponType)
    return {
        weaponType = weaponType,
        groupIndex = math.max(1, math.floor(tonumber(slotDef and slotDef.groupIndex) or 1)),
        firePosOffset = _escortPSlotCloneVec3(slotDef and slotDef.firePosOffset, 0, 0, -4),
        fireDirRelative = _escortPSlotCloneVec3(slotDef and slotDef.fireDirRelative, 0, 0, -1),
        fireDeviationAngle = math.max(0.0, tonumber(slotDef and slotDef.fireDeviationAngle) or 0.0),
        aimMode = tostring((slotDef and slotDef.aimMode) or "fixed"),
        cooldown = tonumber(weaponDef.cooldown) or 0.0,
        maxRange = tonumber(weaponDef.maxRange) or 0.0,
        heatPerShot = tonumber(weaponDef.heatPerShot) or 0.0,
        heatDissipationPerSecond = tonumber(weaponDef.heatDissipationPerSecond) or 0.0,
        overheatThreshold = tonumber(weaponDef.overheatThreshold) or 0.0,
        recoverThreshold = tonumber(weaponDef.recoverThreshold) or 0.0,
    }
end

local function _escortPSlotBuildRuntime()
    return {
        heat = 0.0,
        overheated = false,
        cooldownRemain = 0.0,
    }
end

local function _escortPSlotEnsureGroupEntry(state, groupIndex)
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

local function _escortPSlotResolveGroupHudData(state)
    local groups = (state and state.groups) or {}
    local result = {}
    for groupIndex = 1, #groups do
        local entry = groups[groupIndex] or {}
        local slotIndices = entry.slotIndices or {}
        local groupHeat = 0.0
        local groupOverheated = false
        local groupThreshold = 100.0
        for i = 1, #slotIndices do
            local slot = ((state or {}).slots or {})[slotIndices[i]]
            if slot ~= nil and slot.config ~= nil and slot.runtime ~= nil then
                groupHeat = math.max(groupHeat, slot.runtime.heat or 0.0)
                groupOverheated = groupOverheated or (slot.runtime.overheated and true or false)
                groupThreshold = math.max(1.0, slot.config.overheatThreshold or groupThreshold)
            end
        end
        result[groupIndex] = {
            heat = groupHeat,
            overheated = groupOverheated,
            threshold = groupThreshold,
        }
    end
    return result
end

function server.escortPSlotStateInit(shipType)
    local shipDef = _escortPSlotResolveShipDefinition(shipType)
    local state = {
        requestFire = false,
        slots = {},
        groups = {},
        nextGroupIndex = 1,
    }

    local slotDefs = shipDef.pSlots or {}
    for i = 1, #slotDefs do
        local config = _escortPSlotBuildConfig(slotDefs[i])
        state.slots[i] = {
            config = config,
            runtime = _escortPSlotBuildRuntime(),
        }
        local groupEntry = _escortPSlotEnsureGroupEntry(state, config.groupIndex)
        groupEntry.slotIndices[#groupEntry.slotIndices + 1] = i
    end

    server.escortPSlotState = state
    return state
end

function server.escortPSlotStateSetRequestFire(active)
    if server.escortPSlotState == nil then
        return
    end
    server.escortPSlotState.requestFire = active and true or false
end

function server.escortPSlotStateConsumeRequestFire()
    if server.escortPSlotState == nil then
        return false
    end
    local requested = server.escortPSlotState.requestFire and true or false
    server.escortPSlotState.requestFire = false
    return requested
end

function server.escortPSlotStateResetRuntime()
    local state = server.escortPSlotState
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
end

function server.escortPSlotStatePushHud(force)
    local _ = force
    local shipBody = server.shipBody or 0
    if shipBody == 0 then
        return
    end
    local groupHud = _escortPSlotResolveGroupHudData(server.escortPSlotState)
    local g1 = groupHud[1] or { heat = 0.0, overheated = false, threshold = 100.0 }
    local g2 = groupHud[2] or { heat = 0.0, overheated = false, threshold = 100.0 }
    ClientCall(
        0,
        "client.updateEscortPHudState",
        shipBody,
        g1.heat, g1.overheated and 1 or 0, g1.threshold,
        g2.heat, g2.overheated and 1 or 0, g2.threshold
    )
end

function server.escortPSlotStatePushHudReset(force)
    local _ = force
    ClientCall(0, "client.resetEscortPHudState", server.shipBody or 0)
end
