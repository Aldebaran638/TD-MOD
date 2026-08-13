#version 2
#include "script/include/common.lua"

#include "data/components/component_catalog.lua"
#include "data/targets/external_targets.lua"
#include "data/ships/ship_catalog.lua"
#include "data/configuration/loadout_contract_v1.lua"
#include "data/catalog/catalog_authority_v1.lua"
#include "data/weapons/weapon_catalog.lua"
#include "net/server_sync_limiter.lua"
#include "net/network_debug.lua"
#include "net/world_protocol_v1.lua"
#include "net/world_command_snapshot_v1.lua"
#include "world/host/world_host_v1.lua"
#include "world/adapter/ship_instance_adapter_v1.lua"
#include "world/adapter/vehicle_instance_v1.lua"
#include "world/adapter/entity_graph_v1.lua"
#include "world/adapter/transform_anchor_v1.lua"
#include "world/adapter/transform_anchor_migration_v1.lua"
#include "world/adapter/vehicle_factory_v1.lua"
#include "world/adapter/vehicle_platform_cutover_v1.lua"
#include "weapon/server/behavior/point_defense/allocator_v1.lua"
#include "weapon/server/runtime/hotpath_budget_v1.lua"
#include "net/presentation_event_v1.lua"
#include "net/effect_runtime_authority.lua"
#include "net/presentation_publisher.lua"
#include "testing/ai_agent/telemetry.lua"
#include "ship/common/server/bootstrap.lua"
#include "ship/common/client/bootstrap.lua"

local configuredShipType = GetStringParam("shiptype", "advancedStrikeCraft")

function server.init()
    server.cm2TelemetryInit(false)
    cm2EffectRuntimeAuthority.init()
    cm2CatalogAuthorityV1.init()
    cm2HotpathBudgetV1.serverInit(cm2WorldHostV1.generation())
    server.presentationPublisherInit()
    -- Set this before shared initialization so a failed optional weapon module
    -- can never leave a strike craft with the full-size ship blast.
    server.shipDeathExplosionConfig.explosionSize = 4.0 * 0.20
    local strikeCraftBody = server.shipServerInit(configuredShipType)
    cm2VehicleInstanceV1.serverInit(
        "strike-craft:" .. configuredShipType .. ":" .. tostring(strikeCraftBody),
        configuredShipType,
        strikeCraftBody,
        "ship-owner:" .. tostring(strikeCraftBody),
        { "register", "heartbeat", "snapshotRead", "presentationPublish", "lifecycleRead" }
    )
    cm2EntityGraphV1.serverInit(
        cm2WorldHostV1.generation(),
        "strike-craft:" .. configuredShipType .. ":" .. tostring(strikeCraftBody),
        "ship-owner:" .. tostring(strikeCraftBody),
        { rootBodyId = strikeCraftBody, definitionId = configuredShipType }
    )
    cm2TransformAnchorV1.serverInit(
        cm2WorldHostV1.generation(),
        "strike-craft:" .. configuredShipType .. ":" .. tostring(strikeCraftBody),
        "ship-owner:" .. tostring(strikeCraftBody),
        { units = "meters", frame = "right-handed-y-up" }
    )
    cm2TransformAnchorMigrationV1.serverInit(
        cm2WorldHostV1.generation(),
        "strike-craft:" .. configuredShipType .. ":" .. tostring(strikeCraftBody),
        "ship-owner:" .. tostring(strikeCraftBody),
        { defaultMode = "legacy" }
    )
    cm2VehicleFactoryV1.serverInit(
        cm2WorldHostV1.generation(),
        "ship-owner:" .. tostring(strikeCraftBody),
        { mode = "legacy", maxInstances = 16 }
    )
    cm2VehiclePlatformCutoverV1.serverInit(
        cm2WorldHostV1.generation(),
        "strike-craft:" .. configuredShipType .. ":" .. tostring(strikeCraftBody),
        "ship-owner:" .. tostring(strikeCraftBody),
        { defaultMode = "legacy" }
    )
    cm2PointDefenseAllocatorV1.serverInit(cm2WorldHostV1.generation())
    cm2InterceptorRuntimeV1.serverInit(
        "interceptor:" .. tostring(strikeCraftBody),
        server.registryShipGetOwnerBody ~= nil
            and server.registryShipGetOwnerBody(strikeCraftBody) or 0,
        cm2WorldHostV1.generation(),
        { mode = "legacy", maxPerOwner = 4, maxGlobal = 24, thinkHz = 5, updateHz = 30 }
    )
    -- Strike craft use the same destruction path as ships, but their death
    -- blast is intentionally limited to 20% of the standard ship effect.
    server.shipDeathExplosionConfig.explosionSize = 4.0 * 0.20
end

function server.tick(dt)
    server.cm2TelemetryServerTick(dt)
    local destroyed = server.shipServerIsDestroyed()
    cm2VehicleInstanceV1.serverTick(dt, destroyed)
    if destroyed then
        server.shipServerFinalizeDestroyed()
        return
    end
    server.networkDebugTick(dt)
    cm2InterceptorRuntimeV1.serverTick(dt)
    server.shipServerTick(dt)
end

function server.update(dt)
    if server.shipServerIsDestroyed() then return end
    server.shipServerUpdate(dt)
end

function server.postUpdate()
    if server.shipServerIsDestroyed() then return end
    server.shipServerPostUpdate()
end

function client.init()
    cm2EffectRuntimeAuthority.init()
    cm2CatalogAuthorityV1.init()
    cm2ShipInstanceAdapterV1.clientInit("strike-craft:" .. configuredShipType)
    client.shipClientInit(configuredShipType)
end

function client.tick(dt)
    cm2ShipInstanceAdapterV1.clientTick(dt)
    client.presentationBudget.beginFrame(dt)
    if client.shipClientIsDestroyed() then
        client.shipClientDestroyedUiTick(dt)
        return
    end
    client.shipClientBeforeWeaponTick(dt)
    client.shipClientAfterWeaponTick(dt)
end

function client.draw()
    client.shipClientDrawHealth()
    client.shipClientDrawSensors()
    client.shipClientSuppressNativeHud()
end

function client.render()
    if client.shipClientIsDestroyed() then return end
    client.shipClientRender()
    client.shipClientRenderEffects()
end
