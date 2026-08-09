---@diagnostic disable: undefined-global

-- Systems keep the existing public ClientCall API stable while their internal
-- implementations are now registered by visual stage and profile.
client = client or {}
client.weaponFxSystems = {}

local function _callbacks(initName, tickName, renderName)
    return {
        init = initName and function() client[initName]() end or nil,
        tick = tickName and function(dt) client[tickName](dt) end or nil,
        render = renderName and function() client[renderName]() end or nil,
    }
end

local function _registerSystem(id, initName, tickName, renderName)
    client.weaponFxSystems[#client.weaponFxSystems + 1] = _callbacks(initName, tickName, renderName)
end

local function _register(phase, profileId, systemId)
    client.weaponFxRegister(phase, profileId, { system = systemId })
end

_register("charge", "default", "chargedDefault")
_register("charge", "tachyonLance", "tachyonCharge")
_register("charge", "focusedArcEmitter", "focusedArcCharge")
_register("charge", "perditionBeam", "perditionCharge")

for _, profileId in ipairs({ "energyBeam", "redBeam", "blueBeam", "uvBeam", "xrayBeam" }) do
    _register("beam", profileId, "raycastBeam")
end
_register("beam", "gammaBeam", "gammaBeam")
_register("beam", "arcBeam", "raycastBeam")
_register("beam", "focusedArcBeam", "raycastBeam")
_register("beam", "psionicArcBeam", "raycastBeam")
_register("beam", "tachyonLance", "tachyonBeam")
_register("beam", "perditionBeam", "perditionBeam")
_register("beam", "default", "raycastBeam")

for _, profileId in ipairs({ "none", "kineticArtillery", "gaussLarge", "gaussMedium", "autocannonLarge", "autocannonMedium", "plasmaLarge", "plasmaMedium", "gigaMagneticLaunch", "neutronCompression", "swarmerLaunch", "torpedoLaunch", "disruptor", "focusedArcDischarge" }) do
    _register("muzzle", profileId, "defaultMuzzle")
end
_register("muzzle", "tachyonLance", "tachyonMuzzle")
_register("muzzle", "gammaLarge", "gammaBeam")
_register("muzzle", "gammaMedium", "gammaBeam")
_register("muzzle", "default", "defaultMuzzle")

for _, profileId in ipairs({ "none", "kineticArtillery", "gaussLarge", "gaussMedium", "autocannonLarge", "autocannonMedium", "plasmaLarge", "plasmaMedium", "gigaPenetration", "neutronImpact", "focusedArcImpact", "disruptorImplosion" }) do
    _register("impact", profileId, "defaultImpact")
end
_register("impact", "gammaLarge", "gammaBeam")
_register("impact", "gammaMedium", "gammaBeam")
_register("impact", "tachyonLance", "tachyonImpact")
_register("impact", "perditionImpact", "perditionImpact")
_register("impact", "swarmerFragmentation", "guidedImpact")
_register("impact", "torpedoHeavy", "guidedImpact")
_register("impact", "default", "defaultImpact")

for _, profileId in ipairs({ "kineticProjectile", "plasmaProjectile", "autocannonProjectile", "neutronProjectile", "gigaCannonProjectile" }) do
    _register("projectile", profileId, "projectile")
end
_register("projectile", "guidedMissile", "guided")
_register("projectile", "strikeCraft", "craft")
_register("projectile", "default", "projectile")

_register("craft", "strikeCraft", "craft")
_register("craft", "default", "craft")

_registerSystem("sharedResources", "weaponFxResourcesInit", nil, nil)
_registerSystem("shield", "shieldHitFxInit", "shieldHitFxTick", nil)
_registerSystem("tachyonCharge", nil, "tachyonChargingFxTick", nil)
_registerSystem("focusedArcCharge", "focusedArcChargingFxInit", "focusedArcChargingFxTick", "focusedArcChargingFxRender")
_registerSystem("tachyonBeam", "tachyonBeamFxInit", "tachyonBeamFxTick", "tachyonBeamFxRender")
_registerSystem("tachyonMuzzle", "tachyonMuzzleFxInit", "tachyonMuzzleFxTick", "tachyonMuzzleFxRender")
_registerSystem("perditionCharge", "perditionChargingFxInit", "perditionChargingFxTick", "perditionChargingFxRender")
_registerSystem("perditionBeam", "perditionBeamFxInit", "perditionBeamFxTick", "perditionBeamFxRender")
_registerSystem("perditionImpact", "perditionImpactFxInit", "perditionImpactFxTick", "perditionImpactFxRender")
_registerSystem("raycastBeam", "genericRaycastFxInit", "genericRaycastFxTick", "genericRaycastFxRender")
_registerSystem("gammaBeam", "gammaLaserFxInit", "gammaLaserFxTick", "gammaLaserFxRender")
_registerSystem("defaultMuzzle", "weaponMuzzleFxInit", "weaponMuzzleFxTick", "weaponMuzzleFxRender")
_registerSystem("defaultImpact", "weaponImpactFxInit", "weaponImpactFxTick", "weaponImpactFxRender")
_registerSystem("tachyonImpact", nil, "tachyonImpactFxTick", nil)
_registerSystem("projectile", "projectileVisualInit", "projectileVisualTick", nil)
_registerSystem("guided", "missileVisualInit", "missileVisualTick", "missileVisualRender")
_registerSystem("craft", "hSlotCraftFxInit", "hSlotCraftFxTick", "hSlotCraftFxRender")
_registerSystem("craftSubweapon", nil, "hSlotBeamFxTick", "hSlotBeamFxRender")
_registerSystem("pointDefense", "pointDefenseFxInit", "pointDefenseFxTick", "pointDefenseFxRender")

function client.weaponFxInitAll()
    for _, system in ipairs(client.weaponFxSystems) do if system.init then system.init() end end
end

function client.weaponFxTickAll(dt)
    client.weaponFxBudgetBeginFrame(dt)
    for _, system in ipairs(client.weaponFxSystems) do if system.tick then system.tick(dt) end end
end

function client.weaponFxRenderAll()
    for _, system in ipairs(client.weaponFxSystems) do if system.render then system.render() end end
end
