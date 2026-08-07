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

-- Slot groups are identified by their groupId.  A numbered group such as
-- lSlot2 uses the same weapon family as lSlot, but resolves to its own mount
-- collection and numbered mount profile.  Keeping this rule here prevents
-- loadout validation and runtime resolution from drifting apart.
function shipDefinitionGetGroupMountCollection(groupId, slotType)
    local requestedGroup = tostring(groupId or "")
    local normalizedGroup = string.lower(requestedGroup)
    local requestedType = string.lower(tostring(slotType or ""))
    local base, index = normalizedGroup:match("^(.-)slot(%d*)$")
    if base ~= nil and base ~= "" and requestedType ~= "" then
        if index == "" then
            return requestedType .. "Slots"
        end
        return requestedType .. "Slot" .. index .. "Slots"
    end
    return string.lower(requestedGroup) .. "Slots"
end

function shipDefinitionGetGroupMountProfileName(groupId, baseProfileName)
    local profileName = tostring(baseProfileName or "")
    if profileName == "" then return "" end

    local normalizedGroup = string.lower(tostring(groupId or ""))
    local _, index = normalizedGroup:match("^(.-)slot(%d*)$")
    if index ~= nil and index ~= "" then
        return profileName .. index
    end
    return profileName
end

-- Configuration snapshots use slot keys (L2), while runtime definitions use
-- group ids (lSlot2). Resolve that translation once at the data boundary.
function shipDefinitionGetGroupLoadoutKey(groupId, slotType)
    local normalizedGroup = string.lower(tostring(groupId or ""))
    local requestedType = string.upper(tostring(slotType or ""))
    local _, index = normalizedGroup:match("^(.-)slot(%d*)$")
    if index ~= nil and index ~= "" then
        return requestedType .. index
    end
    return requestedType
end

-- Slot configuration values are normalized once at the ship-data boundary.
-- Runtime weapon scheduling consumes this canonical integer and does not
-- reinterpret raw configuration values.
function shipDefinitionNormalizeSalvoGroupSize(value, count)
    if value == nil then return nil, nil end

    local numeric = tonumber(value)
    if numeric == nil or numeric ~= numeric then
        return nil, "salvoGroupSize must be numeric"
    end

    local normalized = math.floor(numeric)
    local limit = math.max(0, math.floor(tonumber(count) or 0))
    if normalized < 1 or normalized > limit then
        return nil, "salvoGroupSize must be between 1 and " .. tostring(limit)
    end
    return normalized, nil
end

function shipDefinitionFindSlotGroup(configuration, groupId)
    local requested = tostring(groupId or "")
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        if tostring(group.groupId or "") == requested then return group end
    end
    return nil
end

-- Keep catalog eligibility and physical mount eligibility in one shared rule so
-- the configurator never offers a weapon the runtime cannot construct.
function shipDefinitionWeaponFitsGroup(definition, configuration, group, weaponType)
    local ship = definition or {}
    local slotGroup = group or {}
    local slotType = string.upper(tostring(slotGroup.slotType or ""))
    local typeId = tostring(weaponType or "")
    local weapon = (weaponData or {})[typeId]
    if slotType == "" or typeId == "" or weapon == nil then
        return false, "weapon or slot group is missing"
    end

    local inCatalogPool = false
    for _, candidate in ipairs(weaponCatalogGetSlotPool(slotType)) do
        if tostring(candidate) == typeId then
            inCatalogPool = true
            break
        end
    end
    if not inCatalogPool then return false, "weapon is not available for slot type" end
    if weaponBehaviorProfiles == nil
        or weaponBehaviorProfiles[tostring(weapon.behaviorType or "")] ~= true then
        return false, "weapon behavior is not registered"
    end

    local count = math.max(0, math.floor(tonumber(slotGroup.count) or 0))
    local profileName = shipDefinitionGetGroupMountProfileName(
        slotGroup.groupId,
        weapon.mountProfile
    )
    local profile = ((ship.weaponMountProfiles or {})[profileName]) or {}
    if count <= 0 or profileName == "" or #profile < count then
        return false, "mount profile does not cover slot group"
    end

    local _, salvoError = shipDefinitionNormalizeSalvoGroupSize(
        slotGroup.salvoGroupSize,
        count
    )
    if salvoError ~= nil then return false, salvoError end
    return true, nil
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
    local group = shipDefinitionFindSlotGroup(configuration, requestedGroup)
    if group == nil then return {} end

    local typeId = tostring(weaponType or "")
    if typeId == "" then
        local defaults = (configuration or {}).defaultLoadout or {}
        local loadoutKey = shipDefinitionGetGroupLoadoutKey(
            requestedGroup,
            group.slotType
        )
        typeId = tostring(defaults[requestedGroup]
            or defaults[loadoutKey]
            or defaults[tostring(group.slotType or "")] or "")
    end
    local weapon = (weaponData or {})[typeId] or {}
    local profileName = shipDefinitionGetGroupMountProfileName(
        requestedGroup,
        weapon.mountProfile
    )
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
