---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.presentationRuntimeDisposed = false

#include "net/presentation_event_v1.lua"
#include "net/world_protocol_v1.lua"
#include "net/effect_runtime_authority.lua"
#include "ship/common/client/bootstrap.lua"
#include "weapon/client/bootstrap.lua"

function client.init()
    cm2EffectRuntimeAuthority.init()
    cm2CatalogAuthorityV1.init(GetStringParam("cm2_catalog_source", "candidate-v1"))
    if client.cm2TelemetryInit ~= nil then client.cm2TelemetryInit() end
    cm2ShipInstanceAdapterV1.clientInit("ship:" .. tostring(configuredShipType or "ship"))
    local shipType = GetStringParam("shiptype", "")
    local bodyTag = GetStringParam("bodytag", "")
    if shipType == "" or bodyTag == "" then
        error("missing required ship script parameter: shiptype/bodytag")
    end
    client.shipClientInit(shipType, bodyTag)
    client.presentationRuntimeDisposed = false
    local aiProjection = cm2AiWeaponRuntimeProjection
    if bodyTag == "shipTitanAiCandidate"
        and aiProjection ~= nil and aiProjection.activateForScenario ~= nil then
        aiProjection.activateForScenario("ai_weapon_candidate_preview")
        client.updateShipWeaponGroupConfiguration(
            client.shipContextGetBody(),
            "mSlot",
            aiProjection.weaponType()
        )
    end
    client.weaponClientInit()
end

function client.clientTick(dt)
    cm2ShipInstanceAdapterV1.clientTick(dt)
    client.presentationBudget.beginFrame(dt, "client.clientTick")
    if client.shipClientIsDestroyed() then
        if not client.presentationRuntimeDisposed
            and client.presentationSliceRuntimeDisposeAll ~= nil then
            client.presentationSliceRuntimeDisposeAll()
            client.presentationRuntimeDisposed = true
        end
        client.shipClientDestroyedUiTick(dt)
        return
    end
    client.presentationRuntimeDisposed = false
    client.shipClientBeforeWeaponTick(dt)
    client.weaponClientTick(dt)
    client.shipClientAfterWeaponTick(dt)
    client.presentationBudget.publishTelemetry(
        "StellarisShips/testing/presentationBudget/",
        client.shipContextGetBody()
    )
end

function client.destroy()
    if client.presentationSliceRuntimeDisposeAll ~= nil then
        client.presentationSliceRuntimeDisposeAll()
    end
    client.presentationRuntimeDisposed = true
    if client.presentationBudget.sceneReload ~= nil then client.presentationBudget.sceneReload() end
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
    client.presentationBudget.publishTelemetry(
        "StellarisShips/testing/presentationBudget/",
        client.shipContextGetBody()
    )
end
