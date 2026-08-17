---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local _weaponConfigRegistryRoot = "level.stellarisships.weaponconfig"
local _weaponConfigSlots = { "T", "X", "L", "L2", "M", "G", "H", "P" }

local function _weaponConfigLoadoutKeys(configuration)
    local result = {}
    local seen = {}
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        local key = shipDefinitionGetGroupLoadoutKey(group.groupId, group.slotType)
        if key ~= "" and not seen[key] then
            seen[key] = true
            result[#result + 1] = key
        end
    end
    if #result == 0 then return _weaponConfigSlots end
    return result
end

local function _weaponConfigSafeId(value)
    return string.lower(tostring(value or "")):gsub("[^a-z0-9._-]", "")
end

local function _weaponConfigShipRoot(shipType)
    return _weaponConfigRegistryRoot .. "." .. _weaponConfigSafeId(shipType)
end

local function _weaponConfigAliases(definition)
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

local function _weaponConfigGroups(configuration)
    local groups = {}
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        groups[#groups + 1] = tostring(group.groupId or group.slotType or "")
    end
    return groups
end

local function _weaponConfigFindConfiguration(definition, configurationId)
    for _, configuration in ipairs((definition or {}).slotConfigurations or {}) do
        if tostring(configuration.configurationId or "") == tostring(configurationId or "") then
            return configuration
        end
        for _, alias in ipairs(configuration.legacyConfigurationIds or {}) do
            if tostring(alias or "") == tostring(configurationId or "") then
                return configuration
            end
        end
    end
    return nil
end

local function _weaponConfigWithContract(
    shipType,
    configurationId,
    loadout,
    componentLoadout
)
    local resolvedType = tostring(shipType or "")
    local definition = (shipTypeRegistryData or {})[resolvedType] or {}
    local requestedConfiguration = tostring(configurationId or "")
    local configuration = _weaponConfigFindConfiguration(
        definition,
        requestedConfiguration
    )
    local defaultConfiguration = tostring(
        definition.defaultSlotConfigurationId or ""
    )
    local snapshot, errors, warnings = cm2LoadoutContractV1.migrateV0(
        {
            configuration = requestedConfiguration,
            loadout = loadout or {},
            componentLoadout = componentLoadout or {},
        },
        "cm2:vehicle/" .. resolvedType,
        defaultConfiguration,
        _weaponConfigAliases(definition)
    )
    if snapshot == nil then return nil, errors, warnings end

    local runtime = {
        schemaVersion = snapshot.schemaVersion,
        revision = snapshot.revision,
        mountRevision = snapshot.mountRevision,
        vehicleId = snapshot.vehicleId,
        configurationId = snapshot.configurationId,
        loadout = cm2LoadoutContractV1.toRuntimeLoadout(snapshot.loadout),
        componentLoadout = cm2LoadoutContractV1.toRuntimeComponentLoadout(
            snapshot.componentLoadout
        ),
        contractSnapshot = snapshot,
        migration = snapshot.migration,
    }
    runtime.snapshotHash = cm2LoadoutContractV1.snapshotHash(snapshot)
    if configuration == nil then
        return nil, {
            {
                code = "configuration-not-found",
                fieldPath = "configurationId",
                expected = "compiled configuration ID",
                actual = requestedConfiguration,
                suggestion = "select the compiled default configuration",
            },
        }, warnings
    end
    return runtime, errors, warnings
end

local function _weaponConfigDefault(shipType)
    local definition = (shipTypeRegistryData or {})[tostring(shipType or "")] or {}
    local configurationId = tostring(definition.defaultSlotConfigurationId or "")
    local configuration = _weaponConfigFindConfiguration(definition, configurationId)
    local defaults = (configuration or {}).defaultLoadout or {}
    local loadout = {}
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        local slotType = tostring(group.slotType or "")
        local key = shipDefinitionGetGroupLoadoutKey(group.groupId, slotType)
        loadout[key] = tostring(defaults[tostring(group.groupId or "")]
            or defaults[key] or defaults[slotType] or "")
    end
    local result = _weaponConfigWithContract(
        shipType,
        tostring((configuration or {}).configurationId or configurationId),
        loadout,
        shipComponentDefaultLoadout(definition, configurationId)
    )
    return result or {
        configurationId = tostring((configuration or {}).configurationId or configurationId),
        loadout = loadout,
        componentLoadout = shipComponentDefaultLoadout(definition, configurationId),
    }
end

function client.weaponLocalConfigRead(shipType)
    local resolvedType = tostring(shipType or "")
    local definition = (shipTypeRegistryData or {})[resolvedType] or {}
    local root = _weaponConfigShipRoot(resolvedType)
    if not HasKey(root .. ".configuration") then
        return _weaponConfigDefault(resolvedType)
    end

    local configuration = _weaponConfigFindConfiguration(
        definition,
        GetString(root .. ".configuration")
    )
    if configuration == nil then return _weaponConfigDefault(resolvedType) end
    local loadout = {}
    for _, loadoutKey in ipairs(_weaponConfigLoadoutKeys(configuration)) do
        loadout[loadoutKey] = GetString(
            root .. "." .. string.lower(loadoutKey)
        )
    end
    local componentLoadout = {}
    local defaults = (configuration or {}).defaultComponentLoadout or {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        local slotType = group.slotType
        componentLoadout[slotType] = {}
        for index = 1, group.count do
            local key = root .. "." .. string.lower(slotType) .. "." .. tostring(index)
            if HasKey(key) then
                componentLoadout[slotType][index] = GetString(key)
            else
                componentLoadout[slotType][index] =
                    tostring((defaults[slotType] or {})[index] or "")
            end
        end
    end
    local result = _weaponConfigWithContract(
        resolvedType,
        GetString(root .. ".configuration"),
        loadout,
        componentLoadout
    )
    return result or _weaponConfigDefault(resolvedType)
end

function client.weaponLocalConfigWrite(shipType, configurationId, loadout, componentLoadout)
    local root = _weaponConfigShipRoot(shipType)
    local definition = (shipTypeRegistryData or {})[tostring(shipType or "")] or {}
    local snapshot, errors = _weaponConfigWithContract(
        shipType,
        configurationId,
        loadout,
        componentLoadout
    )
    if snapshot == nil then
        return false, errors
    end
    local selected = snapshot.loadout or {}
    SetString(root .. ".schemaVersion", tostring(snapshot.schemaVersion or ""))
    SetString(root .. ".revision", tostring(snapshot.revision or 1))
    SetString(root .. ".vehicleId", tostring(snapshot.vehicleId or ""))
    SetString(root .. ".configuration", tostring(snapshot.configurationId or ""))
    local configuration = _weaponConfigFindConfiguration(
        definition,
        snapshot.configurationId
    )
    for _, loadoutKey in ipairs(_weaponConfigLoadoutKeys(configuration)) do
        SetString(
            root .. "." .. string.lower(loadoutKey),
            tostring(selected[loadoutKey] or "")
        )
    end
    local selectedComponents = snapshot.componentLoadout or {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        local slotType = group.slotType
        for index = 1, group.count do
            SetString(
                root .. "." .. string.lower(slotType) .. "." .. tostring(index),
                tostring(((selectedComponents[slotType] or {})[index]) or "")
            )
        end
    end
    return true, snapshot
end

function client.weaponLocalConfigUiOpenKey()
    return _weaponConfigRegistryRoot .. ".uiopen"
end

function client.weaponConfigRegistryIsOpen()
    return GetBool(client.weaponLocalConfigUiOpenKey())
end

function client.weaponConfigUiIsOpen()
    return client.weaponConfigRegistryIsOpen()
end
