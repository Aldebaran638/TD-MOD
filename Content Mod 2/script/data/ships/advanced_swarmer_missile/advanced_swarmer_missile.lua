-- Stellaris 4.4.6 SWARMER_MISSILE_2: shield 0, armor 15, hull 30.
---@diagnostic disable: undefined-global

shipDefinitionRegister({
    shipType = "advancedSwarmerMissile",
    displayName = "先进型旋风导弹",
    playerConfigurable = false,
    playerDriveable = false,
    playerLockable = false,
    interceptorClass = "missile",
    requiresPositivePower = false,
    maxShieldHP = 0.0,
    maxArmorHP = 15.0,
    maxBodyHP = 30.0,
    shieldRadius = 0.65,
    flightProfile = {},
    cameraProfile = {},
    regen = {
        tickInterval = 0.1,
        shieldPerSecond = 0.0,
        armorPerSecond = 0.0,
        bodyPerSecond = 0.0,
    },
    componentProfile = {
        baseShieldHP = 0.0,
        baseArmorHP = 15.0,
        baseHullHP = 30.0,
    },
    weaponMountProfiles = {},
    defaultSlotConfigurationId = "advancedSwarmerMissile_fixed",
    slotConfigurations = {
        {
            configurationId = "advancedSwarmerMissile_fixed",
            label = "FIXED",
            slotGroups = {},
            defaultLoadout = {},
            componentSlots = {},
            defaultComponentLoadout = {},
        },
    },
})
