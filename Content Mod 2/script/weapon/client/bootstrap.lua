---@diagnostic disable: undefined-global

#include "common/state/weapon_loadout.lua"
#include "../common/targeting_policy.lua"
#include "common/targeting/target_catalog.lua"
#include "common/hud/radial_weapon_wheel.lua"
#include "slots/x/state/render_state.lua"
#include "slots/x/state/render_state_api.lua"
#include "slots/x/targeting/x_slot_targeting.lua"
#include "guided/targeting/guided_targeting.lua"
#include "common/input/main_weapon_input.lua"
#include "common/sound/weapon_sound_catalog.lua"
#include "common/sound/sound_service.lua"
#include "common/hud/target_lock_reticle.lua"
#include "common/hud/main_weapon_hud.lua"
#include "common/hud/ship_crosshair.lua"
#include "guided/hud/guided_targeting_hud.lua"
#include "slots/x/hud/x_slot_lock_hud.lua"
#include "common/effects/registry/effect_profile_registry.lua"
#include "common/effects/registry/palette_profile_registry.lua"
#include "common/effects/shared/effect_budget.lua"
#include "common/effects/shared/effect_resources.lua"
#include "common/effects/shared/shield_hit.lua"
#include "common/effects/beam/charged_helpers.lua"
#include "common/effects/beam/gamma.lua"
#include "common/effects/charge/default.lua"
#include "common/effects/charge/tachyon_lance.lua"
#include "common/effects/charge/focused_arc.lua"
#include "common/effects/charge/perdition_beam.lua"
#include "common/effects/beam/default.lua"
#include "common/effects/beam/arc.lua"
#include "common/effects/beam/tachyon_lance.lua"
#include "common/effects/beam/perdition_beam.lua"
#include "common/effects/muzzle/default.lua"
#include "common/effects/muzzle/tachyon_lance.lua"
#include "common/effects/muzzle/gamma.lua"
#include "common/effects/muzzle/ballistic.lua"
#include "common/effects/muzzle/guided.lua"
#include "common/effects/impact/default.lua"
#include "common/effects/impact/gamma.lua"
#include "common/effects/impact/arc.lua"
#include "common/effects/impact/ballistic.lua"
#include "common/effects/impact/plasma.lua"
#include "common/effects/impact/neutron.lua"
#include "common/effects/impact/guided.lua"
#include "common/effects/impact/tachyon_lance.lua"
#include "common/effects/impact/perdition_beam.lua"
#include "common/effects/projectile/default.lua"
#include "common/effects/projectile/kinetic.lua"
#include "common/effects/projectile/plasma.lua"
#include "common/effects/projectile/autocannon.lua"
#include "common/effects/projectile/neutron.lua"
#include "common/effects/projectile/giga_cannon.lua"
#include "common/effects/trail/default.lua"
#include "common/effects/trail/plasma.lua"
#include "common/effects/trail/neutron.lua"
#include "common/effects/trail/guided_missile.lua"
#include "common/effects/trail/guided_torpedo.lua"
#include "common/effects/guided/missile.lua"
#include "common/effects/guided/torpedo.lua"
#include "common/effects/craft/default.lua"
#include "common/effects/craft/engine.lua"
#include "common/effects/craft/launch.lua"
#include "common/effects/craft/recover.lua"
#include "common/effects/craft/subweapon_beam.lua"
#include "common/effects/craft/subweapon_muzzle.lua"
#include "common/effects/craft/subweapon_impact.lua"
#include "common/effects/beam/point_defense.lua"
#include "slots/t/render_state.lua"
#include "common/effects/registry/effect_dispatch.lua"

client = client or {}

function client.weaponClientInit()
    client.xSlotRenderStateInit()
    client.soundModuleInit()
    client.weaponFxInitAll()
end

function client.weaponClientTick(dt)
    client.weaponLoadoutSyncTick(dt)
    client.guidedTargetingTick(dt)
    client.chargedRayTargetingTick(dt)
    client.mainWeaponInputTick(dt)
    client.soundModuleTick(dt)
    client.weaponFxTickAll(dt)
    client.mainWeaponHudTick(dt)
end

function client.weaponClientRender()
    client.weaponFxRenderAll()
end

function client.weaponClientDrawHud()
    client.mainWeaponHudDraw()
    client.shipCrosshairDraw()
    client.guidedTargetingHudDraw()
    client.chargedRayLockHudDraw()
end
