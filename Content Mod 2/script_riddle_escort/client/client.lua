---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local escortBodyTag = "stellarisShip"

#include "registry/shipRegistry.lua"
#include "shipRuntimeState.lua"
#include "escortSSlotRenderState.lua"
#include "input_handling/mainWeaponInput.lua"
#include "input_handling/bodyMoveInput.lua"
#include "sound_modules/soundModule.lua"
#include "camera_modules/shipCamera.lua"
#include "camera_modules/shipRollError.lua"
#include "camera_modules/shipHealthBar.lua"
#include "camera_modules/mainWeaponHud.lua"
#include "camera_modules/shipHelpOverlay.lua"
#include "camera_modules/shipCrosshair.lua"
#include "draw_modules/escortSSlotLaunchFx.lua"
#include "draw_modules/shieldHitFx.lua"
#include "draw_modules/hitPointFx.lua"
#include "draw_modules/shipDestroyedFx.lua"
#include "draw_modules/projectileVisual.lua"
#include "draw_modules/missileVisual.lua"

function client.init()
    client.soundModuleInit()
    client.shipBody = FindBody(escortBodyTag, false)
end

function client.clientTick(dt)
    client.mainWeaponInputTick(dt)
    client.bodyMoveInputTick(dt)
    client.soundModuleTick(dt)
    client.escortSSlotLaunchFxTick(dt)
    client.shieldHitFxTick(dt)
    client.hitPointFxTick(dt)
    client.shipDestroyedFxTick(dt)
    client.projectileVisualTick(dt)
    client.missileVisualTick(dt)
    client.shipHealthBarTick(dt)
    client.mainWeaponHudTick(dt)
    client.shipHelpOverlayTick(dt)
end

function client.clientDraw()
    client.shipHealthBarDraw()
    client.mainWeaponHudDraw()
    client.shipHelpOverlayDraw()
    client.shipCrosshairDraw()
end

function client.render()
    client.shipCameraTick(0)
    client.shipRollErrorTick(0)
    client.missileVisualTick(0)
end
