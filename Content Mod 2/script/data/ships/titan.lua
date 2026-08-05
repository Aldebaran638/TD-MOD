---@diagnostic disable: undefined-global

#include "titan_mounts.lua"

shipDefinitionRegister({
    shipType = "titan",
    displayName = "泰坦",
    maxShieldHP = 0,
    maxArmorHP = 0,
    maxBodyHP = 40000,
    shieldRadius = 15,
    flightProfile = {
        gravityCompensation = 10, forwardAcceleration = 30, backwardAcceleration = 24,
        maxCombatSpeed = 28, maxReverseSpeed = 18, quadraticDamping = 7000,
        attitude = {
            -- Preserved from the original Titan controller during migration.
            yawDeadzone = 0.5,
            pitchDeadzone = 0.5,
            yawSoftZone = 3.0,
            pitchSoftZone = 3.0,
            yawForceGain = 500000,
            pitchForceGain = 3600000,
            yawForceMax = 2000000,
            pitchForceMax = 2000000,
            yawDamping = 33000000,
            pitchDamping = 100000000,
            yawRateDeadzone = 0.01,
            pitchRateDeadzone = 0.01,
            yawLeverArm = 8.0,
            pitchLeverArm = 8.0,
        },
        roll = { forceGain = 5000, forceMax = 50000 },
    },
    cameraProfile = {
        distance = 50, distanceMin = 40, distanceMax = 80, pitchLimit = 85,
        rearYawMin = -90, rearYawMax = 90, mouseSensitivity = 0.04, glideStrength = 0.55,
        zoomSpeed = 0.5, switchDuration = 0.3,
        frontOffset = { x = 0, y = 3, z = -7 },
        frontPitchLimit = 85, frontYawMin = -85, frontYawMax = 85,
        rearDefaultPitch = 0, fov = 70,
    },
    regen = { tickInterval = 0.1, shieldPerSecond = 0, armorPerSecond = 0, bodyPerSecond = 0, shieldNoDamageDelay = 2, armorNoDamageDelay = 4, bodyNoDamageDelay = 6 },
    componentProfile = { baseArmorRegenPercent = 0.001, baseHullRegenPercent = 0.001 },
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
        H = { "gammaStrikeCraft" },
    },
    weaponMountProfiles = shipMountProfileData.titan,
    defaultSlotConfigurationId = "titan_core",
    slotConfigurations = {
        {
            configurationId = "titan_core",
            label = "2T 4L + 4L 4M 4H",
            slotGroups = {
                { groupId = "tSlot", slotType = "T", count = 2 },
                -- Each original Titan L battery is a four-mount volley.
                { groupId = "lSlot", slotType = "L", count = 4, salvoGroupSize = 4 },
                { groupId = "lSlot2", slotType = "L", count = 4, salvoGroupSize = 4 },
                { groupId = "mSlot", slotType = "M", count = 4 },
                { groupId = "hSlot", slotType = "H", count = 4 },
            },
            defaultLoadout = {
                T = "perditionBeam", L = "kineticArtillery", L2 = "largeGammaLaser",
                M = "mediumGammaLaser", H = "gammaStrikeCraft",
            },
            componentSlots = {
                { slotType = "largeUtility", count = 20 },
                { slotType = "auxiliary", count = 4 },
                { slotType = "thruster", count = 1 },
                { slotType = "sensor", count = 1 },
                { slotType = "reactor", count = 1 },
            },
            defaultComponentLoadout = {
                largeUtility = {
                    "dragonScaleArmor", "dragonScaleArmor", "dragonScaleArmor", "dragonScaleArmor",
                    "dragonScaleArmor", "dragonScaleArmor", "dragonScaleArmor", "dragonScaleArmor",
                    "dragonScaleArmor", "dragonScaleArmor", "dragonScaleArmor", "dragonScaleArmor",
                    "dragonScaleArmor", "darkMatterDeflector", "darkMatterDeflector", "darkMatterDeflector",
                    "darkMatterDeflector", "darkMatterDeflector", "darkMatterDeflector", "darkMatterDeflector",
                },
                auxiliary = {
                    "reactorBooster3", "reactorBooster3",
                    "reactorBooster3", "shieldCapacitor",
                },
                thruster = { "darkMatterThrusters" }, sensor = { "tachyonSensors" }, reactor = { "darkMatterReactor" },
            },
        },
    },
})
