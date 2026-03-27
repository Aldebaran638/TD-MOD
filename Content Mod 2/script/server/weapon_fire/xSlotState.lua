---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.xSlotState = server.xSlotState or {
    requestFire = false,
    activeSlot = 1,
    lastTickState = "idle",
    lastTickActiveSlot = 1,
    slots = {},
}

server.xSlotHudSyncState = server.xSlotHudSyncState or {
    lastCd1 = nil,
    lastCd2 = nil,
    lastMaxCd1 = nil,
    lastMaxCd2 = nil,
    lastSendTime = -1000.0,
}

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
    }
end

local function _xSlotStateBuildRuntime()
    return {
        cd = 0.0,
        state = "idle",
        chargeRemain = 0.0,
        launchRemain = 0.0,
    }
end

local function _xSlotNow()
    return (GetTime ~= nil) and GetTime() or 0.0
end

function server.xSlotStateMarkHudDirty()
    local sync = server.xSlotHudSyncState or {}
    sync.lastCd1 = nil
    sync.lastCd2 = nil
    sync.lastMaxCd1 = nil
    sync.lastMaxCd2 = nil
    sync.lastSendTime = -1000.0
    server.xSlotHudSyncState = sync
end

function server.xSlotStateInit(shipType)
    local shipDef = _xSlotStateResolveShipDefinition(shipType)
    local state = {
        requestFire = false,
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
        lastCd1 = nil,
        lastCd2 = nil,
        lastMaxCd1 = nil,
        lastMaxCd2 = nil,
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
    state.activeSlot = 1
    state.lastTickState = "idle"
    state.lastTickActiveSlot = 1

    local slots = state.slots or {}
    for i = 1, #slots do
        local runtime = (slots[i] and slots[i].runtime) or nil
        if runtime ~= nil then
            runtime.cd = 0.0
            runtime.state = "idle"
            runtime.chargeRemain = 0.0
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
    local slot1Entry = slots[1] or {}
    local slot2Entry = slots[2] or {}
    local slot1 = slot1Entry.runtime or {}
    local slot2 = slot2Entry.runtime or {}
    local slot1Config = slot1Entry.config or {}
    local slot2Config = slot2Entry.config or {}
    local cd1 = math.max(0.0, tonumber(slot1.cd) or 0.0)
    local cd2 = math.max(0.0, tonumber(slot2.cd) or 0.0)
    local maxCd1 = math.max(0.0, tonumber(slot1Config.cooldown) or 0.0)
    local maxCd2 = math.max(0.0, tonumber(slot2Config.cooldown) or 0.0)

    local sync = server.xSlotHudSyncState or {}
    local nowTime = _xSlotNow()
    local shouldSend = force
        or sync.lastCd1 == nil
        or sync.lastCd2 == nil
        or sync.lastMaxCd1 == nil
        or sync.lastMaxCd2 == nil
        or math.abs((sync.lastCd1 or 0.0) - cd1) > 0.0001
        or math.abs((sync.lastCd2 or 0.0) - cd2) > 0.0001
        or math.abs((sync.lastMaxCd1 or 0.0) - maxCd1) > 0.0001
        or math.abs((sync.lastMaxCd2 or 0.0) - maxCd2) > 0.0001
        or ((nowTime - (sync.lastSendTime or -1000.0)) >= 0.5)

    if shouldSend then
        ClientCall(0, "client.updateXSlotHudState", shipBodyId, cd1, cd2, maxCd1, maxCd2)
        sync.lastSendTime = nowTime
    end

    sync.lastCd1 = cd1
    sync.lastCd2 = cd2
    sync.lastMaxCd1 = maxCd1
    sync.lastMaxCd2 = maxCd2
    server.xSlotHudSyncState = sync
end
