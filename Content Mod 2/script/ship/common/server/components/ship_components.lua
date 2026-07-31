---@diagnostic disable: undefined-global

server = server or {}

local function _copyAndValidateGroup(definition, group, requested)
    local slotType = tostring((group or {}).slotType or "")
    local count = math.max(0, math.floor(tonumber((group or {}).count) or 0))
    for index, _ in pairs(requested or {}) do
        if type(index) ~= "number"
            or index ~= math.floor(index)
            or index < 1
            or index > count then
            return nil, "unexpected " .. slotType .. " component index"
        end
    end
    local result = {}
    for index = 1, count do
        local componentId = tostring((requested or {})[index] or "")
        if not shipComponentAllowed(definition, slotType, componentId) then
            return nil, "invalid " .. slotType .. " component at " .. tostring(index)
        end
        result[index] = componentId
    end
    return result, nil
end

function server.shipComponentPrepareLoadout(
    shipType,
    configurationId,
    requested,
    weaponLoadout
)
    local definition = shipDefinitionGet(shipType, server.shipContextGetType())
    local configuration =
        shipComponentFindConfiguration(definition, configurationId)
    if configuration == nil then return nil, nil, "configuration not found" end

    local result = {}
    local knownTypes = {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        if knownTypes[group.slotType] then
            return nil, nil, "duplicate component slot group"
        end
        knownTypes[group.slotType] = true
        local resolved, err = _copyAndValidateGroup(
            definition,
            group,
            (requested or {})[group.slotType]
        )
        if resolved == nil then return nil, nil, err end
        result[group.slotType] = resolved
    end
    for slotType, _ in pairs(requested or {}) do
        if not knownTypes[tostring(slotType or "")] then
            return nil, nil, "unexpected component slot group"
        end
    end

    local profile = shipComponentResolveProfile(
        definition,
        result,
        configuration,
        weaponLoadout
    )
    if (definition or {}).requiresPositivePower ~= false
        and not ((profile.energy or {}).valid) then
        return nil, nil, "ship design requires positive power balance"
    end
    return result, profile, nil
end

function server.shipComponentApplyPrepared(loadout, profile, restoreFull)
    local body = server.shipContextGetBody()
    if body == 0 or not server.registryShipExists(body) then
        return false, "ship body is not registered"
    end
    server.shipRuntimeSetComponentProfile(body, profile)
    server.registryShipSetProtectionProfile(
        body,
        (profile or {}).protection,
        restoreFull and true or false
    )
    server.shipComponentLoadout = loadout or {}
    server.shipComponentProfile = profile or {}
    return true, nil
end

function server.shipComponentApplyLoadout(
    shipType,
    configurationId,
    requested,
    restoreFull
)
    local loadout, profile, err = server.shipComponentPrepareLoadout(
        shipType,
        configurationId,
        requested,
        nil
    )
    if loadout == nil then return false, err end
    return server.shipComponentApplyPrepared(loadout, profile, restoreFull)
end

function server.shipComponentApplyDefault(shipType)
    local definition = shipDefinitionGet(shipType, server.shipContextGetType())
    local loadout, configuration = shipComponentDefaultLoadout(definition)
    return server.shipComponentApplyLoadout(
        tostring(definition.shipType or shipType or ""),
        tostring(configuration.configurationId or ""),
        loadout,
        true
    )
end
