---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

#include "registry/shipRegistry.lua"
#include "shipRuntimeState.lua"
#include "xSlotRenderState.lua"
#include "targeting/sSlotTargeting.lua"
#include "input_handling/mainWeaponInput.lua"
#include "input_handling/bodyMoveInput.lua"
#include "sound_modules/soundModule.lua"
#include "camera_modules/shipCamera.lua"
#include "camera_modules/shipRollError.lua"
#include "camera_modules/shipHealthBar.lua"
#include "camera_modules/mainWeaponHud.lua"
#include "camera_modules/shipHelpOverlay.lua"
#include "camera_modules/shipCrosshair.lua"
#include "camera_modules/sSlotHud.lua"
#include "draw_modules/xSlotChargingFx.lua"
#include "draw_modules/xSlotLaunchFx.lua"
#include "draw_modules/shieldHitFx.lua"
#include "draw_modules/hitPointFx.lua"
#include "draw_modules/shipDestroyedFx.lua"
#include "draw_modules/projectileVisual.lua"

function client.init()
    client.soundModuleInit()
    client.shipBody = FindBody("stellarisShip", false)
end

function client.clientTick(dt)
    client.mainWeaponInputTick(dt)
    client.bodyMoveInputTick(dt)
    client.soundModuleTick(dt)

    client.xSlotChargingFxTick(dt)
    client.xSlotLaunchFxTick(dt)
    client.shieldHitFxTick(dt)
    client.hitPointFxTick(dt)
    client.shipDestroyedFxTick(dt)
    client.projectileVisualTick(dt)

    client.sSlotTargetingTick(dt)
    client.shipHealthBarTick(dt)
    client.mainWeaponHudTick(dt)
    client.shipHelpOverlayTick(dt)
end

function client.clientDraw()
    client.shipHealthBarDraw()
    client.mainWeaponHudDraw()
    client.shipHelpOverlayDraw()
    client.shipCrosshairDraw()
    client.sSlotHudDraw()
end

function client.render()
    client.shipCameraTick(0)
    client.shipRollErrorTick(0)
end
