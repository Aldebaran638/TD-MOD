---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local _weaponConfigRegistryRoot = "level.stellarisships.weaponconfig"
local _weaponConfigSlots = { "X", "L", "M", "G", "H" }

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
    for _, slotType in ipairs(_weaponConfigSlots) do
        loadout[slotType] = tostring(defaults[slotType] or "")
    end
    return {
        configurationId = tostring((configuration or {}).configurationId or configurationId),
        loadout = loadout,
    }
end

function client.weaponLocalConfigRead(shipType)
    local resolvedType = tostring(shipType or "")
    local root = _weaponConfigShipRoot(resolvedType)
    if not HasKey(root .. ".configuration") then
        return _weaponConfigDefault(resolvedType)
    end

    local loadout = {}
    for _, slotType in ipairs(_weaponConfigSlots) do
        loadout[slotType] = GetString(root .. "." .. string.lower(slotType))
    end
    return {
        configurationId = GetString(root .. ".configuration"),
        loadout = loadout,
    }
end

function client.weaponLocalConfigWrite(shipType, configurationId, loadout)
    local root = _weaponConfigShipRoot(shipType)
    local selected = loadout or {}
    SetString(root .. ".configuration", tostring(configurationId or ""))
    for _, slotType in ipairs(_weaponConfigSlots) do
        SetString(root .. "." .. string.lower(slotType), tostring(selected[slotType] or ""))
    end
end

function client.weaponLocalConfigUiOpenKey()
    return _weaponConfigRegistryRoot .. ".uiopen"
end

function client.weaponConfigUiIsOpen()
    return GetBool(client.weaponLocalConfigUiOpenKey())
end
