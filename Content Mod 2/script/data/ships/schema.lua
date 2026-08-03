---@diagnostic disable: undefined-global

shipTypeRegistryData = shipTypeRegistryData or {}

function shipDefinitionRegister(definition)
    local shipType = tostring((definition or {}).shipType or "")
    if shipType == "" then error("ship definition is missing shipType") end
    if shipTypeRegistryData[shipType] ~= nil then
        error("duplicate ship definition " .. shipType)
    end
    shipTypeRegistryData[shipType] = definition
    return definition
end

function shipDefinitionGet(shipType, fallbackType)
    local requested = tostring(shipType or "")
    local fallback = tostring(fallbackType or "")
    return shipTypeRegistryData[requested]
        or shipTypeRegistryData[fallback]
        or {}
end

function shipDefinitionFindConfiguration(definition, configurationId)
    local requested = tostring(configurationId or "")
    local fallback = nil
    for _, configuration in ipairs((definition or {}).slotConfigurations or {}) do
        fallback = fallback or configuration
        if tostring(configuration.configurationId or "") == requested then
            return configuration
        end
        for _, alias in ipairs(configuration.legacyConfigurationIds or {}) do
            if tostring(alias or "") == requested then return configuration end
        end
    end
    return fallback
end

function shipDefinitionResolveMounts(
    shipType,
    configurationId,
    groupId,
    weaponType
)
    local definition = shipDefinitionGet(shipType, shipType)
    local configuration = shipDefinitionFindConfiguration(
        definition,
        configurationId or definition.defaultSlotConfigurationId
    )
    local requestedGroup = tostring(groupId or "")
    local group = nil
    for _, candidate in ipairs((configuration or {}).slotGroups or {}) do
        if tostring(candidate.groupId or "") == requestedGroup then
            group = candidate
            break
        end
    end
    if group == nil then return {} end

    local typeId = tostring(weaponType or "")
    if typeId == "" then
        local defaults = (configuration or {}).defaultLoadout or {}
        typeId = tostring(defaults[requestedGroup]
            or defaults[tostring(group.slotType or "")] or "")
    end
    local weapon = (weaponData or {})[typeId] or {}
    local profileName = tostring(weapon.mountProfile or "")
    if requestedGroup == "lSlot2" and profileName ~= "" then
        profileName = profileName .. "2"
    end
    local profile = ((definition.weaponMountProfiles or {})[profileName]) or {}
    local count = math.max(0, math.floor(tonumber(group.count) or 0))
    local mounts = {}
    for i = 1, math.min(count, #profile) do
        local source = profile[i] or {}
        local mount = {}
        for key, value in pairs(source) do mount[key] = value end
        mount.weaponType = typeId
        mounts[i] = mount
    end
    return mounts
end
