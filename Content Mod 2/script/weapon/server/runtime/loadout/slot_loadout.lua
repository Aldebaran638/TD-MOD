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

local function _contractAliases(definition)
    local aliases = {}
    for _, configuration in ipairs((definition or {}).slotConfigurations or {}) do
        local canonical = tostring(configuration.configurationId or "")
        for _, alias in ipairs(configuration.legacyConfigurationIds or {}) do
            if canonical ~= "" and tostring(alias or "") ~= "" then
                aliases[tostring(alias)] = canonical
            end
        end
    end
    return aliases
end

local function _contractGroups(configuration)
    local groups = {}
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        groups[#groups + 1] = tostring(group.groupId or group.slotType or "")
    end
    return groups
end

local function _contractErrorText(errors)
    local first = (errors or {})[1]
    if type(first) ~= "table" then return tostring(first or "loadout contract rejected") end
    return tostring(first.code or "invalid") .. " at "
        .. tostring(first.fieldPath or "snapshot") .. ": "
        .. tostring(first.suggestion or first.actual or "invalid value")
end

local function _contractSnapshotFor(
    definition,
    configurationId,
    requestedLoadout,
    requestedComponentLoadout
)
    local requested = requestedLoadout or {}
    local configuration = _findConfiguration(definition, configurationId)
    if configuration == nil then
        configuration = _findConfiguration(
            definition,
            tostring((definition or {}).defaultSlotConfigurationId or "")
        )
    end
    local snapshot, errors, warnings = cm2LoadoutContractV1.migrateV0(
        {
            configuration = configurationId,
            loadout = requested,
            groups = _contractGroups(configuration),
            componentLoadout = requestedComponentLoadout or {},
        },
        "cm2:vehicle/" .. tostring((definition or {}).shipType or ""),
        tostring((definition or {}).defaultSlotConfigurationId or ""),
        _contractAliases(definition)
    )
    if snapshot == nil then return nil, _contractErrorText(errors), warnings end
    return snapshot, nil, warnings
end

local function _recordContractSnapshot(snapshot, source)
    if snapshot == nil then return end
    local hash = cm2LoadoutContractV1.snapshotHash(snapshot)
    local vehicleId = tostring(snapshot.vehicleId or "")
    local shipType = string.match(vehicleId, "^cm2:vehicle/(.+)$") or ""
    local encoded = cm2LoadoutContractV1.encode(snapshot)
    if shipType ~= "" and SetString ~= nil then
        local root = "StellarisShips/loadoutContract/v1/" .. shipType
        SetString(root .. "/schemaVersion", tostring(snapshot.schemaVersion or ""), true)
        SetInt(root .. "/revision", tonumber(snapshot.revision) or 0, true)
        SetString(root .. "/vehicleId", vehicleId, true)
        SetString(root .. "/configurationId", tostring(snapshot.configurationId or ""), true)
        SetString(root .. "/snapshotHash", tostring(hash or ""), true)
        SetString(root .. "/encoded", tostring(encoded or ""), true)
        SetString(root .. "/source", tostring(source or "runtime"), true)
    end
    if type(server.cm2TelemetryRecord) == "function" then
        server.cm2TelemetryRecord("loadout_configuration_v1", {
            source = tostring(source or "runtime"),
            schemaVersion = tostring(snapshot.schemaVersion or ""),
            revision = tonumber(snapshot.revision) or 0,
            vehicleId = vehicleId,
            configurationId = tostring(snapshot.configurationId or ""),
            snapshotHash = tostring(hash or ""),
            migration = snapshot.migration,
        })
    end
end

local function _weaponAllowed(definition, configuration, group, weaponType)
    return shipDefinitionWeaponFitsGroup(
        definition,
        configuration,
        group,
        weaponType
    )
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
            local loadoutKey = shipDefinitionGetGroupLoadoutKey(groupId, slotType)
            local candidate = requestedLoadout and requestedLoadout[groupId] or nil
            if candidate == nil or candidate == "" then
                candidate = requestedLoadout and requestedLoadout[loadoutKey] or nil
            end
            if candidate == nil or candidate == "" then
                candidate = requestedLoadout and requestedLoadout[slotType] or nil
            end
            if candidate == nil or candidate == "" then
                candidate = defaults[groupId] or defaults[loadoutKey]
                    or defaults[slotType]
            end
            if candidate == nil or candidate == "" then
                return nil, "missing weapon for slot group " .. slotType
            end
            if not _weaponAllowed(definition, configuration, group, candidate) then
                return nil, "weapon " .. tostring(candidate) .. " is not allowed for slot group " .. slotType
            end
            result[groupId] = tostring(candidate)
            result[loadoutKey] = tostring(candidate)
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
        local loadoutKey = shipDefinitionGetGroupLoadoutKey(groupId, slotType)
        local weaponType = tostring((loadout or {})[groupId]
            or (loadout or {})[loadoutKey]
            or (loadout or {})[slotType] or "")
        if slotType == "" or count <= 0 then
            return false, "invalid slot group"
        end
        if tostring(group.groupId or "") == "" then
            return false, "slot group " .. slotType .. " is missing groupId"
        end
        local fits, reason = shipDefinitionWeaponFitsGroup(
            definition,
            configuration,
            group,
            weaponType
        )
        if not fits then
            return false, "slot group " .. groupId .. ": " .. tostring(reason)
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
            loadout[groupId]
                or loadout[shipDefinitionGetGroupLoadoutKey(groupId, slotType)]
                or loadout[slotType]
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
    local contractSnapshot, contractError = _contractSnapshotFor(
        definition,
        configuration.configurationId,
        requestedLoadout
    )
    if contractSnapshot == nil then return false, contractError end
    local loadout, loadoutError = _buildResolvedLoadout(
        definition,
        configuration,
        cm2LoadoutContractV1.toRuntimeLoadout(contractSnapshot.loadout)
    )
    if loadout == nil then
        return false, loadoutError
    end
    local shapeOk, shapeError = _validateConfigurationShape(definition, configuration, loadout)
    if not shapeOk then
        return false, shapeError
    end
    
    _stateByType[shipType] = {
        shipType = shipType,
        configurationId = contractSnapshot.configurationId,
        loadout = loadout,
        contractSnapshot = contractSnapshot,
        snapshotHash = cm2LoadoutContractV1.snapshotHash(contractSnapshot),
    }

    _rebuildResolvedDefinition(shipType)
    _recordContractSnapshot(contractSnapshot, "init")
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
        schemaVersion = cm2LoadoutContractV1.schemaVersion,
        revision = cm2LoadoutContractV1.currentRevision,
        vehicleId = "cm2:vehicle/" .. tostring(state.shipType or ""),
        contractSnapshot = _cloneTable(state.contractSnapshot),
        snapshotHash = tostring(state.snapshotHash or ""),
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
    local contractSnapshot, contractError = _contractSnapshotFor(
        definition,
        configuration.configurationId,
        requestedLoadout
    )
    if contractSnapshot == nil then return false, contractError end
    
    local loadout, loadoutError = _buildResolvedLoadout(
        definition,
        configuration,
        cm2LoadoutContractV1.toRuntimeLoadout(contractSnapshot.loadout)
    )
    if loadout == nil then
        return false, loadoutError
    end
    local shapeOk, shapeError = _validateConfigurationShape(definition, configuration, loadout)
    if not shapeOk then
        return false, shapeError
    end
    
    _stateByType[resolvedType] = {
        shipType = resolvedType,
        configurationId = tostring(contractSnapshot.configurationId),
        loadout = loadout,
        contractSnapshot = contractSnapshot,
        snapshotHash = cm2LoadoutContractV1.snapshotHash(contractSnapshot),
    }

    _rebuildResolvedDefinition(resolvedType)
    _recordContractSnapshot(contractSnapshot, "set_configuration")
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

    -- Keep the slot-type, group-id, and numbered-slot aliases coherent. The
    -- resolver intentionally prefers the group id, so updating only M would
    -- otherwise leave a stale mSlot value in front of the requested weapon.
    for _, group in ipairs(configuration.slotGroups or {}) do
        local groupId = tostring(group.groupId or "")
        local slotType = tostring(group.slotType or "")
        local loadoutKey = shipDefinitionGetGroupLoadoutKey(groupId, slotType)
        local requested = incoming[groupId]
            or incoming[loadoutKey]
            or incoming[slotType]
        if requested ~= nil then
            local value = tostring(requested)
            merged[groupId] = value
            merged[loadoutKey] = value
            merged[slotType] = value
        end
    end
    
    local contractSnapshot, contractError = _contractSnapshotFor(
        definition,
        configuration.configurationId,
        merged
    )
    if contractSnapshot == nil then return false, contractError end
    local loadout, loadoutError = _buildResolvedLoadout(
        definition,
        configuration,
        cm2LoadoutContractV1.toRuntimeLoadout(contractSnapshot.loadout)
    )
    if loadout == nil then
        return false, loadoutError
    end
    
    state.loadout = loadout
    state.configurationId = tostring(contractSnapshot.configurationId)
    state.contractSnapshot = contractSnapshot
    state.snapshotHash = cm2LoadoutContractV1.snapshotHash(contractSnapshot)
    _stateByType[resolvedType] = state

    _rebuildResolvedDefinition(resolvedType)
    _recordContractSnapshot(contractSnapshot, "set_loadout")
    return true, nil
end

function _loadoutAPI.validateSnapshot(
    shipType,
    configurationId,
    requestedLoadout,
    requestedComponentLoadout
)
    local resolvedType = shipType or server.shipContextGetType()
    local definition = _resolveShipDefinition(resolvedType)
    if definition.shipType == nil then
        return nil, "ship type not found: " .. tostring(resolvedType)
    end
    local contractSnapshot, contractError = _contractSnapshotFor(
        definition,
        configurationId,
        requestedLoadout or {},
        requestedComponentLoadout or {}
    )
    if contractSnapshot == nil then return nil, contractError end
    local configuration = _findConfiguration(
        definition,
        contractSnapshot.configurationId
    )
    if configuration == nil then return nil, "configuration not found" end
    local loadout, loadoutError = _buildResolvedLoadout(
        definition,
        configuration,
        cm2LoadoutContractV1.toRuntimeLoadout(contractSnapshot.loadout)
    )
    if loadout == nil then return nil, loadoutError end
    local shapeOk, shapeError =
        _validateConfigurationShape(definition, configuration, loadout)
    if not shapeOk then return nil, shapeError end
    return {
        shipType = resolvedType,
        configurationId =
            tostring(contractSnapshot.configurationId),
        loadout = loadout,
        contractSnapshot = contractSnapshot,
        snapshotHash = cm2LoadoutContractV1.snapshotHash(contractSnapshot),
    }, nil
end

function _loadoutAPI.applySnapshot(snapshot)
    local resolved = snapshot or {}
    local shipType = tostring(resolved.shipType or server.shipContextGetType())
    local validated, validationError = _loadoutAPI.validateSnapshot(
        shipType,
        resolved.configurationId,
        resolved.loadout or {},
        resolved.componentLoadout or {}
    )
    if validated == nil then
        DebugPrint("[slotLoadout] snapshot rejected: " .. tostring(validationError))
        return false
    end
    _stateByType[shipType] = {
        shipType = shipType,
        configurationId = validated.configurationId,
        loadout = _cloneTable(validated.loadout or {}),
        contractSnapshot = _cloneTable(validated.contractSnapshot),
        snapshotHash = tostring(validated.snapshotHash or ""),
    }
    local rebuilt = _rebuildResolvedDefinition(shipType) ~= nil
    if rebuilt then
        _recordContractSnapshot(validated.contractSnapshot, "apply_snapshot")
    end
    return rebuilt
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
