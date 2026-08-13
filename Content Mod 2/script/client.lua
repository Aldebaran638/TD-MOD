---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

#include "net/presentation_event_v1.lua"
#include "net/world_protocol_v1.lua"
#include "net/effect_runtime_authority.lua"
#include "ship/common/client/bootstrap.lua"
#include "weapon/client/bootstrap.lua"

function client.init()
    cm2EffectRuntimeAuthority.init()
    cm2ShipInstanceAdapterV1.clientInit("ship:" .. tostring(configuredShipType or "ship"))
    local shipType = GetStringParam("shiptype", "")
    local bodyTag = GetStringParam("bodytag", "")
    if shipType == "" or bodyTag == "" then
        error("missing required ship script parameter: shiptype/bodytag")
    end
    client.shipClientInit(shipType, bodyTag)
    client.weaponClientInit()
end

function client.clientTick(dt)
    cm2ShipInstanceAdapterV1.clientTick(dt)
    client.presentationBudget.beginFrame(dt)
    if client.shipClientIsDestroyed() then
        client.shipClientDestroyedUiTick(dt)
        return
    end
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
