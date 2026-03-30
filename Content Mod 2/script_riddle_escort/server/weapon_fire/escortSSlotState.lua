---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.escortSSlotState = server.escortSSlotState or {
    requestFire = false,
    nextSlotIndex = 1,
    slots = {},
}

local function _escortSSlotCloneVec3(v, defaultX, defaultY, defaultZ)
    local t = v or {}
    return {
        x = tonumber(t.x) or defaultX or 0.0,
        y = tonumber(t.y) or defaultY or 0.0,
        z = tonumber(t.z) or defaultZ or 0.0,
    }
end

local function _escortSSlotResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "riddle_escort"
    return defs[requested] or defs[server.defaultShipType] or defs.riddle_escort or {}
end

local function _escortSSlotResolveWeaponDefinition(weaponType)
    local requested = weaponType or "gammaLaser"
    local registryDefs = escortSSlotWeaponRegistryData or {}
    local runtimeDefs = weaponData or {}
    return registryDefs[requested] or registryDefs.gammaLaser or runtimeDefs[requested] or runtimeDefs.gammaLaser or {}
end

local function _escortSSlotBuildConfig(slotDef)
    local weaponType = tostring((slotDef and slotDef.weaponType) or "none")
    local weaponDef = _escortSSlotResolveWeaponDefinition(weaponType)
    return {
        weaponType = weaponType,
        firePosOffset = _escortSSlotCloneVec3(slotDef and slotDef.firePosOffset, 0, 0, -4),
        fireDirRelative = _escortSSlotCloneVec3(slotDef and slotDef.fireDirRelative, 0, 0, -1),
        aimMode = tostring((slotDef and slotDef.aimMode) or "fixed"),
        cooldown = tonumber(weaponDef.cooldown) or 0.0,
        launchDuration = tonumber(weaponDef.launchDuration) or 0.0,
        randomTrajectoryAngle = tonumber(weaponDef.randomTrajectoryAngle) or 0.0,
        maxRange = tonumber(weaponDef.maxRange) or 0.0,
        damageMin = tonumber(weaponDef.damageMin) or 0.0,
        damageMax = tonumber(weaponDef.damageMax) or tonumber(weaponDef.damageMin) or 0.0,
        shieldFix = tonumber(weaponDef.shieldFix) or 1.0,
        armorFix = tonumber(weaponDef.armorFix) or 1.0,
        bodyFix = tonumber(weaponDef.bodyFix) or 1.0,
    }
end

local function _escortSSlotBuildRuntime()
    return {
        cooldownRemain = 0.0,
    }
end

function server.escortSSlotStateInit(shipType)
    local shipDef = _escortSSlotResolveShipDefinition(shipType)
    local state = {
        requestFire = false,
        nextSlotIndex = 1,
        slots = {},
    }

    local slotDefs = shipDef.sSlots or {}
    for i = 1, #slotDefs do
        state.slots[i] = {
            config = _escortSSlotBuildConfig(slotDefs[i]),
            runtime = _escortSSlotBuildRuntime(),
        }
    end

    server.escortSSlotState = state
    return state
end

function server.escortSSlotStateSetRequestFire(active)
    local state = server.escortSSlotState
    if state == nil then
        return
    end
    state.requestFire = active and true or false
end

function server.escortSSlotStateConsumeRequestFire()
    local state = server.escortSSlotState
    if state == nil then
        return false
    end
    local requested = state.requestFire and true or false
    state.requestFire = false
    return requested
end

function server.escortSSlotStateResetRuntime()
    local state = server.escortSSlotState
    if state == nil then
        return
    end
    state.requestFire = false
    state.nextSlotIndex = 1
    local slots = state.slots or {}
    for i = 1, #slots do
        local runtime = (slots[i] or {}).runtime or nil
        if runtime ~= nil then
            runtime.cooldownRemain = 0.0
        end
    end
end

function server.escortSSlotStatePushHud(force)
    local _ = force
    local shipBodyId = server.shipBody or 0
    if shipBodyId == 0 then
        return
    end

    local slots = (server.escortSSlotState and server.escortSSlotState.slots) or {}
    local cds = { 0.0, 0.0, 0.0, 0.0 }
    local maxCds = { 1.0, 1.0, 1.0, 1.0 }
    for i = 1, 4 do
        local entry = slots[i] or {}
        local runtime = entry.runtime or {}
        local config = entry.config or {}
        cds[i] = math.max(0.0, tonumber(runtime.cooldownRemain) or 0.0)
        maxCds[i] = math.max(0.0, tonumber(config.cooldown) or 0.0)
    end

    ClientCall(
        0,
        "client.updateEscortSHudState",
        shipBodyId,
        cds[1], cds[2], cds[3], cds[4],
        maxCds[1], maxCds[2], maxCds[3], maxCds[4]
    )
end
