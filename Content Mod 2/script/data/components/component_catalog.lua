---@diagnostic disable: undefined-global

#include "schema.lua"
#include "defense/a/stellaris.lua"
#include "defense/l/stellaris.lua"
#include "core/reactor/stellaris.lua"
#include "core/thruster/stellaris.lua"
#include "core/sensor/stellaris.lua"

componentSlotPools = {}

for componentId, definition in pairs(shipComponentData) do
    local slotType = tostring(definition.slotType or "")
    if slotType ~= "" then
        componentSlotPools[slotType] = componentSlotPools[slotType] or {}
        componentSlotPools[slotType][#componentSlotPools[slotType] + 1] = componentId
    end
end

for _, pool in pairs(componentSlotPools) do
    table.sort(pool, function(leftId, rightId)
        local left = shipComponentData[leftId] or {}
        local right = shipComponentData[rightId] or {}
        local leftName = tostring(left.englishName or leftId)
        local rightName = tostring(right.englishName or rightId)
        if leftName ~= rightName then return leftName < rightName end
        return tostring(leftId) < tostring(rightId)
    end)
end

function shipComponentGetSlotPool(slotType)
    return componentSlotPools[tostring(slotType or "")] or {}
end

local function _componentClamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or 0.0))
end

function shipComponentFindConfiguration(definition, configurationId)
    local requested = tostring(
        configurationId or (definition or {}).defaultSlotConfigurationId or ""
    )
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

function shipComponentSlotGroups(configuration)
    local result = {}
    for _, group in ipairs((configuration or {}).componentSlots or {}) do
        local slotType = tostring(group.slotType or "")
        local count = math.max(0, math.floor(tonumber(group.count) or 0))
        if slotType ~= "" and count > 0 then
            result[#result + 1] = { slotType = slotType, count = count }
        end
    end
    return result
end

function shipComponentAllowed(_, slotType, componentId)
    local requestedSlotType = tostring(slotType or "")
    if tostring(componentId or "") == "" then
        return requestedSlotType == "largeUtility" or requestedSlotType == "auxiliary"
    end
    local component = shipComponentData[tostring(componentId or "")]
    if component == nil or tostring(component.slotType or "") ~= requestedSlotType then
        return false
    end
    for _, candidate in ipairs(shipComponentGetSlotPool(requestedSlotType)) do
        if candidate == componentId then return true end
    end
    return false
end

function shipComponentResolveProfile(
    definition,
    componentLoadout,
    configuration,
    weaponLoadout
)
    local base = (definition or {}).componentProfile or {}
    local regen = (definition or {}).regen or {}
    local protection = {
        maxShieldHP = tonumber((definition or {}).maxShieldHP)
            or tonumber(base.baseShieldHP) or 0.0,
        maxArmorHP = tonumber((definition or {}).maxArmorHP)
            or tonumber(base.baseArmorHP) or 0.0,
        maxBodyHP = tonumber((definition or {}).maxBodyHP)
            or tonumber(base.baseHullHP) or 0.0,
        shieldHardening = 0.0,
        armorHardening = 0.0,
        shieldRegenPerSecond = tonumber(regen.shieldPerSecond) or 0.0,
        armorRegenPercent = tonumber(base.baseArmorRegenPercent) or 0.0,
        hullRegenPercent = tonumber(base.baseHullRegenPercent) or 0.0,
    }
    local mobility = {
        speedMultiplier = 0.0,
        turnResponseMultiplier = 0.0,
        turnForceMultiplier = 0.0,
    }
    local shieldMultiplier = 0.0
    local powerOutput = 0.0
    local reactorOutputMultiplier = 0.0
    local componentPowerUse = 0.0
    local fixedSensor = (definition or {}).fixedSensorProfile or {}
    local sensor = {
        range = tonumber(fixedSensor.range) or 0.0,
        interval = tonumber(fixedSensor.interval) or 1.0,
        trackingAdd = tonumber(fixedSensor.trackingAdd) or 0.0,
        componentId = tostring(fixedSensor.componentId or ""),
    }
    local cloak = {
        available = false,
        strength = 0.0,
        shieldReduction = 0.0,
        shipLimit = 0,
    }

    local function applyComponent(componentId)
        local component = shipComponentData[tostring(componentId or "")]
        if component == nil then return end
        protection.maxShieldHP = protection.maxShieldHP + (_componentClamp(component.shieldAdd, 0.0, math.huge))
        protection.maxArmorHP = protection.maxArmorHP + (_componentClamp(component.armorAdd, 0.0, math.huge))
        protection.shieldHardening = protection.shieldHardening + (tonumber(component.shieldHardening) or 0.0)
        protection.armorHardening = protection.armorHardening + (tonumber(component.armorHardening) or 0.0)
        protection.shieldRegenPerSecond = protection.shieldRegenPerSecond + (tonumber(component.shieldRegenAdd) or 0.0)
        protection.armorRegenPercent = protection.armorRegenPercent + (tonumber(component.armorRegenPercent) or 0.0)
        protection.hullRegenPercent = protection.hullRegenPercent + (tonumber(component.hullRegenPercent) or 0.0)
        mobility.speedMultiplier = mobility.speedMultiplier + (tonumber(component.speedMultiplier) or 0.0)
        mobility.turnResponseMultiplier = mobility.turnResponseMultiplier + (tonumber(component.turnResponseMultiplier) or 0.0)
        mobility.turnForceMultiplier = mobility.turnForceMultiplier + (tonumber(component.turnForceMultiplier) or 0.0)
        shieldMultiplier = shieldMultiplier + (tonumber(component.shieldMultiplier) or 0.0)
        powerOutput = powerOutput + (tonumber(component.powerOutput) or 0.0)
        componentPowerUse = componentPowerUse + (tonumber(component.powerUse) or 0.0)
        reactorOutputMultiplier = reactorOutputMultiplier + (tonumber(component.reactorOutputMultiplier) or 0.0)
        if (tonumber(component.cloakStrength) or 0.0) > 0.0 then
            cloak.available = true
            cloak.strength = math.max(cloak.strength, tonumber(component.cloakStrength) or 0.0)
            cloak.shieldReduction = math.max(cloak.shieldReduction, tonumber(component.cloakedShieldReduction) or 0.0)
            cloak.shipLimit = math.max(cloak.shipLimit, math.floor(tonumber(component.shipLimit) or 0))
        end
        if (tonumber(component.sensorRange) or 0.0) > 0.0 then
            sensor.range = tonumber(component.sensorRange) or 0.0
            sensor.interval = math.max(0.05, tonumber(component.sensorInterval) or 1.0)
            sensor.trackingAdd = tonumber(component.trackingAdd) or 0.0
            sensor.componentId = tostring(component.componentId or "")
        end
    end

    for _, slots in pairs(componentLoadout or {}) do
        for _, componentId in ipairs(slots or {}) do applyComponent(componentId) end
    end

    powerOutput = powerOutput * (1.0 + math.max(0.0, reactorOutputMultiplier))
    protection.maxShieldHP = math.max(0.0, protection.maxShieldHP * (1.0 + shieldMultiplier))
    protection.maxArmorHP = math.max(0.0, protection.maxArmorHP)
    protection.maxBodyHP = math.max(0.0, protection.maxBodyHP)
    protection.shieldHardening = _componentClamp(protection.shieldHardening, 0.0, 1.0)
    protection.armorHardening = _componentClamp(protection.armorHardening, 0.0, 1.0)
    protection.armorRegenPerSecond = protection.maxArmorHP * protection.armorRegenPercent
    protection.hullRegenPerSecond = protection.maxBodyHP * protection.hullRegenPercent

    local weaponPowerUse = 0.0
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        local slotType = tostring(group.slotType or "")
        local groupId = tostring(group.groupId or "")
        local loadoutKey = shipDefinitionGetGroupLoadoutKey(groupId, slotType)
        local count = math.max(0, math.floor(tonumber(group.count) or 0))
        local defaults = (configuration or {}).defaultLoadout or {}
        local weaponId = tostring((weaponLoadout or {})[groupId]
            or (weaponLoadout or {})[loadoutKey]
            or (weaponLoadout or {})[slotType]
            or defaults[groupId]
            or defaults[loadoutKey]
            or defaults[slotType] or "")
        local weapon = (weaponData or {})[weaponId] or {}
        weaponPowerUse = weaponPowerUse + count * math.max(0.0, tonumber(weapon.powerUse) or 0.0)
    end
    local powerUse = componentPowerUse + weaponPowerUse
    local powerBalance = powerOutput - powerUse
    local excessRatio = 0.0
    if powerOutput > 0.0 and powerBalance / powerOutput >= 0.05 then
        excessRatio = _componentClamp(powerBalance / powerOutput, 0.0, 1.0)
    end
    local excessBonus = excessRatio * 0.10
    mobility.speedMultiplier = math.max(-0.95, mobility.speedMultiplier + excessBonus)
    mobility.turnResponseMultiplier = math.max(-0.95, mobility.turnResponseMultiplier + excessBonus)
    mobility.turnForceMultiplier = math.max(-0.95, mobility.turnForceMultiplier + excessBonus)
    return {
        protection = protection,
        mobility = mobility,
        sensor = sensor,
        energy = {
            output = powerOutput,
            componentUse = componentPowerUse,
            weaponUse = weaponPowerUse,
            use = powerUse,
            balance = powerBalance,
            valid = powerOutput > 0.0 and powerBalance > 0.0,
            excessRatio = excessRatio,
            speedMultiplier = excessBonus,
            evasionMultiplier = excessBonus,
            weaponDamageMultiplier = excessBonus,
            reactorOutputMultiplier = reactorOutputMultiplier,
        },
        cloak = cloak,
    }
end

function shipComponentDefaultLoadout(definition, configurationId)
    local configuration = shipComponentFindConfiguration(definition, configurationId) or {}
    local defaults = configuration.defaultComponentLoadout or {}
    local result = {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        result[group.slotType] = {}
        for index = 1, group.count do
            result[group.slotType][index] = tostring((defaults[group.slotType] or {})[index] or "")
        end
    end
    return result, configuration
end

function shipComponentEncodeLoadout(loadout)
    local slotTypes = {}
    for slotType, _ in pairs(loadout or {}) do slotTypes[#slotTypes + 1] = tostring(slotType or "") end
    table.sort(slotTypes)
    local parts = {}
    for _, slotType in ipairs(slotTypes) do
        for index, componentId in ipairs((loadout or {})[slotType] or {}) do
            parts[#parts + 1] = slotType .. "." .. tostring(index) .. "=" .. tostring(componentId or "")
        end
    end
    return table.concat(parts, ";")
end

function shipComponentDecodeLoadout(payload)
    local encoded = tostring(payload or "")
    if #encoded > 4096 then return nil, "component loadout is too large" end
    local result = {}
    local segmentCount = 0
    for segment in string.gmatch(encoded .. ";", "(.-);") do
        if segment ~= "" then
            segmentCount = segmentCount + 1
            if segmentCount > 128 then return nil, "component loadout has too many entries" end
            local slotType, indexText, componentId = string.match(segment, "^([%w_]+)%.(%d+)=([%w_-]*)$")
            local index = math.floor(tonumber(indexText) or 0)
            if slotType == nil or index <= 0 then return nil, "malformed component loadout" end
            result[slotType] = result[slotType] or {}
            if result[slotType][index] ~= nil then return nil, "duplicate component slot" end
            result[slotType][index] = tostring(componentId or "")
        end
    end
    return result, nil
end
