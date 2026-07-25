---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

function client.weaponConfigUiIsOpen()
    return GetBool("StellarisShips/client/weaponConfigUiOpen/" .. tostring(GetLocalPlayer() or 0))
end

#include "ship/battlecruiser/client/registry/ship_registry.lua"
#include "ship/battlecruiser/client/state/ship_runtime_state.lua"
#include "ship/battlecruiser/client/state/ship_runtime_state_api.lua"
#include "weapon/client/common/state/weapon_loadout.lua"
#include "weapon/client/slots/x/state/render_state.lua"
#include "weapon/client/slots/x/state/render_state_api.lua"
#include "weapon/client/slots/x/targeting/x_slot_targeting.lua"
#include "weapon/client/guided/targeting/guided_targeting.lua"
#include "weapon/client/common/input/main_weapon_input.lua"
#include "ship/battlecruiser/client/input/body_move_input.lua"
#include "weapon/client/common/sound/weapon_sound_catalog.lua"
#include "weapon/client/common/sound/sound_service.lua"
#include "ship/battlecruiser/client/camera/ship_camera.lua"
#include "ship/battlecruiser/client/hud/ship_roll_error.lua"
#include "ship/battlecruiser/client/hud/ship_health_bar.lua"
#include "weapon/client/common/hud/main_weapon_hud.lua"
#include "ship/battlecruiser/client/hud/ship_help_overlay.lua"
#include "weapon/client/common/hud/ship_crosshair.lua"
#include "weapon/client/guided/hud/guided_targeting_hud.lua"
#include "weapon/client/slots/x/hud/x_slot_lock_hud.lua"
#include "weapon/client/slots/x/tachyon_lance/effects/charging_fx.lua"
#include "weapon/client/slots/x/focused_arc_emitter/effects/charging_fx.lua"
#include "weapon/client/slots/x/tachyon_lance/effects/beam_fx.lua"
#include "weapon/client/slots/x/tachyon_lance/effects/muzzle_fx.lua"
#include "weapon/client/common/effects/shield_hit_fx.lua"
#include "weapon/client/common/effects/generic_raycast_fx.lua"
#include "weapon/client/slots/x/tachyon_lance/effects/impact_fx.lua"
#include "ship/battlecruiser/client/effects/ship_destroyed_fx.lua"
#include "ship/battlecruiser/client/effects/engine_thruster_fx.lua"
#include "weapon/client/slots/l/kinetic_artillery/effects/projectile_visual.lua"
#include "weapon/client/guided/effects/missile_impact_fx.lua"
#include "weapon/client/guided/effects/missile_visual.lua"
#include "weapon/client/guided/effects/missile_warp_fx.lua"
#include "weapon/client/slots/h/gamma_strike_craft/effects/beam_fx.lua"

function client.init()
    client.shipRuntimeStateInit()
    client.xSlotRenderStateInit()
    client.soundModuleInit()
    client.tachyonBeamFxInit()
    client.shipBody = FindBody("stellarisShip", false)
    client.engineThrusterFxInit()
    client.tachyonMuzzleFxInit()
    client.focusedArcChargingFxInit()
    client.genericRaycastFxInit()
end

function client.clientTick(dt)
    client.weaponLoadoutSyncTick(dt)
    client.guidedTargetingTick(dt)
    client.xSlotTargetingTick(dt)
    client.mainWeaponInputTick(dt)
    client.bodyMoveInputTick(dt)
    client.soundModuleTick(dt)

    client.tachyonChargingFxTick(dt)
    client.focusedArcChargingFxTick(dt)
    client.tachyonBeamFxTick(dt)
    client.tachyonMuzzleFxTick(dt)
    client.shieldHitFxTick(dt)
    client.tachyonImpactFxTick(dt)
    client.shipDestroyedFxTick(dt)
    client.engineThrusterFxTick(dt)
    client.projectileVisualTick(dt)
    client.missileVisualTick(dt)
    client.missileWarpFxTick(dt)
    client.hSlotBeamFxTick(dt)
    client.genericRaycastFxTick(dt)

    client.shipHealthBarTick(dt)
    client.mainWeaponHudTick(dt)
    client.shipHelpOverlayTick(dt)
end

function client.clientDraw()
    client.shipHealthBarDraw()
    client.mainWeaponHudDraw()
    client.shipHelpOverlayDraw()
    client.shipCrosshairDraw()
    client.guidedTargetingHudDraw()
    client.xSlotLockHudDraw()
end

function client.render()
    client.shipCameraTick(0)
    client.shipRollErrorTick(0)
    -- 更新导弹视觉效果
    client.missileVisualTick(0)
    client.hSlotBeamFxRender()
    client.tachyonBeamFxRender()
    client.tachyonMuzzleFxRender()
    client.focusedArcChargingFxRender()
    client.genericRaycastFxRender()
    client.engineThrusterFxRender()
end
