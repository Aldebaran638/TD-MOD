---@diagnostic disable: undefined-global

local function registerInterceptorShip(definition)
    local resolved = definition or {}
    resolved.playerConfigurable = false
    resolved.playerDriveable = false
    resolved.playerLockable = false
    resolved.requiresPositivePower = false
    resolved.flightProfile = resolved.flightProfile or {}
    resolved.cameraProfile = resolved.cameraProfile or {}
    resolved.regen = resolved.regen or {
        tickInterval = 0.1,
        shieldPerSecond = 0.0,
        armorPerSecond = 0.0,
        bodyPerSecond = 0.0,
    }
    resolved.componentProfile = {
        baseShieldHP = tonumber(resolved.maxShieldHP) or 0.0,
        baseArmorHP = tonumber(resolved.maxArmorHP) or 0.0,
        baseHullHP = tonumber(resolved.maxBodyHP) or 0.0,
    }
    resolved.componentPools = {}
    resolved.slotWeaponPools = {}
    resolved.weaponMountProfiles = {}
    resolved.defaultSlotConfigurationId = resolved.shipType .. "_fixed"
    resolved.slotConfigurations = {
        {
            configurationId = resolved.defaultSlotConfigurationId,
            label = "FIXED",
            slotGroups = {},
            defaultLoadout = {},
            componentSlots = {},
            defaultComponentLoadout = {},
        },
    }
    shipDefinitionRegister(resolved)
end

-- Stellaris 4.4.6 SWARMER_MISSILE_2: shield 0, armor 15, hull 30.
registerInterceptorShip({
    shipType = "advancedSwarmerMissile",
    displayName = "先进型旋风导弹",
    interceptorClass = "missile",
    maxShieldHP = 0.0,
    maxArmorHP = 15.0,
    maxBodyHP = 30.0,
    shieldRadius = 0.65,
})

-- Stellaris 4.4.6 TORPEDO_3: shield 0, armor 10, hull 10.
registerInterceptorShip({
    shipType = "devastatorTorpedo",
    displayName = "毁灭者鱼雷",
    interceptorClass = "torpedo",
    maxShieldHP = 0.0,
    maxArmorHP = 10.0,
    maxBodyHP = 10.0,
    shieldRadius = 0.85,
})
