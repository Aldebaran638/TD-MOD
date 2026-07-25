---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}
server.weaponGroupStateById = server.weaponGroupStateById or {}

local _groupDefinitions = {
    xSlot = { slotType = "X", mountCollection = "xSlots" },
    lSlot = { slotType = "L", mountCollection = "lSlots" },
    mSlot = { slotType = "M", mountCollection = "mSlots" },
    gSlot = { slotType = "G", mountCollection = "gSlots" },
    hSlot = { slotType = "H", mountCollection = "hSlots" },
}

local function _resolveShipDefinition(shipType)
    if server.shipSlotLoadoutResolveShipDefinition ~= nil then
        local resolved = server.shipSlotLoadoutResolveShipDefinition(shipType)
        if resolved ~= nil then return resolved end
    end
    local defs = shipTypeRegistryData or {}
    return defs[shipType] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

local function _buildState(groupId, shipType)
    local group = _groupDefinitions[groupId]
    local shipDef = _resolveShipDefinition(shipType)
    local mounts = shipDef[group.mountCollection] or {}
    local state = {
        groupId = groupId,
        slotType = group.slotType,
        mountCollection = group.mountCollection,
        shipType = shipType,
        nextMountIndex = 1,
        mounts = {},
        pending = nil,
        hudSyncAge = 0.0,
    }
    for i = 1, #mounts do
        state.mounts[i] = {
            definition = mounts[i],
            cooldownRemain = 0.0,
        }
    end
    return state
end

local function _pickReadyMount(state)
    local count = #(state.mounts or {})
    if count == 0 then return nil, nil end
    local start = math.max(1, math.min(count, math.floor(state.nextMountIndex or 1)))
    for offset = 0, count - 1 do
        local index = ((start - 1 + offset) % count) + 1
        local mount = state.mounts[index]
        if (tonumber(mount.cooldownRemain) or 0.0) <= 0.0 then
            state.nextMountIndex = (index % count) + 1
            return mount, index
        end
    end
    return nil, nil
end

local function _resolveWeapon(state)
    local first = (state.mounts or {})[1]
    local weaponType = tostring(first and first.definition and first.definition.weaponType or "none")
    return weaponType, (weaponData or {})[weaponType]
end

local function _pushHud(state)
    local weaponType, weaponDef = _resolveWeapon(state)
    if tostring((weaponDef or {}).legacyController or "") ~= "" then return end
    local cooldown = math.max(0.0, tonumber((weaponDef or {}).cooldown) or 0.0)
    local values, maximums, phases = {}, {}, {}
    for i = 1, 4 do
        local mount = (state.mounts or {})[i]
        local remaining = mount and math.max(0.0, tonumber(mount.cooldownRemain) or 0.0) or 0.0
        values[i] = remaining
        maximums[i] = mount and cooldown or 0.0
        phases[i] = remaining > 0.0001 and "cooldown" or "idle"
        local pending = state.pending
        if mount ~= nil and pending ~= nil and pending.mount == mount then
            local total = math.max(0.0, tonumber(pending.total) or 0.0)
            values[i] = math.max(0.0, total - math.max(0.0, tonumber(pending.remaining) or 0.0))
            maximums[i] = total
            phases[i] = "charging"
        end
    end
    ClientCall(
        0,
        "client.updateWeaponGroupHudState",
        server.shipBody or 0,
        tostring(state.groupId or ""),
        weaponType,
        values[1], values[2], values[3], values[4],
        maximums[1], maximums[2], maximums[3], maximums[4],
        phases[1], phases[2], phases[3], phases[4]
    )
end

local function _legacyFire(controllerId, groupId, request)
    if controllerId == "xSlot" and server.xSlotStateSetRequestFire ~= nil then
        server.xSlotStateSetRequestFire(true)
        return true
    end
    if controllerId == "lSlot" and server.lSlotStateSetRequestFire ~= nil then
        server.lSlotStateSetRequestFire(true)
        return true
    end
    if controllerId == "mSlot" and server.mSlotControlSetFireRequest ~= nil then
        return server.mSlotControlSetFireRequest(request.shipBodyId, request.targetVehicleId, request.targetBodyId)
    end
    if controllerId == "gSlot" and server.gSlotControlSetFireRequest ~= nil then
        return server.gSlotControlSetFireRequest(request.shipBodyId, request.targetVehicleId, request.targetBodyId)
    end
    if controllerId == "hSlot" and server.hSlotControlSetFireRequested ~= nil then
        server.hSlotLastFireRequest = request
        server.hSlotControlSetFireRequested(true)
        return true
    end
    return false
end

function server.weaponGroupInit(shipType)
    local resolvedType = tostring(shipType or server.defaultShipType or "enigmaticCruiser")
    server.weaponGroupStateById = {}
    for _, behavior in pairs(server.weaponBehaviorRegistry or {}) do
        if type(behavior.reset) == "function" then behavior.reset() end
    end
    local valid = true
    for groupId, _ in pairs(_groupDefinitions) do
        local state = _buildState(groupId, resolvedType)
        server.weaponGroupStateById[groupId] = state
        local weaponType, definition = _resolveWeapon(state)
        if weaponType ~= "none" and definition ~= nil then
            local ok, err = server.weaponBehaviorValidateDefinition(definition)
            if not ok then
                valid = false
                DebugPrint("[weaponGroup] " .. groupId .. ": " .. tostring(err))
            end
        end
    end
    return valid
end

function server.weaponGroupReset()
    for _, state in pairs(server.weaponGroupStateById or {}) do
        state.nextMountIndex = 1
        state.pending = nil
        for i = 1, #(state.mounts or {}) do
            state.mounts[i].cooldownRemain = 0.0
        end
    end
    for _, behavior in pairs(server.weaponBehaviorRegistry or {}) do
        if type(behavior.reset) == "function" then behavior.reset() end
    end
end

function server.weaponGroupRequestFire(groupId, request)
    local id = tostring(groupId or "")
    local state = server.weaponGroupStateById[id]
    if state == nil then return false, "unknown weapon group" end
    local weaponType, weaponDef = _resolveWeapon(state)
    if weaponDef == nil or weaponType == "none" then return false, "weapon not found" end

    local normalizedRequest = request or {}
    normalizedRequest.shipBodyId = math.floor(normalizedRequest.shipBodyId or server.shipBody or 0)
    normalizedRequest.targetVehicleId = math.floor(normalizedRequest.targetVehicleId or 0)
    normalizedRequest.targetBodyId = math.floor(normalizedRequest.targetBodyId or 0)
    normalizedRequest.groupId = id
    normalizedRequest.weaponType = weaponType

    local legacy = tostring(weaponDef.legacyController or "")
    if legacy ~= "" then return _legacyFire(legacy, id, normalizedRequest) end

    local mount, mountIndex = _pickReadyMount(state)
    if mount == nil then return false, "all mounts cooling down" end
    local behavior = server.weaponBehaviorGet(weaponDef.behaviorType)
    if behavior == nil then return false, "behavior not registered" end
    local context = {
        groupId = id,
        slotType = state.slotType,
        shipBodyId = normalizedRequest.shipBodyId,
        targetVehicleId = normalizedRequest.targetVehicleId,
        targetBodyId = normalizedRequest.targetBodyId,
        weaponType = weaponType,
        weaponDefinition = weaponDef,
        mountDefinition = mount.definition,
        mountIndex = mountIndex,
    }
    local fireProfile = weaponDef.fireProfile or {}
    local chargeDuration = math.max(0.0, tonumber(fireProfile.chargeDuration) or 0.0)
    if chargeDuration > 0.0 then
        if state.pending ~= nil then return false, "weapon group is charging" end
        state.pending = {
            remaining = chargeDuration,
            total = chargeDuration,
            behavior = behavior,
            context = context,
            mount = mount,
            cooldown = math.max(0.0, tonumber(weaponDef.cooldown) or 0.0),
        }
        _pushHud(state)
        return true, nil
    end
    local fired = behavior.fire(context) and true or false
    if fired then mount.cooldownRemain = math.max(0.0, tonumber(weaponDef.cooldown) or 0.0) end
    _pushHud(state)
    return fired, fired and nil or "controller rejected fire"
end

function server.weaponGroupTick(dt)
    local delta = math.max(0.0, tonumber(dt) or 0.0)
    for _, state in pairs(server.weaponGroupStateById or {}) do
        for i = 1, #(state.mounts or {}) do
            local mount = state.mounts[i]
            mount.cooldownRemain = math.max(0.0, (tonumber(mount.cooldownRemain) or 0.0) - delta)
        end
        local pending = state.pending
        if pending ~= nil then
            pending.remaining = (tonumber(pending.remaining) or 0.0) - delta
            if pending.remaining <= 0.0 then
                local fired = pending.behavior.fire(pending.context) and true or false
                if fired then pending.mount.cooldownRemain = pending.cooldown end
                state.pending = nil
            end
        end
        state.hudSyncAge = (tonumber(state.hudSyncAge) or 0.0) + delta
        local currentMode = server.shipRuntimeGetCurrentMainWeapon ~= nil
            and server.shipRuntimeGetCurrentMainWeapon(server.shipBody or 0) or ""
        if state.hudSyncAge >= 0.10 and currentMode == state.groupId then
            state.hudSyncAge = 0.0
            _pushHud(state)
        end
    end
    for _, behavior in pairs(server.weaponBehaviorRegistry or {}) do
        if type(behavior.tick) == "function" then behavior.tick(delta) end
    end
end
