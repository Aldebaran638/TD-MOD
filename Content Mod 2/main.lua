#version 2
#include "script/include/common.lua"

#include "script/data/components/component_catalog.lua"
#include "script/data/ships/ship_catalog.lua"
#include "script/data/weapons/weapon_catalog.lua"
#include "script/net/world_protocol_v1.lua"
#include "script/net/world_command_snapshot_v1.lua"
#include "script/world/host/world_host_v1.lua"
#include "script/weapon/client/presentation/effect_player.lua"
#include "script/world/host/presentation_audio_host_v1.lua"
#include "script/world/host/registry_scheduler_damage_v1.lua"
#include "script/world/host/dense_entity_store_v1.lua"
#include "script/world/host/scene_target_catalog_v1.lua"
#include "script/map/space_battlefield.lua"
#include "script/weapon/client/interaction/config/local_weapon_config.lua"
#include "script/weapon/client/interaction/config/weapon_config_ui.lua"
#include "script/testing/ai_agent/telemetry.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}
server = server or {}

function server.init()
    server.cm2TelemetryInit(true)
    cm2WorldHostV1.serverInit("content-host", "scene-host-1")
    cm2RegistrySchedulerDamageV1.serverInit(cm2WorldHostV1.generation())
    cm2WorldMultiplayerV1.serverInit(cm2WorldHostV1.generation())
    cm2DenseEntityStoreV1.serverInit(cm2WorldHostV1.generation())
    cm2SceneTargetCatalogV1.serverInit(cm2WorldHostV1.generation(), "content-scene-1")
    server.spaceBattlefieldInit()
end

function server.tick(dt)
    server.cm2TelemetryServerTick(dt)
    cm2WorldHostV1.serverTick(dt)
    cm2RegistrySchedulerDamageV1.beginSnapshotCycle(cm2WorldHostV1.generation())
    cm2RegistrySchedulerDamageV1.freezeSnapshot()
    cm2RegistrySchedulerDamageV1.tickScheduler(dt)
    cm2DenseEntityStoreV1.tick(dt)
    cm2SceneTargetCatalogV1.tick(dt)
    server.spaceBattlefieldTick(dt)
end

function client.init()
    cm2WorldHostV1.clientInit()
    cm2SceneTargetCatalogV1.clientInit()
    cm2PresentationAudioHostV1.clientInit("content-host")
    SetBool("level.stellarisships.weaponconfig.contenthost", true)
    client.weaponConfigUiSetOpen(false)
    client.spaceBattlefieldInit()
    client.aiAgentTelemetryInit()
end

function client.tick(dt)
    cm2WorldHostV1.clientTick(dt)
    cm2PresentationAudioHostV1.clientTick(dt)
    client.spaceBattlefieldTick(dt)
    client.weaponConfigUiTick(dt)
    client.aiAgentTelemetryTick(dt)
end

function client.draw()
    client.weaponConfigUiDraw()
    client.aiAgentTelemetryDraw()
end
