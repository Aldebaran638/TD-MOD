---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

#include "ship/common/client/bootstrap.lua"
#include "weapon/client/bootstrap.lua"

function client.init()
    local shipType = GetStringParam("shiptype", "enigmaticCruiser")
    client.shipClientInit(shipType)
    client.weaponClientInit()
end

function client.clientTick(dt)
    if client.shipClientIsDestroyed() then
        client.shipClientDestroyedUiTick(dt)
        return
    end
    client.weaponFxBudgetBeginFrame(dt)
    client.shipClientBeforeWeaponTick(dt)
    client.weaponClientTick(dt)
    client.shipClientAfterWeaponTick(dt)
end

function client.clientDraw()
    client.shipClientDrawHealth()
    client.shipClientDrawSensors()
    client.mainWeaponHudDraw()
    client.shipClientDrawHelp()
    client.shipCrosshairDraw()
    client.guidedTargetingHudDraw()
    client.xSlotLockHudDraw()
    client.shipClientSuppressNativeHud()
end

function client.render()
    if client.shipClientIsDestroyed() then return end
    client.shipClientRender()
    client.weaponClientRender()
    client.shipClientRenderEffects()
end
