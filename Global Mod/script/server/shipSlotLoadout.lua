---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.shipSlotLoadoutStateByType = server.shipSlotLoadoutStateByType or {}
server.shipSlotResolvedDefinitionByType = server.shipSlotResolvedDefinitionByType or {}

local function _slotLoadoutCloneTable(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = _slotLoadoutCloneTable(v)
    end
    return copy
end

local function _slotLoadoutResolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    return defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

local function _slotLoadoutFindConfiguration(definition, configurationId)
    local configs = definition.slotConfigurations or {}
    for i = 1, #configs do
        local cfg = configs[i]
        if tostring(cfg.configurationId or "") == tostring(configurationId or "") then
            return cfg
        end
    end
    return nil
end

local function _slotLoadoutWeaponAllowed(definition, slotType, weaponType)
    local pools = definition.slotWeaponPools or {}
    local pool = pools[slotType] or {}
    for i = 1, #pool do
        if tostring(pool[i]) == tostring(weaponType) then
            return true
        end
    end
    return false
end

local function _slotLoadoutBuildResolvedLoadout(definition, configuration, requestedLoadout)
    local result = {}
    local defaults = configuration.defaultLoadout or {}
    local groups = configuration.slotGroups or {}

    for i = 1, #groups do
        local group = groups[i] or {}
        local slotType = tostring(group.slotType or "")
        if slotType ~= "" then
            local candidate = requestedLoadout and requestedLoadout[slotType] or nil
            if candidate == nil or candidate == "" then
                candidate = defaults[slotType]
            end
            if candidate == nil or candidate == "" then
                return nil, "missing weapon for slot group " .. slotType
            end
            if not _slotLoadoutWeaponAllowed(definition, slotType, candidate) then
                return nil, "weapon " .. tostring(candidate) .. " is not allowed for slot group " .. slotType
            end
            result[slotType] = tostring(candidate)
        end
    end

    return result, nil
end

local function _slotLoadoutValidateConfigurationShape(configuration)
    local groups = configuration.slotGroups or {}
    local mounts = configuration.mounts or {}

    for i = 1, #groups do
        local group = groups[i] or {}
        local mountCollection = tostring(group.mountCollection or "")
        local requiredCount = math.max(0, math.floor(tonumber(group.count) or 0))
        local mountEntries = mounts[mountCollection] or {}
        if mountCollection == "" then
            return false, "slot group missing mountCollection"
        end
        if #mountEntries ~= requiredCount then
            return false, "mount count mismatch for " .. mountCollection
        end
    end

    return true, nil
end

local function _slotLoadoutRebuildResolvedDefinition(shipType)
    local state = server.shipSlotLoadoutStateByType[shipType] or nil
    if state == nil then
        return nil
    end

    local baseDefinition = _slotLoadoutResolveShipDefinition(shipType)
    local configuration = _slotLoadoutFindConfiguration(baseDefinition, state.configurationId)
    if configuration == nil then
        return nil
    end

    local resolved = _slotLoadoutCloneTable(baseDefinition)
    local groups = configuration.slotGroups or {}
    local mounts = configuration.mounts or {}
    local loadout = state.loadout or {}

    resolved.xSlots = {}
    resolved.lSlots = {}
    resolved.sSlots = {}
    resolved.gSlots = {}
    resolved.hSlots = {}

    for i = 1, #groups do
        local group = groups[i] or {}
        local slotType = tostring(group.slotType or "")
        local mountCollection = tostring(group.mountCollection or "")
        local mountEntries = mounts[mountCollection] or {}
        local selectedWeapon = loadout[slotType]

        resolved[mountCollection] = {}
        for j = 1, #mountEntries do
            local mountDef = _slotLoadoutCloneTable(mountEntries[j])
            mountDef.weaponType = tostring(selectedWeapon or "none")
            resolved[mountCollection][j] = mountDef
        end
    end

    resolved.activeSlotConfigurationId = state.configurationId
    resolved.activeSlotLoadout = _slotLoadoutCloneTable(state.loadout)

    server.shipSlotResolvedDefinitionByType[shipType] = resolved
    return resolved
end

local function _slotLoadoutInitInternal(shipType)
    local definition = _slotLoadoutResolveShipDefinition(shipType)
    local defaultConfigId = tostring(definition.defaultSlotConfigurationId or "")
    local configuration = _slotLoadoutFindConfiguration(definition, defaultConfigId)

    if configuration == nil then
        local configs = definition.slotConfigurations or {}
        configuration = configs[1]
        if configuration ~= nil then
            defaultConfigId = tostring(configuration.configurationId or "")
        end
    end

    if configuration == nil then
        return false, "no slot configuration found"
    end

    local shapeOk, shapeError = _slotLoadoutValidateConfigurationShape(configuration)
    if not shapeOk then
        return false, shapeError
    end

    local loadout, loadoutError = _slotLoadoutBuildResolvedLoadout(definition, configuration, configuration.defaultLoadout or {})
    if loadout == nil then
        return false, loadoutError
    end

    server.shipSlotLoadoutStateByType[shipType] = {
        shipType = shipType,
        configurationId = defaultConfigId,
        loadout = loadout,
    }

    _slotLoadoutRebuildResolvedDefinition(shipType)
    return true, nil
end

local function _slotLoadoutEnsureInitialized(shipType)
    if server.shipSlotLoadoutStateByType[shipType] ~= nil then
        return true
    end
    local ok = _slotLoadoutInitInternal(shipType)
    return ok
end

function server.shipSlotLoadoutInit(shipType)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    local ok, err = _slotLoadoutInitInternal(resolvedType)
    if not ok then
        DebugPrint("[shipSlotLoadout] init failed: " .. tostring(err or "unknown"))
        return false
    end
    return true
end

function server.shipSlotLoadoutGetState(shipType)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    if not _slotLoadoutEnsureInitialized(resolvedType) then
        return nil
    end

    local state = server.shipSlotLoadoutStateByType[resolvedType]
    if state == nil then
        return nil
    end

    return {
        shipType = state.shipType,
        configurationId = state.configurationId,
        loadout = _slotLoadoutCloneTable(state.loadout),
    }
end

function server.shipSlotLoadoutSetConfiguration(shipType, configurationId)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    if not _slotLoadoutEnsureInitialized(resolvedType) then
        return false, "state init failed"
    end

    local definition = _slotLoadoutResolveShipDefinition(resolvedType)
    local configuration = _slotLoadoutFindConfiguration(definition, configurationId)
    if configuration == nil then
        return false, "configuration not found"
    end

    local shapeOk, shapeError = _slotLoadoutValidateConfigurationShape(configuration)
    if not shapeOk then
        return false, shapeError
    end

    local previous = server.shipSlotLoadoutStateByType[resolvedType] or {}
    local requestedLoadout = _slotLoadoutCloneTable(previous.loadout or {})

    local loadout, loadoutError = _slotLoadoutBuildResolvedLoadout(definition, configuration, requestedLoadout)
    if loadout == nil then
        return false, loadoutError
    end

    server.shipSlotLoadoutStateByType[resolvedType] = {
        shipType = resolvedType,
        configurationId = tostring(configuration.configurationId or configurationId),
        loadout = loadout,
    }

    _slotLoadoutRebuildResolvedDefinition(resolvedType)
    return true, nil
end

function server.shipSlotLoadoutSetLoadout(shipType, requestedLoadout)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    if not _slotLoadoutEnsureInitialized(resolvedType) then
        return false, "state init failed"
    end

    local state = server.shipSlotLoadoutStateByType[resolvedType] or {}
    local definition = _slotLoadoutResolveShipDefinition(resolvedType)
    local configuration = _slotLoadoutFindConfiguration(definition, state.configurationId)
    if configuration == nil then
        return false, "configuration not found"
    end

    local merged = _slotLoadoutCloneTable(state.loadout or {})
    local incoming = requestedLoadout or {}
    for slotType, weaponType in pairs(incoming) do
        merged[tostring(slotType)] = tostring(weaponType)
    end

    local loadout, loadoutError = _slotLoadoutBuildResolvedLoadout(definition, configuration, merged)
    if loadout == nil then
        return false, loadoutError
    end

    state.loadout = loadout
    server.shipSlotLoadoutStateByType[resolvedType] = state

    _slotLoadoutRebuildResolvedDefinition(resolvedType)
    return true, nil
end

function server.shipSlotLoadoutResolveShipDefinition(shipType)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    if not _slotLoadoutEnsureInitialized(resolvedType) then
        return _slotLoadoutResolveShipDefinition(resolvedType)
    end

    local resolved = server.shipSlotResolvedDefinitionByType[resolvedType]
    if resolved == nil then
        resolved = _slotLoadoutRebuildResolvedDefinition(resolvedType)
    end

    if resolved == nil then
        return _slotLoadoutResolveShipDefinition(resolvedType)
    end
    return resolved
end
