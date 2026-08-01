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
        powerUse = 220.0,
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
        powerUse = 20.0,
    },
    shieldCapacitor = {
        componentId = "shieldCapacitor",
        slotType = "auxiliary",
        displayName = "护盾电容",
        englishName = "Shield Capacitor",
        iconPath = "MOD/gfx/ui/defense_components/shieldCapacitor.png",
        shieldMultiplier = 0.10,
        powerUse = 20.0,
    },
    naniteRepairSystem = {
        componentId = "naniteRepairSystem",
        slotType = "auxiliary",
        displayName = "纳米修复系统",
        englishName = "Nanite Repair System",
        iconPath = "MOD/gfx/ui/defense_components/naniteRepairSystem.png",
        hullRegenPercent = 0.0015,
        armorRegenPercent = 0.0020,
        powerUse = 15.0,
    },
    advancedShieldHardener = {
        componentId = "advancedShieldHardener",
        slotType = "auxiliary",
        displayName = "高级护盾硬化器",
        englishName = "Advanced Shield Hardener",
        iconPath = "MOD/gfx/ui/defense_components/advancedShieldHardener.png",
        shieldHardening = 0.25,
        powerUse = 25.0,
    },
    livingReactiveArmor = {
        componentId = "livingReactiveArmor",
        slotType = "auxiliary",
        displayName = "活性反应装甲",
        englishName = "Living Reactive Armor",
        iconPath = "MOD/gfx/ui/defense_components/livingReactiveArmor.png",
        armorHardening = 0.25,
        powerUse = 25.0,
    },
    reactorBooster1 = {
        componentId = "reactorBooster1",
        slotType = "auxiliary",
        displayName = "反应堆增压器 I",
        englishName = "Reactor Booster I",
        iconPath = "MOD/gfx/ui/defense_components/reactorBooster1.png",
        reactorOutputMultiplier = 0.20,
    },
    reactorBooster2 = {
        componentId = "reactorBooster2",
        slotType = "auxiliary",
        displayName = "反应堆增压器 II",
        englishName = "Reactor Booster II",
        iconPath = "MOD/gfx/ui/defense_components/reactorBooster2.png",
        reactorOutputMultiplier = 0.33,
    },
    reactorBooster3 = {
        componentId = "reactorBooster3",
        slotType = "auxiliary",
        displayName = "反应堆增压器 III",
        englishName = "Reactor Booster III",
        iconPath = "MOD/gfx/ui/defense_components/reactorBooster3.png",
        reactorOutputMultiplier = 0.50,
    },
    darkMatterCloakingField = {
        componentId = "darkMatterCloakingField",
        slotType = "auxiliary",
        displayName = "暗物质隐形场",
        englishName = "Dark Matter Cloaking Field",
        iconPath = "MOD/gfx/ui/defense_components/darkMatterCloakingField.png",
        officialComponentId = "BATTLESHIP_CLOAKING_DARK_MATTER",
        powerUse = 180.0,
        cloakStrength = 1.0,
        cloakedShieldReduction = 0.50,
        shipLimit = 1,
    },
    chemicalThrusters = {
        componentId = "chemicalThrusters",
        slotType = "thruster",
        displayName = "化学推进器",
        englishName = "Chemical Thrusters",
        iconPath = "MOD/gfx/ui/defense_components/thruster_1.png",
        officialComponentId = "BATTLESHIP_SHIP_THRUSTER_1",
        powerUse = 80.0,
    },
    ionThrusters = {
        componentId = "ionThrusters",
        slotType = "thruster",
        displayName = "离子推进器",
        englishName = "Ion Thrusters",
        iconPath = "MOD/gfx/ui/defense_components/thruster_2.png",
        officialComponentId = "BATTLESHIP_SHIP_THRUSTER_2",
        powerUse = 120.0,
        speedMultiplier = 0.25,
        turnResponseMultiplier = 0.25,
        turnForceMultiplier = 0.25,
    },
    plasmaThrusters = {
        componentId = "plasmaThrusters",
        slotType = "thruster",
        displayName = "等离子推进器",
        englishName = "Plasma Thrusters",
        iconPath = "MOD/gfx/ui/defense_components/thruster_3.png",
        officialComponentId = "BATTLESHIP_SHIP_THRUSTER_3",
        powerUse = 160.0,
        speedMultiplier = 0.50,
        turnResponseMultiplier = 0.50,
        turnForceMultiplier = 0.50,
    },
    impulseThrusters = {
        componentId = "impulseThrusters",
        slotType = "thruster",
        displayName = "脉冲推进器",
        englishName = "Impulse Thrusters",
        iconPath = "MOD/gfx/ui/defense_components/thruster_4.png",
        officialComponentId = "BATTLESHIP_SHIP_THRUSTER_4",
        powerUse = 200.0,
        speedMultiplier = 0.75,
        turnResponseMultiplier = 0.75,
        turnForceMultiplier = 0.75,
    },
    darkMatterThrusters = {
        componentId = "darkMatterThrusters",
        slotType = "thruster",
        displayName = "暗物质推进器",
        englishName = "Dark Matter Thrusters",
        iconPath = "MOD/gfx/ui/defense_components/thruster_5.png",
        officialComponentId = "BATTLESHIP_SHIP_THRUSTER_5",
        powerUse = 240.0,
        speedMultiplier = 1.25,
        turnResponseMultiplier = 1.25,
        turnForceMultiplier = 1.25,
    },
    radarSystem = {
        componentId = "radarSystem",
        slotType = "sensor",
        displayName = "雷达系统",
        englishName = "Radar System",
        iconPath = "MOD/gfx/ui/defense_components/sensor_1.png",
        officialComponentId = "SENSOR_1",
        powerUse = 5.0,
        sensorRange = 300.0,
        sensorInterval = 1.0,
        trackingAdd = 0.0,
    },
    graviticSensors = {
        componentId = "graviticSensors",
        slotType = "sensor",
        displayName = "引力传感器",
        englishName = "Gravitic Sensors",
        iconPath = "MOD/gfx/ui/defense_components/sensor_2.png",
        officialComponentId = "SENSOR_2",
        powerUse = 10.0,
        sensorRange = 600.0,
        sensorInterval = 0.75,
        trackingAdd = 5.0,
    },
    subspaceSensors = {
        componentId = "subspaceSensors",
        slotType = "sensor",
        displayName = "亚空间传感器",
        englishName = "Subspace Sensors",
        iconPath = "MOD/gfx/ui/defense_components/sensor_3.png",
        officialComponentId = "SENSOR_3",
        powerUse = 15.0,
        sensorRange = 900.0,
        sensorInterval = 0.50,
        trackingAdd = 10.0,
    },
    tachyonSensors = {
        componentId = "tachyonSensors",
        slotType = "sensor",
        displayName = "快子传感器",
        englishName = "Tachyon Sensors",
        iconPath = "MOD/gfx/ui/defense_components/sensor_4.png",
        officialComponentId = "SENSOR_4",
        powerUse = 20.0,
        sensorRange = 1200.0,
        sensorInterval = 0.25,
        trackingAdd = 15.0,
    },
    fissionReactor = {
        componentId = "fissionReactor",
        slotType = "reactor",
        displayName = "裂变反应堆",
        englishName = "Fission Reactor",
        iconPath = "MOD/gfx/ui/defense_components/reactor_1.png",
        officialComponentId = "BATTLESHIP_FISSION_REACTOR",
        powerOutput = 550.0,
    },
    fusionReactor = {
        componentId = "fusionReactor",
        slotType = "reactor",
        displayName = "聚变反应堆",
        englishName = "Fusion Reactor",
        iconPath = "MOD/gfx/ui/defense_components/reactor_2.png",
        officialComponentId = "BATTLESHIP_FUSION_REACTOR",
        powerOutput = 720.0,
    },
    coldFusionReactor = {
        componentId = "coldFusionReactor",
        slotType = "reactor",
        displayName = "冷核聚变反应堆",
        englishName = "Cold Fusion Reactor",
        iconPath = "MOD/gfx/ui/defense_components/reactor_3.png",
        officialComponentId = "BATTLESHIP_COLD_FUSION_REACTOR",
        powerOutput = 950.0,
    },
    antimatterReactor = {
        componentId = "antimatterReactor",
        slotType = "reactor",
        displayName = "反物质反应堆",
        englishName = "Antimatter Reactor",
        iconPath = "MOD/gfx/ui/defense_components/reactor_4.png",
        officialComponentId = "BATTLESHIP_ANTIMATTER_REACTOR",
        powerOutput = 1250.0,
    },
    zeroPointReactor = {
        componentId = "zeroPointReactor",
        slotType = "reactor",
        displayName = "零点反应堆",
        englishName = "Zero Point Reactor",
        iconPath = "MOD/gfx/ui/defense_components/reactor_5.png",
        officialComponentId = "BATTLESHIP_ZERO_POINT_REACTOR",
        powerOutput = 1550.0,
    },
    darkMatterReactor = {
        componentId = "darkMatterReactor",
        slotType = "reactor",
        displayName = "暗物质反应堆",
        englishName = "Dark Matter Reactor",
        iconPath = "MOD/gfx/ui/defense_components/dark_matter_power_core.png",
        officialComponentId = "BATTLESHIP_DARK_MATTER_REACTOR",
        powerOutput = 2000.0,
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
    if tostring(componentId or "") == "" then
        return slotType ~= "thruster"
            and slotType ~= "sensor"
            and slotType ~= "reactor"
    end
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

function shipComponentResolveProfile(
    definition,
    componentLoadout,
    configuration,
    weaponLoadout
)
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
        powerOutput = powerOutput + (tonumber(component.powerOutput) or 0.0)
        componentPowerUse =
            componentPowerUse + (tonumber(component.powerUse) or 0.0)
        reactorOutputMultiplier = reactorOutputMultiplier
            + (tonumber(component.reactorOutputMultiplier) or 0.0)
        if (tonumber(component.cloakStrength) or 0.0) > 0.0 then
            cloak.available = true
            cloak.strength = math.max(
                cloak.strength,
                tonumber(component.cloakStrength) or 0.0
            )
            cloak.shieldReduction = math.max(
                cloak.shieldReduction,
                tonumber(component.cloakedShieldReduction) or 0.0
            )
            cloak.shipLimit = math.max(
                cloak.shipLimit,
                math.floor(tonumber(component.shipLimit) or 0)
            )
        end
        if (tonumber(component.sensorRange) or 0.0) > 0.0 then
            sensor.range = tonumber(component.sensorRange) or 0.0
            sensor.interval = math.max(
                0.05,
                tonumber(component.sensorInterval) or 1.0
            )
            sensor.trackingAdd = tonumber(component.trackingAdd) or 0.0
            sensor.componentId = tostring(component.componentId or "")
        end
    end

    for _, slots in pairs(componentLoadout or {}) do
        for _, componentId in ipairs(slots or {}) do applyComponent(componentId) end
    end

    powerOutput = powerOutput * (1.0 + math.max(0.0, reactorOutputMultiplier))
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

    local weaponPowerUse = 0.0
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        local slotType = tostring(group.slotType or "")
        local count = math.max(0, math.floor(tonumber(group.count) or 0))
        local weaponId = tostring((weaponLoadout or {})[slotType]
            or ((configuration or {}).defaultLoadout or {})[slotType] or "")
        local weapon = (weaponData or {})[weaponId] or {}
        weaponPowerUse = weaponPowerUse
            + count * math.max(0.0, tonumber(weapon.powerUse) or 0.0)
    end
    local powerUse = componentPowerUse + weaponPowerUse
    local powerBalance = powerOutput - powerUse
    local excessRatio = 0.0
    if powerOutput > 0.0 and powerBalance / powerOutput >= 0.05 then
        excessRatio = _componentClamp(powerBalance / powerOutput, 0.0, 1.0)
    end
    local excessBonus = excessRatio * 0.10
    mobility.speedMultiplier = mobility.speedMultiplier + excessBonus
    mobility.turnResponseMultiplier =
        mobility.turnResponseMultiplier + excessBonus
    mobility.turnForceMultiplier = mobility.turnForceMultiplier + excessBonus
    mobility.speedMultiplier = math.max(-0.95, mobility.speedMultiplier)
    mobility.turnResponseMultiplier =
        math.max(-0.95, mobility.turnResponseMultiplier)
    mobility.turnForceMultiplier =
        math.max(-0.95, mobility.turnForceMultiplier)
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
