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
    return {
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
    return {
        configurationId = GetString(root .. ".configuration"),
        loadout = loadout,
        componentLoadout = componentLoadout,
    }
end

function client.weaponLocalConfigWrite(shipType, configurationId, loadout, componentLoadout)
    local root = _weaponConfigShipRoot(shipType)
    local selected = loadout or {}
    SetString(root .. ".configuration", tostring(configurationId or ""))
    local definition = (shipTypeRegistryData or {})[tostring(shipType or "")] or {}
    local configuration = _weaponConfigFindConfiguration(definition, configurationId)
    for _, loadoutKey in ipairs(_weaponConfigLoadoutKeys(configuration)) do
        SetString(
            root .. "." .. string.lower(loadoutKey),
            tostring(selected[loadoutKey] or "")
        )
    end
    local selectedComponents = componentLoadout or {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        local slotType = group.slotType
        for index = 1, group.count do
            SetString(
                root .. "." .. string.lower(slotType) .. "." .. tostring(index),
                tostring(((selectedComponents[slotType] or {})[index]) or "")
            )
        end
    end
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
