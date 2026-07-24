---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

#include "ship/battlecruiser/client/registry/shipRegistry.lua"
#include "ship/battlecruiser/client/state/ship_runtime_state.lua"
#include "ship/battlecruiser/client/state/ship_runtime_state_api.lua"
#include "weapon/client/state/xslot_render_state.lua"
#include "weapon/client/state/xslot_render_state_api.lua"
#include "weapon/client/targeting/xSlotTargeting.lua"
#include "weapon/client/targeting/guidedTargeting.lua"
#include "weapon/client/input/mainWeaponInput.lua"
#include "ship/battlecruiser/client/input/bodyMoveInput.lua"
#include "weapon/client/sound/soundModule.lua"
#include "ship/battlecruiser/client/camera/shipCamera.lua"
#include "ship/battlecruiser/client/camera/shipRollError.lua"
#include "ship/battlecruiser/client/camera/shipHealthBar.lua"
#include "weapon/client/hud/mainWeaponHud.lua"
#include "ship/battlecruiser/client/camera/shipHelpOverlay.lua"
#include "weapon/client/hud/shipCrosshair.lua"
#include "weapon/client/hud/guidedTargetingHud.lua"
#include "weapon/client/hud/xSlotLockHud.lua"
#include "weapon/client/effects/xSlotChargingFx.lua"
#include "weapon/client/effects/xSlotLaunchFx.lua"
#include "weapon/client/effects/drawSpriteBeamTest.lua"
#include "weapon/client/effects/shieldHitFx.lua"
#include "weapon/client/effects/hitPointFx.lua"
#include "ship/battlecruiser/client/effects/shipDestroyedFx.lua"
#include "weapon/client/effects/projectileVisual.lua"
#include "weapon/client/effects/missileVisual.lua"
#include "weapon/client/effects/missileWarpFx.lua"
#include "weapon/client/effects/hSlotBeamFx.lua"

function client.init()
    client.shipRuntimeStateInit()
    client.xSlotRenderStateInit()
    client.soundModuleInit()
    client.drawSpriteBeamTestInit()
    client.shipBody = FindBody("stellarisShip", false)
end

function client.clientTick(dt)
    client.mainWeaponInputTick(dt)
    client.bodyMoveInputTick(dt)
    client.soundModuleTick(dt)

    client.xSlotChargingFxTick(dt)
    client.xSlotLaunchFxTick(dt)
    client.drawSpriteBeamTestTick(dt)
    client.shieldHitFxTick(dt)
    client.hitPointFxTick(dt)
    client.shipDestroyedFxTick(dt)
    client.projectileVisualTick(dt)
    client.missileVisualTick(dt)
    client.missileWarpFxTick(dt)
    client.hSlotBeamFxTick(dt)

    client.guidedTargetingTick(dt)
    client.xSlotTargetingTick(dt)
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
    client.drawSpriteBeamTestRender()
end
