---@diagnostic disable: undefined-global

-- Stellaris 4.4.6 TORPEDO_3: shield 0, armor 10, hull 10.
shipDefinitionRegister({
    shipType = "devastatorTorpedo",
    displayName = "毁灭者鱼雷",
    playerConfigurable = false,
    playerDriveable = false,
    playerLockable = false,
    interceptorClass = "torpedo",
    requiresPositivePower = false,
    maxShieldHP = 0.0,
    maxArmorHP = 10.0,
    maxBodyHP = 10.0,
    shieldRadius = 0.85,
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
        baseArmorHP = 10.0,
        baseHullHP = 10.0,
    },
    componentPools = {},
    weaponMountProfiles = {},
    defaultSlotConfigurationId = "devastatorTorpedo_fixed",
    slotConfigurations = {
        {
            configurationId = "devastatorTorpedo_fixed",
            label = "FIXED",
            slotGroups = {},
            defaultLoadout = {},
            componentSlots = {},
            defaultComponentLoadout = {},
        },
    },
})
