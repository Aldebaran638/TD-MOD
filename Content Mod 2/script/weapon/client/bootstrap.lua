---@diagnostic disable: undefined-global

#include "../shared/targeting/policy.lua"
#include "runtime/state/weapon_loadout.lua"
#include "interaction/targeting/target_catalog.lua"
#include "interaction/hud/radial_weapon_wheel.lua"
#include "slot/x/render_state.lua"
#include "slot/x/render_state_api.lua"
#include "behavior/charged_ray/targeting.lua"
#include "behavior/guided_projectile/targeting.lua"
#include "interaction/input/main_weapon_input.lua"
#include "presentation/audio/weapon_sound_catalog.lua"
#include "presentation/audio/sound_service.lua"
#include "presentation/event_runtime.lua"
#include "presentation/effect_player.lua"
#include "presentation/presentation_budget.lua"
#include "presentation/slice_runtime.lua"
#include "presentation/effect_lab.lua"
#include "interaction/hud/target_lock_reticle.lua"
#include "interaction/hud/main_weapon_hud.lua"
#include "interaction/hud/ship_crosshair.lua"
#include "behavior/guided_projectile/hud.lua"
#include "behavior/charged_ray/hud.lua"
#include "presentation/visual/runtime/registry/effect_profile_registry.lua"
#include "presentation/visual/runtime/registry/palette_profile_registry.lua"
#include "presentation/visual/runtime/shared/effect_budget.lua"
#include "presentation/visual/runtime/shared/effect_resources.lua"
#include "presentation/visual/runtime/shared/shield_hit.lua"
#include "presentation/visual/phase/beam/charged_helpers.lua"
#include "presentation/visual/phase/beam/gamma.lua"
#include "presentation/visual/phase/charge/default.lua"
#include "presentation/visual/phase/charge/tachyon_lance.lua"
#include "presentation/visual/phase/charge/focused_arc.lua"
#include "presentation/visual/phase/charge/perdition_beam.lua"
#include "presentation/visual/phase/beam/default.lua"
#include "presentation/visual/phase/beam/arc.lua"
#include "presentation/visual/phase/beam/tachyon_lance.lua"
#include "presentation/visual/phase/beam/perdition_beam.lua"
#include "presentation/visual/phase/muzzle/default.lua"
#include "presentation/visual/phase/muzzle/tachyon_lance.lua"
#include "presentation/visual/phase/muzzle/gamma.lua"
#include "presentation/visual/phase/muzzle/ballistic.lua"
#include "presentation/visual/phase/muzzle/guided.lua"
#include "presentation/visual/phase/impact/default.lua"
#include "presentation/visual/phase/impact/gamma.lua"
#include "presentation/visual/phase/impact/arc.lua"
#include "presentation/visual/phase/impact/ballistic.lua"
#include "presentation/visual/phase/impact/plasma.lua"
#include "presentation/visual/phase/impact/neutron.lua"
#include "presentation/visual/phase/impact/guided.lua"
#include "presentation/visual/phase/impact/tachyon_lance.lua"
#include "presentation/visual/phase/impact/perdition_beam.lua"
#include "presentation/visual/phase/projectile/default.lua"
#include "presentation/visual/phase/projectile/kinetic.lua"
#include "presentation/visual/phase/projectile/plasma.lua"
#include "presentation/visual/phase/projectile/autocannon.lua"
#include "presentation/visual/phase/projectile/neutron.lua"
#include "presentation/visual/phase/projectile/giga_cannon.lua"
#include "presentation/visual/phase/trail/default.lua"
#include "presentation/visual/phase/trail/plasma.lua"
#include "presentation/visual/phase/trail/neutron.lua"
#include "presentation/visual/phase/trail/guided_missile.lua"
#include "presentation/visual/phase/trail/guided_torpedo.lua"
#include "presentation/visual/phase/projectile/guided_missile.lua"
#include "presentation/visual/phase/projectile/guided_torpedo.lua"
#include "presentation/visual/entity/strike_craft/craft.lua"
#include "presentation/visual/entity/strike_craft/engine.lua"
#include "presentation/visual/entity/strike_craft/launch.lua"
#include "presentation/visual/entity/strike_craft/recover.lua"
#include "presentation/visual/entity/strike_craft/subweapon/beam.lua"
#include "presentation/visual/entity/strike_craft/subweapon/muzzle.lua"
#include "presentation/visual/entity/strike_craft/subweapon/impact.lua"
#include "presentation/visual/phase/beam/point_defense.lua"
#include "slot/t/render_state.lua"
#include "presentation/visual/runtime/registry/effect_dispatch.lua"

client = client or {}

function client.weaponClientInit()
    client.presentationSliceRuntimeInit()
    client.xSlotRenderStateInit()
    client.soundModuleInit()
    client.weaponFxInitAll()
end

function client.weaponClientTick(dt)
    client.weaponLoadoutSyncTick(dt)
    client.presentationSliceRuntimeTick(dt)
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
