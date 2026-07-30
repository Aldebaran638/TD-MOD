---@diagnostic disable: undefined-global

#include "common/state/weapon_loadout.lua"
#include "slots/x/state/render_state.lua"
#include "slots/x/state/render_state_api.lua"
#include "slots/x/targeting/x_slot_targeting.lua"
#include "guided/targeting/guided_targeting.lua"
#include "common/input/main_weapon_input.lua"
#include "common/sound/weapon_sound_catalog.lua"
#include "common/sound/sound_service.lua"
#include "common/hud/main_weapon_hud.lua"
#include "common/hud/ship_crosshair.lua"
#include "guided/hud/guided_targeting_hud.lua"
#include "slots/x/hud/x_slot_lock_hud.lua"
#include "slots/x/tachyon_lance/effects/charging_fx.lua"
#include "slots/x/focused_arc_emitter/effects/charging_fx.lua"
#include "slots/x/tachyon_lance/effects/beam_fx.lua"
#include "slots/x/tachyon_lance/effects/muzzle_fx.lua"
#include "common/effects/weapon_fx_budget.lua"
#include "common/effects/weapon_fx_resources.lua"
#include "common/effects/gamma_laser_fx.lua"
#include "common/effects/weapon_muzzle_fx.lua"
#include "common/effects/weapon_impact_fx.lua"
#include "common/effects/shield_hit_fx.lua"
#include "common/effects/generic_raycast_fx.lua"
#include "slots/x/tachyon_lance/effects/impact_fx.lua"
#include "slots/l/kinetic_artillery/effects/projectile_visual.lua"
#include "guided/effects/missile_impact_fx.lua"
#include "guided/effects/missile_visual.lua"
#include "slots/h/gamma_strike_craft/effects/beam_fx.lua"
#include "slots/h/gamma_strike_craft/effects/craft_fx.lua"

client = client or {}

function client.weaponClientInit()
    client.xSlotRenderStateInit()
    client.soundModuleInit()
    client.tachyonBeamFxInit()
    client.tachyonMuzzleFxInit()
    client.weaponFxResourcesInit()
    client.gammaLaserFxInit()
    client.weaponMuzzleFxInit()
    client.weaponImpactFxInit()
    client.shieldHitFxInit()
    client.focusedArcChargingFxInit()
    client.genericRaycastFxInit()
    client.projectileVisualInit()
    client.missileVisualInit()
    client.hSlotCraftFxInit()
end

function client.weaponClientTick(dt)
    client.weaponLoadoutSyncTick(dt)
    client.guidedTargetingTick(dt)
    client.xSlotTargetingTick(dt)
    client.mainWeaponInputTick(dt)
    client.soundModuleTick(dt)
    client.tachyonChargingFxTick(dt)
    client.focusedArcChargingFxTick(dt)
    client.tachyonBeamFxTick(dt)
    client.tachyonMuzzleFxTick(dt)
    client.shieldHitFxTick(dt)
    client.tachyonImpactFxTick(dt)
    client.projectileVisualTick(dt)
    client.missileVisualTick(dt)
    client.hSlotBeamFxTick(dt)
    client.hSlotCraftFxTick(dt)
    client.genericRaycastFxTick(dt)
    client.gammaLaserFxTick(dt)
    client.weaponMuzzleFxTick(dt)
    client.weaponImpactFxTick(dt)
    client.mainWeaponHudTick(dt)
end

function client.weaponClientRender()
    client.missileVisualRender()
    client.hSlotBeamFxRender()
    client.hSlotCraftFxRender()
    client.tachyonBeamFxRender()
    client.tachyonMuzzleFxRender()
    client.focusedArcChargingFxRender()
    client.genericRaycastFxRender()
    client.gammaLaserFxRender()
    client.weaponMuzzleFxRender()
    client.weaponImpactFxRender()
end

function client.weaponClientDrawHud()
    client.mainWeaponHudDraw()
    client.shipCrosshairDraw()
    client.guidedTargetingHudDraw()
    client.xSlotLockHudDraw()
end
