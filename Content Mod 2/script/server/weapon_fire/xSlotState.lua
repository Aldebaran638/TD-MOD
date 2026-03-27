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
end
