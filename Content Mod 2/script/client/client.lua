---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

#include "registry/shipRegistry.lua"
#include "sound_modules/shipSound.lua"
#include "camera_modules/shipCamera.lua"
#include "camera_modules/shipRollError.lua"
#include "camera_modules/shipHealthBar.lua"
#include "camera_modules/shipCrosshair.lua"
#include "draw_modules/xSlotChargingFx.lua"
#include "draw_modules/xSlotLaunchFx.lua"
#include "draw_modules/shieldHitFx.lua"
#include "draw_modules/hitPointFx.lua"

function client.init()
    client.shipSoundInit()
    client.shipBody = FindBody("stellarisShip", false)
end

function client.clientTick(dt)
    client.shipSoundTick(client.shipBody)

    client.xSlotChargingFxTick(dt)
    client.xSlotLaunchFxTick(dt)
    client.shieldHitFxTick(dt)
    client.hitPointFxTick(dt)

    client.shipHealthBarTick(dt)
end

function client.clientDraw()
    client.shipHealthBarDraw()
    client.shipCrosshairDraw()
end

function client.render()
    client.shipCameraTick(0)
    client.shipRollErrorTick(0)
end
