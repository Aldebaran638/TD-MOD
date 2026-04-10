---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- slot_loadout.lua
-- 飞船槽位装载管理模块 - 符合规范的模块文件
-- 只导出 server.slotLoadoutInit() 和 server.slotLoadoutTick()

server = server or {}

-- 模块内部状态
local _stateByType = {}
local _resolvedDefinitionByType = {}

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
    end
    return nil
end

local function _weaponAllowed(definition, slotType, weaponType)
    local pools = definition.slotWeaponPools or {}
    local pool = pools[slotType] or {}
    for i = 1, #pool do
        if tostring(pool[i]) == tostring(weaponType) then
            return true
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
    resolved.xSlots = _cloneTable((configuration.mounts or {}).xSlots or {})
    resolved.lSlots = _cloneTable((configuration.mounts or {}).lSlots or {})
    resolved.sSlots = _cloneTable((configuration.mounts or {}).sSlots or {})
    resolved.gSlots = _cloneTable((configuration.mounts or {}).gSlots or {})
    resolved.hSlots = _cloneTable((configuration.mounts or {}).hSlots or {})
    
    local loadout = state.loadout or {}
    
    for i = 1, #resolved.xSlots do
        resolved.xSlots[i].weaponType = loadout.X or resolved.xSlots[i].weaponType
    end
    for i = 1, #resolved.lSlots do
        resolved.lSlots[i].weaponType = loadout.L or resolved.lSlots[i].weaponType
    end
    for i = 1, #resolved.sSlots do
        resolved.sSlots[i].weaponType = loadout.M or resolved.sSlots[i].weaponType
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
    
    local defaultConfigId = definition.defaultSlotConfigurationId
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
    
    local loadout, loadoutError = _buildResolvedLoadout(definition, configuration, configuration.defaultLoadout or {})
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
        return _loadoutAPI.resolveShipDefinition(resolvedType)
    end
    
    local resolved = _resolvedDefinitionByType[resolvedType]
    if resolved == nil then
        resolved = _rebuildResolvedDefinition(resolvedType)
    end
    
    if resolved == nil then
        return _loadoutAPI.resolveShipDefinition(resolvedType)
    end
    return resolved
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