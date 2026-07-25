---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- slot_loadout.lua
-- 飞船槽位装载管理模块 - 符合规范的模块文件
-- 只导出 server.slotLoadoutInit() 和 server.slotLoadoutTick()

server = server or {}

-- 模块内部状态
local _stateByType = {}
local _resolvedDefinitionByType = {}
local _templateRegistryRoot = "StellarisShips/server/spawnTemplates"

-- ============ 内部辅助函数 ============

local function _cloneTable(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = _cloneTable(v)
    end
    return copy
end

local function _resolveShipDefinition(shipType)
    local defs = shipTypeRegistryData or {}
    local requested = shipType or server.defaultShipType or "enigmaticCruiser"
    return defs[requested] or defs[server.defaultShipType] or defs.enigmaticCruiser or {}
end

local function _findConfiguration(definition, configurationId)
    local configs = definition.slotConfigurations or {}
    for i = 1, #configs do
        local cfg = configs[i]
        if tostring(cfg.configurationId or "") == tostring(configurationId or "") then
            return cfg
        end
        local aliases = cfg.legacyConfigurationIds or {}
        for aliasIndex = 1, #aliases do
            if tostring(aliases[aliasIndex] or "") == tostring(configurationId or "") then
                return cfg
            end
        end
    end
    return nil
end

local function _weaponAllowed(definition, slotType, weaponType)
    local pools = definition.slotWeaponPools or {}
    local pool = pools[slotType] or {}
    for i = 1, #pool do
        if tostring(pool[i]) == tostring(weaponType) then
            local weapon = (weaponData or {})[tostring(weaponType)]
            if weapon == nil then return false end
            local allowedSlots = weapon.slotTypes or {}
            for slotIndex = 1, #allowedSlots do
                if tostring(allowedSlots[slotIndex]) == tostring(slotType) then
                    return weaponBehaviorProfiles ~= nil
                        and weaponBehaviorProfiles[tostring(weapon.behaviorType or "")] == true
                end
            end
            return false
        end
    end
    return false
end

local function _buildResolvedLoadout(definition, configuration, requestedLoadout)
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
            if not _weaponAllowed(definition, slotType, candidate) then
                return nil, "weapon " .. tostring(candidate) .. " is not allowed for slot group " .. slotType
            end
            result[slotType] = tostring(candidate)
        end
    end
    
    return result, nil
end

local function _validateConfigurationShape(configuration)
    local groups = configuration.slotGroups or {}
    local mounts = configuration.mounts or {}
    
    for i = 1, #groups do
        local group = groups[i] or {}
        local slotType = tostring(group.slotType or "")
        local count = tonumber(group.count) or 0
        local collectionName = tostring(group.mountCollection or "")
        
        if slotType ~= "" and collectionName ~= "" and count > 0 then
            local collection = mounts[collectionName] or {}
            if #collection < count then
                return false, "mount collection " .. collectionName .. " has " .. tostring(#collection) .. " mounts, expected " .. tostring(count)
            end
        end
    end
    
    return true, nil
end

local function _templateKey(shipType, field)
    return _templateRegistryRoot .. "/" .. tostring(shipType or "enigmaticCruiser") .. "/" .. tostring(field or "")
end

local function _readSpawnTemplate(shipType, definition)
    local configurationId = GetString(_templateKey(shipType, "configurationId"))
    if configurationId == nil or configurationId == "" then return nil end
    local configuration = _findConfiguration(definition, configurationId)
    if configuration == nil then return nil end
    local requested = {}
    for _, slotType in ipairs({ "X", "L", "M", "G", "H" }) do
        requested[slotType] = GetString(_templateKey(shipType, slotType))
    end
    local loadout = _buildResolvedLoadout(definition, configuration, requested)
    if loadout == nil then return nil end
    return {
        configurationId = tostring(configuration.configurationId or configurationId),
        loadout = loadout,
    }
end

local function _configurationGroup(configuration, slotType)
    for _, group in ipairs(configuration.slotGroups or {}) do
        if tostring(group.slotType or "") == tostring(slotType or "") then
            return group
        end
    end
    return nil
end

local function _resolvedMountsForWeapon(definition, configuration, slotType, weaponType)
    local group = _configurationGroup(configuration, slotType)
    if group == nil then return {} end

    local count = math.max(0, math.floor(tonumber(group.count) or 0))
    local collectionName = tostring(group.mountCollection or "")
    local fallback = ((configuration.mounts or {})[collectionName]) or {}
    local weaponDefinition = (weaponData or {})[tostring(weaponType or "")] or {}
    local profileName = tostring(weaponDefinition.mountProfile or "")
    local profile = ((definition.weaponMountProfiles or {})[profileName]) or fallback
    local mounts = {}
    for i = 1, math.min(count, #profile) do
        mounts[i] = _cloneTable(profile[i])
    end
    return mounts
end

local function _rebuildResolvedDefinition(shipType)
    local state = _stateByType[shipType]
    if state == nil then
        return nil
    end
    
    local definition = _resolveShipDefinition(shipType)
    local configuration = _findConfiguration(definition, state.configurationId)
    if configuration == nil then
        return nil
    end
    
    local resolved = _cloneTable(definition)
    local loadout = state.loadout or {}
    resolved.xSlots = _resolvedMountsForWeapon(definition, configuration, "X", loadout.X)
    resolved.lSlots = _resolvedMountsForWeapon(definition, configuration, "L", loadout.L)
    resolved.mSlots = _resolvedMountsForWeapon(definition, configuration, "M", loadout.M)
    resolved.gSlots = _resolvedMountsForWeapon(definition, configuration, "G", loadout.G)
    resolved.hSlots = _resolvedMountsForWeapon(definition, configuration, "H", loadout.H)
    
    for i = 1, #resolved.xSlots do
        resolved.xSlots[i].weaponType = loadout.X or resolved.xSlots[i].weaponType
    end
    for i = 1, #resolved.lSlots do
        resolved.lSlots[i].weaponType = loadout.L or resolved.lSlots[i].weaponType
    end
    for i = 1, #resolved.mSlots do
        resolved.mSlots[i].weaponType = loadout.M or resolved.mSlots[i].weaponType
    end
    for i = 1, #resolved.gSlots do
        resolved.gSlots[i].weaponType = loadout.G or resolved.gSlots[i].weaponType
    end
    for i = 1, #resolved.hSlots do
        resolved.hSlots[i].weaponType = loadout.H or resolved.hSlots[i].weaponType
    end
    
    _resolvedDefinitionByType[shipType] = resolved
    return resolved
end

local function _initInternal(shipType)
    local definition = _resolveShipDefinition(shipType)
    
    if definition.shipType == nil then
        return false, "ship type not found: " .. tostring(shipType)
    end
    
    local template = _readSpawnTemplate(shipType, definition)
    local defaultConfigId = template and template.configurationId or definition.defaultSlotConfigurationId
    local configuration = _findConfiguration(definition, defaultConfigId)
    
    if configuration == nil then
        local configs = definition.slotConfigurations or {}
        for i = 1, #configs do
            if configuration == nil then
                configuration = configs[i]
            end
        end
    end
    
    if configuration == nil then
        return false, "no slot configuration found"
    end
    
    local shapeOk, shapeError = _validateConfigurationShape(configuration)
    if not shapeOk then
        return false, shapeError
    end
    
    local requestedLoadout = template and template.loadout or configuration.defaultLoadout or {}
    local loadout, loadoutError = _buildResolvedLoadout(definition, configuration, requestedLoadout)
    if loadout == nil then
        return false, loadoutError
    end
    
    _stateByType[shipType] = {
        shipType = shipType,
        configurationId = defaultConfigId,
        loadout = loadout,
    }
    
    _rebuildResolvedDefinition(shipType)
    return true, nil
end

local function _ensureInitialized(shipType)
    if _stateByType[shipType] ~= nil then
        return true
    end
    local ok = _initInternal(shipType)
    return ok
end

-- ============ API函数（内部使用，通过API文件暴露） ============

local _loadoutAPI = {}

function _loadoutAPI.getState(shipType)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    if not _ensureInitialized(resolvedType) then
        return nil
    end
    
    local state = _stateByType[resolvedType]
    if state == nil then
        return nil
    end
    
    return {
        shipType = state.shipType,
        configurationId = state.configurationId,
        loadout = _cloneTable(state.loadout),
    }
end

function _loadoutAPI.setConfiguration(shipType, configurationId)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    if not _ensureInitialized(resolvedType) then
        return false, "state init failed"
    end
    
    local definition = _resolveShipDefinition(resolvedType)
    local configuration = _findConfiguration(definition, configurationId)
    if configuration == nil then
        return false, "configuration not found"
    end
    
    local shapeOk, shapeError = _validateConfigurationShape(configuration)
    if not shapeOk then
        return false, shapeError
    end
    
    local previous = _stateByType[resolvedType] or {}
    local requestedLoadout = _cloneTable(previous.loadout or {})
    
    local loadout, loadoutError = _buildResolvedLoadout(definition, configuration, requestedLoadout)
    if loadout == nil then
        return false, loadoutError
    end
    
    _stateByType[resolvedType] = {
        shipType = resolvedType,
        configurationId = tostring(configuration.configurationId or configurationId),
        loadout = loadout,
    }
    
    _rebuildResolvedDefinition(resolvedType)
    return true, nil
end

function _loadoutAPI.setLoadout(shipType, requestedLoadout)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    if not _ensureInitialized(resolvedType) then
        return false, "state init failed"
    end
    
    local state = _stateByType[resolvedType] or {}
    local definition = _resolveShipDefinition(resolvedType)
    local configuration = _findConfiguration(definition, state.configurationId)
    if configuration == nil then
        return false, "configuration not found"
    end
    
    local merged = _cloneTable(state.loadout or {})
    local incoming = requestedLoadout or {}
    for slotType, weaponType in pairs(incoming) do
        merged[tostring(slotType)] = tostring(weaponType)
    end
    
    local loadout, loadoutError = _buildResolvedLoadout(definition, configuration, merged)
    if loadout == nil then
        return false, loadoutError
    end
    
    state.loadout = loadout
    _stateByType[resolvedType] = state
    
    _rebuildResolvedDefinition(resolvedType)
    return true, nil
end

function _loadoutAPI.resolveShipDefinition(shipType)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    if not _ensureInitialized(resolvedType) then
        return nil
    end
    
    local resolved = _resolvedDefinitionByType[resolvedType]
    if resolved == nil then
        resolved = _rebuildResolvedDefinition(resolvedType)
    end
    
    if resolved == nil then
        return nil
    end
    return resolved
end

function _loadoutAPI.getSpawnTemplate(shipType)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    local definition = _resolveShipDefinition(resolvedType)
    local template = _readSpawnTemplate(resolvedType, definition)
    if template ~= nil then return _cloneTable(template) end

    local configuration = _findConfiguration(definition, definition.defaultSlotConfigurationId)
    if configuration == nil then return nil end
    local loadout = _buildResolvedLoadout(definition, configuration, configuration.defaultLoadout or {})
    if loadout == nil then return nil end
    return {
        configurationId = tostring(configuration.configurationId or definition.defaultSlotConfigurationId),
        loadout = loadout,
    }
end

function _loadoutAPI.setSpawnTemplate(shipType, configurationId, requestedLoadout)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    local definition = _resolveShipDefinition(resolvedType)
    local configuration = _findConfiguration(definition, configurationId)
    if configuration == nil then return false, "configuration not found" end

    local shapeOk, shapeError = _validateConfigurationShape(configuration)
    if not shapeOk then return false, shapeError end
    local loadout, loadoutError = _buildResolvedLoadout(definition, configuration, requestedLoadout or {})
    if loadout == nil then return false, loadoutError end

    SetString(_templateKey(resolvedType, "configurationId"), tostring(configuration.configurationId or configurationId), true)
    for _, slotType in ipairs({ "X", "L", "M", "G", "H" }) do
        SetString(_templateKey(resolvedType, slotType), tostring(loadout[slotType] or ""), true)
    end
    return true, nil
end

-- 将API导出到server表，供API文件使用
server._slotLoadoutAPI = _loadoutAPI

-- ============ 规范化的模块接口 ============

function server.slotLoadoutInit(shipType)
    local resolvedType = shipType or server.defaultShipType or "enigmaticCruiser"
    local ok, err = _initInternal(resolvedType)
    if not ok then
        DebugPrint("[slotLoadout] init failed: " .. tostring(err or "unknown"))
        return false
    end
    return true
end

function server.slotLoadoutTick(dt)
    -- 槽位装载管理通常不需要每tick执行
    -- 但保留接口以符合规范
end
