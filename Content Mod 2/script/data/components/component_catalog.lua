---@diagnostic disable: undefined-global

shipComponentData = shipComponentData or {
    dragonScaleArmor = {
        componentId = "dragonScaleArmor",
        slotType = "largeUtility",
        displayName = "龙鳞装甲",
        englishName = "Dragonscale Armor",
        iconPath = "MOD/gfx/ui/defense_components/dragonScaleArmor.png",
        armorAdd = 2925.0,
        armorHardening = 0.05,
    },
    darkMatterDeflector = {
        componentId = "darkMatterDeflector",
        slotType = "largeUtility",
        displayName = "暗物质偏导盾",
        englishName = "Dark Matter Deflector",
        iconPath = "MOD/gfx/ui/defense_components/darkMatterDeflector.png",
        shieldAdd = 2925.0,
        shieldRegenAdd = 8.125,
        shieldHardening = 0.05,
    },
    advancedAfterburners = {
        componentId = "advancedAfterburners",
        slotType = "auxiliary",
        displayName = "高级加力燃烧室",
        englishName = "Advanced Afterburners",
        iconPath = "MOD/gfx/ui/defense_components/advancedAfterburners.png",
        speedMultiplier = 0.20,
        turnResponseMultiplier = 0.50,
        turnForceMultiplier = 1.00,
    },
    shieldCapacitor = {
        componentId = "shieldCapacitor",
        slotType = "auxiliary",
        displayName = "护盾电容",
        englishName = "Shield Capacitor",
        iconPath = "MOD/gfx/ui/defense_components/shieldCapacitor.png",
        shieldMultiplier = 0.10,
    },
    naniteRepairSystem = {
        componentId = "naniteRepairSystem",
        slotType = "auxiliary",
        displayName = "纳米修复系统",
        englishName = "Nanite Repair System",
        iconPath = "MOD/gfx/ui/defense_components/naniteRepairSystem.png",
        hullRegenPercent = 0.0015,
        armorRegenPercent = 0.0020,
    },
    advancedShieldHardener = {
        componentId = "advancedShieldHardener",
        slotType = "auxiliary",
        displayName = "高级护盾硬化器",
        englishName = "Advanced Shield Hardener",
        iconPath = "MOD/gfx/ui/defense_components/advancedShieldHardener.png",
        shieldHardening = 0.25,
    },
    livingReactiveArmor = {
        componentId = "livingReactiveArmor",
        slotType = "auxiliary",
        displayName = "活性反应装甲",
        englishName = "Living Reactive Armor",
        iconPath = "MOD/gfx/ui/defense_components/livingReactiveArmor.png",
        armorHardening = 0.25,
    },
}

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

function shipComponentAllowed(definition, slotType, componentId)
    if tostring(componentId or "") == "" then return true end
    local component = shipComponentData[tostring(componentId or "")]
    if component == nil or tostring(component.slotType or "") ~= tostring(slotType or "") then
        return false
    end
    local pool = ((definition or {}).componentPools or {})[tostring(slotType or "")] or {}
    for _, candidate in ipairs(pool) do
        if tostring(candidate or "") == tostring(componentId or "") then return true end
    end
    return false
end

function shipComponentResolveProfile(definition, componentLoadout)
    local base = (definition or {}).componentProfile or {}
    local regen = (definition or {}).regen or {}
    local protection = {
        maxShieldHP = tonumber(base.baseShieldHP)
            or tonumber((definition or {}).maxShieldHP) or 0.0,
        maxArmorHP = tonumber(base.baseArmorHP)
            or tonumber((definition or {}).maxArmorHP) or 0.0,
        maxBodyHP = tonumber(base.baseHullHP)
            or tonumber((definition or {}).maxBodyHP) or 0.0,
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

    local function applyComponent(componentId)
        local component = shipComponentData[tostring(componentId or "")]
        if component == nil then return end
        protection.maxShieldHP =
            protection.maxShieldHP + (tonumber(component.shieldAdd) or 0.0)
        protection.maxArmorHP =
            protection.maxArmorHP + (tonumber(component.armorAdd) or 0.0)
        protection.shieldHardening =
            protection.shieldHardening
                + (tonumber(component.shieldHardening) or 0.0)
        protection.armorHardening =
            protection.armorHardening
                + (tonumber(component.armorHardening) or 0.0)
        protection.shieldRegenPerSecond =
            protection.shieldRegenPerSecond
                + (tonumber(component.shieldRegenAdd) or 0.0)
        protection.armorRegenPercent =
            protection.armorRegenPercent
                + (tonumber(component.armorRegenPercent) or 0.0)
        protection.hullRegenPercent =
            protection.hullRegenPercent
                + (tonumber(component.hullRegenPercent) or 0.0)
        mobility.speedMultiplier =
            mobility.speedMultiplier + (tonumber(component.speedMultiplier) or 0.0)
        mobility.turnResponseMultiplier =
            mobility.turnResponseMultiplier
                + (tonumber(component.turnResponseMultiplier) or 0.0)
        mobility.turnForceMultiplier =
            mobility.turnForceMultiplier
                + (tonumber(component.turnForceMultiplier) or 0.0)
        shieldMultiplier =
            shieldMultiplier + (tonumber(component.shieldMultiplier) or 0.0)
    end

    for _, slots in pairs(componentLoadout or {}) do
        for _, componentId in ipairs(slots or {}) do applyComponent(componentId) end
    end

    protection.maxShieldHP =
        math.max(0.0, protection.maxShieldHP * (1.0 + shieldMultiplier))
    protection.maxArmorHP = math.max(0.0, protection.maxArmorHP)
    protection.maxBodyHP = math.max(0.0, protection.maxBodyHP)
    protection.shieldHardening =
        _componentClamp(protection.shieldHardening, 0.0, 1.0)
    protection.armorHardening =
        _componentClamp(protection.armorHardening, 0.0, 1.0)
    protection.armorRegenPerSecond =
        protection.maxArmorHP * protection.armorRegenPercent
    protection.hullRegenPerSecond =
        protection.maxBodyHP * protection.hullRegenPercent

    mobility.speedMultiplier = math.max(-0.95, mobility.speedMultiplier)
    mobility.turnResponseMultiplier =
        math.max(-0.95, mobility.turnResponseMultiplier)
    mobility.turnForceMultiplier =
        math.max(-0.95, mobility.turnForceMultiplier)
    return { protection = protection, mobility = mobility }
end

function shipComponentDefaultLoadout(definition, configurationId)
    local configuration = shipComponentFindConfiguration(definition, configurationId) or {}
    local defaults = configuration.defaultComponentLoadout or {}
    local result = {}
    for _, group in ipairs(shipComponentSlotGroups(configuration)) do
        result[group.slotType] = {}
        for index = 1, group.count do
            result[group.slotType][index] =
                tostring((defaults[group.slotType] or {})[index] or "")
        end
    end
    return result, configuration
end

function shipComponentEncodeLoadout(loadout)
    local slotTypes = {}
    for slotType, _ in pairs(loadout or {}) do
        slotTypes[#slotTypes + 1] = tostring(slotType or "")
    end
    table.sort(slotTypes)
    local parts = {}
    for _, slotType in ipairs(slotTypes) do
        for index, componentId in ipairs((loadout or {})[slotType] or {}) do
            parts[#parts + 1] = slotType .. "." .. tostring(index)
                .. "=" .. tostring(componentId or "")
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
            if segmentCount > 128 then
                return nil, "component loadout has too many entries"
            end
            local slotType, indexText, componentId =
                string.match(segment, "^([%w_]+)%.(%d+)=([%w_-]*)$")
            local index = math.floor(tonumber(indexText) or 0)
            if slotType == nil or index <= 0 then
                return nil, "malformed component loadout"
            end
            result[slotType] = result[slotType] or {}
            if result[slotType][index] ~= nil then
                return nil, "duplicate component slot"
            end
            result[slotType][index] = tostring(componentId or "")
        end
    end
    return result, nil
end
