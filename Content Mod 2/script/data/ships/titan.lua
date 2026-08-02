---@diagnostic disable: undefined-global

#include "titan_mounts.lua"

shipDefinitionRegister({
    shipType = "titan",
    displayName = "泰坦",
    maxShieldHP = 0,
    maxArmorHP = 0,
    maxBodyHP = 20000,
    shieldRadius = 15,
    flightProfile = {
        gravityCompensation = 10, forwardAcceleration = 30, backwardAcceleration = 24,
        maxCombatSpeed = 28, maxReverseSpeed = 18, quadraticDamping = 7000,
        attitude = { yawForceGain = 40000, pitchForceGain = 180000, yawForceMax = 14000, pitchForceMax = 14000 },
        roll = { forceGain = 5000, forceMax = 50000 },
    },
    cameraProfile = {
        distance = 24, distanceMin = 16, distanceMax = 34, pitchLimit = 85,
        rearYawMin = -90, rearYawMax = 90, mouseSensitivity = 0.04, glideStrength = 0.55,
        zoomSpeed = 0.5, switchDuration = 0.3, frontOffset = { x = 0, y = 2, z = -7 }, fov = 70,
    },
    regen = { tickInterval = 0.1, shieldPerSecond = 0, armorPerSecond = 0, bodyPerSecond = 0, shieldNoDamageDelay = 2, armorNoDamageDelay = 4, bodyNoDamageDelay = 6 },
    componentProfile = { baseShieldHP = 0, baseArmorHP = 0, baseHullHP = 20000, baseArmorRegenPercent = 0.001, baseHullRegenPercent = 0.001 },
    componentPools = {
        largeUtility = { "dragonScaleArmor", "darkMatterDeflector" },
        auxiliary = { "advancedAfterburners", "shieldCapacitor", "naniteRepairSystem", "advancedShieldHardener", "livingReactiveArmor", "reactorBooster3", "darkMatterCloakingField" },
        thruster = { "chemicalThrusters", "ionThrusters", "plasmaThrusters", "impulseThrusters", "darkMatterThrusters" },
        sensor = { "radarSystem", "graviticSensors", "subspaceSensors", "tachyonSensors" },
        reactor = { "fissionReactor", "fusionReactor", "coldFusionReactor", "antimatterReactor", "zeroPointReactor", "darkMatterReactor" },
    },
    slotWeaponPools = {
        T = { "perditionBeam" },
        L = { "largeGammaLaser", "largePlasmaCannon", "largeGaussCannon", "kineticArtillery", "largeStormfireAutocannon" },
        M = { "mediumGammaLaser", "mediumPlasmaCannon", "phaseDisruptor", "mediumGaussCannon", "mediumStormfireAutocannon", "swarmerMissile" },
    },
    weaponMountProfiles = shipMountProfileData.titan,
    defaultSlotConfigurationId = "titan_core",
    slotConfigurations = {
        {
            configurationId = "titan_core",
            label = "1T 8L 4M",
            slotGroups = {
                { groupId = "tSlot", slotType = "T", count = 1 },
                { groupId = "lSlot", slotType = "L", count = 8 },
                { groupId = "mSlot", slotType = "M", count = 4 },
            },
            defaultLoadout = { T = "perditionBeam", L = "kineticArtillery", M = "mediumGammaLaser" },
            -- Standard Titan sections provide 12 large and 3 auxiliary utility slots.
            componentSlots = {
                { slotType = "largeUtility", count = 12 },
                { slotType = "auxiliary", count = 3 },
                { slotType = "thruster", count = 1 },
                { slotType = "sensor", count = 1 },
                { slotType = "reactor", count = 1 },
            },
            defaultComponentLoadout = {
                largeUtility = {
                    "dragonScaleArmor", "darkMatterDeflector", "dragonScaleArmor", "darkMatterDeflector",
                    "dragonScaleArmor", "darkMatterDeflector", "dragonScaleArmor", "darkMatterDeflector",
                    "dragonScaleArmor", "darkMatterDeflector", "dragonScaleArmor", "darkMatterDeflector",
                },
                auxiliary = { "advancedAfterburners", "reactorBooster3", "naniteRepairSystem" },
                thruster = { "darkMatterThrusters" }, sensor = { "tachyonSensors" }, reactor = { "darkMatterReactor" },
            },
        },
    },
})
