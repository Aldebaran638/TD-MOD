---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.xSlotState = server.xSlotState or {
    requestFire = false,
    holdRequested = false,
    releaseRequested = false,
    activeSlot = 1,
    lastTickState = "idle",
    lastTickActiveSlot = 1,
    slots = {},
}

server.xSlotHudSyncState = server.xSlotHudSyncState or {
    lastValue1 = nil,
    lastValue2 = nil,
    lastMax1 = nil,
    lastMax2 = nil,
    lastPhase1 = nil,
    lastPhase2 = nil,
    lastSendTime = -1000.0,
}

local function _xSlotHudResolveSlotPayload(slotEntry)
    local config = (slotEntry and slotEntry.config) or {}
    local runtime = (slotEntry and slotEntry.runtime) or {}
    local state = tostring(runtime.state or "idle")

    if state == "charging" or state == "charged" then
        return math.max(0.0, tonumber(runtime.charge) or 0.0), math.max(0.0, tonumber(config.chargeDuration) or 0.0), state
    end

    if state == "launching" then
        local maxValue = math.max(0.0, tonumber(config.launchDuration) or 0.0)
        local current = maxValue - math.max(0.0, tonumber(runtime.launchRemain) or 0.0)
        if current < 0.0 then
            current = 0.0
        end
        return current, maxValue, state
    end

    local cooldown = math.max(0.0, tonumber(runtime.cd) or 0.0)
    local maxCooldown = math.max(0.0, tonumber(config.cooldown) or 0.0)
    if cooldown > 0.0001 then
        return cooldown, maxCooldown, "cooldown"
    end

    return 0.0, math.max(0.0, tonumber(config.chargeDuration) or 0.0), "idle"
end

local function _xSlotStateCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = t.x or defaultX or 0.0,
        y = t.y or defaultY or 0.0,
        z = t.z or defaultZ or 0.0,
    }
end

local function _xSlotStateResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    return defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

local function _xSlotStateResolveWeaponDefinition(weaponType)
    local requested = weaponType or "tachyonLance"
    local registryDefs = xSlotWeaponRegistryData or {}
    local runtimeDefs = weaponData or {}
    return registryDefs[requested] or registryDefs.tachyonLance or runtimeDefs[requested] or runtimeDefs.tachyonLance or {}
end

local function _xSlotStateBuildConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "none")
    local weaponDef = _xSlotStateResolveWeaponDefinition(weaponType)
    local cooldown = weaponDef.cooldown
    if cooldown == nil then
        cooldown = weaponDef.CD
    end

    return {
        weaponType = weaponType,
        firePosOffset = _xSlotStateCloneVec3(slotDef and slotDef.firePosOffset, 0, 0, -4),
        fireDirRelative = _xSlotStateCloneVec3(slotDef and slotDef.fireDirRelative, 0, 0, -1),
        chargeDuration = weaponDef.chargeDuration or 0.0,
        launchDuration = weaponDef.launchDuration or 0.0,
        randomTrajectoryAngle = weaponDef.randomTrajectoryAngle or 0.0,
        cooldown = cooldown or 0.0,
        aimControlMode = tostring(weaponDef.aimControlMode or "fixed"),
        aimLimitDeg = tonumber(weaponDef.aimLimitDeg) or 0.0,
        aimPitchOffsetDeg = tonumber(weaponDef.aimPitchOffsetDeg) or 0.0,
    }
end

local function _xSlotStateBuildRuntime()
    return {
        cd = 0.0,
        state = "idle",
        charge = 0.0,
        launchRemain = 0.0,
    }
end

local function _xSlotNow()
    return (GetTime ~= nil) and GetTime() or 0.0
end

function server.xSlotStateMarkHudDirty()
    local sync = server.xSlotHudSyncState or {}
    sync.lastValue1 = nil
    sync.lastValue2 = nil
    sync.lastMax1 = nil
    sync.lastMax2 = nil
    sync.lastPhase1 = nil
    sync.lastPhase2 = nil
    sync.lastSendTime = -1000.0
    server.xSlotHudSyncState = sync
end

function server.xSlotStateInit(shipType)
    local shipDef = _xSlotStateResolveShipDefinition(shipType)
    local state = {
        requestFire = false,
        holdRequested = false,
        releaseRequested = false,
        activeSlot = 1,
        lastTickState = "idle",
        lastTickActiveSlot = 1,
        slots = {},
    }

    local slotDefs = shipDef.xSlots or {}
    for i = 1, #slotDefs do
        state.slots[i] = {
            config = _xSlotStateBuildConfig(slotDefs[i]),
            runtime = _xSlotStateBuildRuntime(),
        }
    end

    server.xSlotState = state
    server.xSlotHudSyncState = {
        lastValue1 = nil,
        lastValue2 = nil,
        lastMax1 = nil,
        lastMax2 = nil,
        lastPhase1 = nil,
        lastPhase2 = nil,
        lastSendTime = -1000.0,
    }
    server.xSlotStateMarkHudDirty()
    return state
end

function server.xSlotStateSetRequestFire(active)
    local state = server.xSlotState
    if state == nil then
        return
    end
    state.requestFire = active and true or false
end

function server.xSlotStateSetHoldRequested(active)
    local state = server.xSlotState
    if state == nil then
        return
    end
    state.holdRequested = active and true or false
end

function server.xSlotStateGetHoldRequested()
    local state = server.xSlotState
    if state == nil then
        return false
    end
    return state.holdRequested and true or false
end

function server.xSlotStateSetReleaseRequested(active)
    local state = server.xSlotState
    if state == nil then
        return
    end
    state.releaseRequested = active and true or false
end

function server.xSlotStateConsumeReleaseRequested()
    local state = server.xSlotState
    if state == nil then
        return false
    end
    local requested = state.releaseRequested and true or false
    state.releaseRequested = false
    return requested
end

function server.xSlotStateConsumeRequestFire()
    local state = server.xSlotState
    if state == nil then
        return false
    end
    local requested = state.requestFire and true or false
    state.requestFire = false
    return requested
end

function server.xSlotStateResetRuntime()
    local state = server.xSlotState
    if state == nil then
        return
    end

    state.requestFire = false
    state.holdRequested = false
    state.releaseRequested = false
    state.activeSlot = 1
    state.lastTickState = "idle"
    state.lastTickActiveSlot = 1

    local slots = state.slots or {}
    for i = 1, #slots do
        local runtime = (slots[i] and slots[i].runtime) or nil
        if runtime ~= nil then
            runtime.cd = 0.0
            runtime.state = "idle"
            runtime.charge = 0.0
            runtime.launchRemain = 0.0
        end
    end
    server.xSlotStateMarkHudDirty()
end

function server.xSlotStatePushHud(force)
    local shipBodyId = server.shipBody or 0
    if shipBodyId == 0 then
        return
    end

    local slots = (server.xSlotState and server.xSlotState.slots) or {}
    local value1, max1, phase1 = _xSlotHudResolveSlotPayload(slots[1])
    local value2, max2, phase2 = _xSlotHudResolveSlotPayload(slots[2])

    local sync = server.xSlotHudSyncState or {}
    local nowTime = _xSlotNow()
    local shouldSend = force
        or sync.lastValue1 == nil
        or sync.lastValue2 == nil
        or sync.lastMax1 == nil
        or sync.lastMax2 == nil
        or sync.lastPhase1 == nil
        or sync.lastPhase2 == nil
        or math.abs((sync.lastValue1 or 0.0) - value1) > 0.0001
        or math.abs((sync.lastValue2 or 0.0) - value2) > 0.0001
        or math.abs((sync.lastMax1 or 0.0) - max1) > 0.0001
        or math.abs((sync.lastMax2 or 0.0) - max2) > 0.0001
        or (sync.lastPhase1 or "") ~= phase1
        or (sync.lastPhase2 or "") ~= phase2
        or ((nowTime - (sync.lastSendTime or -1000.0)) >= 0.5)

    if shouldSend then
        ClientCall(0, "client.updateXSlotHudState", shipBodyId, value1, value2, max1, max2, phase1, phase2)
        sync.lastSendTime = nowTime
    end

    sync.lastValue1 = value1
    sync.lastValue2 = value2
    sync.lastMax1 = max1
    sync.lastMax2 = max2
    sync.lastPhase1 = phase1
    sync.lastPhase2 = phase2
    server.xSlotHudSyncState = sync
end
