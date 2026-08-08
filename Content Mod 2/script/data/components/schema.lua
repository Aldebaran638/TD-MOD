---@diagnostic disable: undefined-global

shipComponentData = shipComponentData or {}

local _componentSlotTypes = {
    largeUtility = true,
    auxiliary = true,
    reactor = true,
    thruster = true,
    sensor = true,
}

local function _number(value)
    return tonumber(value) or 0.0
end

local function _hasAnyPositive(definition, fields)
    for _, field in ipairs(fields) do
        if _number(definition[field]) > 0.0 then return true end
    end
    return false
end

function shipComponentDefine(definition)
    definition = definition or {}
    local componentId = tostring(definition.componentId or "")
    if componentId == "" then error("component definition is missing componentId") end
    if shipComponentData[componentId] ~= nil then
        error("duplicate component definition " .. componentId)
    end

    local slotType = tostring(definition.slotType or "")
    if not _componentSlotTypes[slotType] then
        error("component " .. componentId .. " has invalid slotType " .. slotType)
    end
    if tostring(definition.displayName or "") == "" then
        error("component " .. componentId .. " is missing displayName")
    end
    if tostring(definition.englishName or "") == "" then
        error("component " .. componentId .. " is missing englishName")
    end
    if tostring(definition.iconPath or "") == "" then
        error("component " .. componentId .. " is missing iconPath")
    end

    if slotType == "largeUtility" and not _hasAnyPositive(definition, {
        "armorAdd", "shieldAdd", "armorHardening", "shieldHardening", "shieldRegenAdd",
    }) then
        error("largeUtility component " .. componentId .. " has no protection effect")
    end
    if slotType == "auxiliary" and not _hasAnyPositive(definition, {
        "speedMultiplier", "turnResponseMultiplier", "turnForceMultiplier",
        "shieldMultiplier", "hullRegenPercent", "armorRegenPercent",
        "shieldHardening", "armorHardening", "reactorOutputMultiplier", "cloakStrength",
    }) then
        error("auxiliary component " .. componentId .. " has no auxiliary effect")
    end
    if slotType == "reactor" and _number(definition.powerOutput) <= 0.0 then
        error("reactor component " .. componentId .. " requires positive powerOutput")
    end
    if slotType == "thruster" and _number(definition.powerUse) <= 0.0 then
        error("thruster component " .. componentId .. " requires positive powerUse")
    end
    if slotType == "sensor" and (_number(definition.sensorRange) <= 0.0
        or _number(definition.sensorInterval) <= 0.0) then
        error("sensor component " .. componentId .. " requires sensorRange and sensorInterval")
    end

    shipComponentData[componentId] = definition
    return definition
end
