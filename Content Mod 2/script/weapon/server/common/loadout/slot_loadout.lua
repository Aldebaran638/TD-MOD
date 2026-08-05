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
    local requested = shipType or server.shipContextGetType()
    return shipDefinitionGet(requested, server.shipContextGetType())
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
            local groupId = tostring(group.groupId or "")
            local candidate = requestedLoadout and requestedLoadout[groupId] or nil
            if candidate == nil or candidate == "" then
                candidate = requestedLoadout and requestedLoadout[slotType] or nil
            end
            if candidate == nil or candidate == "" then
                candidate = defaults[groupId] or defaults[slotType]
            end
            if candidate == nil or candidate == "" then
                return nil, "missing weapon for slot group " .. slotType
            end
            if not _weaponAllowed(definition, slotType, candidate) then
                return nil, "weapon " .. tostring(candidate) .. " is not allowed for slot group " .. slotType
            end
            result[groupId] = tostring(candidate)
            if result[slotType] == nil then result[slotType] = tostring(candidate) end
        end
    end
    
    return result, nil
end

local function _validateConfigurationShape(definition, configuration, loadout)
    local groups = configuration.slotGroups or {}
    for i = 1, #groups do
        local group = groups[i] or {}
        local slotType = tostring(group.slotType or "")
        local count = math.max(0, math.floor(tonumber(group.count) or 0))
        local groupId = tostring(group.groupId or "")
        local weaponType = tostring((loadout or {})[groupId]
            or (loadout or {})[slotType] or "")
        local weaponDefinition = (weaponData or {})[weaponType] or {}
        local profileName = shipDefinitionGetGroupMountProfileName(
            groupId,
            weaponDefinition.mountProfile
        )
        local profile = ((definition.weaponMountProfiles or {})[profileName]) or {}
        if slotType == "" or count <= 0 then
            return false, "invalid slot group"
        end
        if tostring(group.groupId or "") == "" then
            return false, "slot group " .. slotType .. " is missing groupId"
        end
        local _, salvoError = shipDefinitionNormalizeSalvoGroupSize(
            group.salvoGroupSize,
            count
        )
        if salvoError ~= nil then
            return false, "slot group " .. groupId .. ": " .. salvoError
        end
        if profileName == "" or #profile < count then
            return false, "mount profile " .. profileName .. " has "
                .. tostring(#profile) .. " mounts, expected " .. tostring(count)
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
    
    local resolved = {}
    for key, value in pairs(definition) do
        resolved[key] = value
    end
    local loadout = state.loadout or {}
    resolved.weaponGroups = {}
    for _, group in ipairs(configuration.slotGroups or {}) do
        local slotType = tostring(group.slotType or "")
        local groupId = tostring(group.groupId or "")
        local collectionName = shipDefinitionGetGroupMountCollection(
            groupId,
            slotType
        )
        local count = math.max(0, math.floor(tonumber(group.count) or 0))
        local salvoGroupSize, salvoError =
            shipDefinitionNormalizeSalvoGroupSize(group.salvoGroupSize, count)
        if salvoError ~= nil then
            DebugPrint("[slotLoadout] " .. groupId .. ": " .. salvoError)
            return nil
        end
        resolved.weaponGroups[#resolved.weaponGroups + 1] = {
            groupId = tostring(group.groupId or ""),
            slotType = slotType,
            count = count,
            mountCollection = collectionName,
            automatic = group.automatic and true or false,
            salvoGroupSize = salvoGroupSize,
        }
        local mounts = shipDefinitionResolveMounts(
            shipType,
            configuration.configurationId,
            group.groupId,
            loadout[groupId] or loadout[slotType]
        )
        resolved[collectionName] = mounts
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
    
    local requestedLoadout = configuration.defaultLoadout or {}
    local loadout, loadoutError = _buildResolvedLoadout(definition, configuration, requestedLoadout)
    if loadout == nil then
        return false, loadoutError
    end
    local shapeOk, shapeError = _validateConfigurationShape(definition, configuration, loadout)
    if not shapeOk then
        return false, shapeError
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
    local resolvedType = shipType or server.shipContextGetType()
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
    local resolvedType = shipType or server.shipContextGetType()
    if not _ensureInitialized(resolvedType) then
        return false, "state init failed"
    end
    
    local definition = _resolveShipDefinition(resolvedType)
    local configuration = _findConfiguration(definition, configurationId)
    if configuration == nil then
        return false, "configuration not found"
    end
    
    local previous = _stateByType[resolvedType] or {}
    local requestedLoadout = _cloneTable(previous.loadout or {})
    
    local loadout, loadoutError = _buildResolvedLoadout(definition, configuration, requestedLoadout)
    if loadout == nil then
        return false, loadoutError
    end
    local shapeOk, shapeError = _validateConfigurationShape(definition, configuration, loadout)
    if not shapeOk then
        return false, shapeError
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
    local resolvedType = shipType or server.shipContextGetType()
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

function _loadoutAPI.validateSnapshot(shipType, configurationId, requestedLoadout)
    local resolvedType = shipType or server.shipContextGetType()
    local definition = _resolveShipDefinition(resolvedType)
    if definition.shipType == nil then
        return nil, "ship type not found: " .. tostring(resolvedType)
    end
    local configuration = _findConfiguration(definition, configurationId)
    if configuration == nil then return nil, "configuration not found" end
    local loadout, loadoutError =
        _buildResolvedLoadout(definition, configuration, requestedLoadout or {})
    if loadout == nil then return nil, loadoutError end
    local shapeOk, shapeError =
        _validateConfigurationShape(definition, configuration, loadout)
    if not shapeOk then return nil, shapeError end
    return {
        shipType = resolvedType,
        configurationId =
            tostring(configuration.configurationId or configurationId or ""),
        loadout = loadout,
    }, nil
end

function _loadoutAPI.applySnapshot(snapshot)
    local resolved = snapshot or {}
    local shipType = tostring(resolved.shipType or server.shipContextGetType())
    local validated, validationError = _loadoutAPI.validateSnapshot(
        shipType,
        resolved.configurationId,
        resolved.loadout or {}
    )
    if validated == nil then
        DebugPrint("[slotLoadout] snapshot rejected: " .. tostring(validationError))
        return false
    end
    _stateByType[shipType] = {
        shipType = shipType,
        configurationId = validated.configurationId,
        loadout = _cloneTable(validated.loadout or {}),
    }
    return _rebuildResolvedDefinition(shipType) ~= nil
end

function _loadoutAPI.resolveShipDefinition(shipType)
    local resolvedType = shipType or server.shipContextGetType()
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

-- 将API导出到server表，供API文件使用
server._slotLoadoutAPI = _loadoutAPI

-- ============ 规范化的模块接口 ============

function server.slotLoadoutInit(shipType)
    local resolvedType = shipType or server.shipContextGetType()
    local ok, err = _initInternal(resolvedType)
    if not ok then
        DebugPrint("[slotLoadout] init failed: " .. tostring(err or "unknown"))
        return false
    end
    server.weaponLocalConfigurationBound = false
    server.weaponLocalConfigurationPlayerId = nil
    return true
end

function server.slotLoadoutTick(dt)
    -- 槽位装载管理通常不需要每tick执行
    -- 但保留接口以符合规范
end
