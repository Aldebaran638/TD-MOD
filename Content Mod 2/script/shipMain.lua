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
#include "net/presentation_event_v1.lua"
#include "net/effect_runtime_authority.lua"
#include "net/presentation_publisher.lua"
#include "testing/ai_agent/telemetry.lua"
#include "ship/common/server/bootstrap.lua"
#include "weapon/server/bootstrap.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

local configuredShipType = GetStringParam("shiptype", "")
local configuredBodyTag = GetStringParam("bodytag", "")
local destroyedControlsDisabled = false

local function requireShipParameter(name, value)
    if value == nil or value == "" then
        error("missing required ship script parameter: " .. name)
    end
    return value
end

local function disableDestroyedControls()
    if destroyedControlsDisabled then return end
    server.weaponRuntimeClearCommands()
    server.weaponRuntimeDeactivate()
    server.shipServerFinalizeDestroyed()
    destroyedControlsDisabled = true
end

-- server = server or {}

-- -- registry 访问

-- x 槽控制模块位于独立的武器系统目录中。
-- 移动类模块：根据 body 质量施加竖直向上
-- 移动类模块：根据 W/S 输入施加前后推进
-- 移动类模块：接收客户moveState 更新
-- 移动类模块：始终施加与速度反向的平方阻
-- 移动类模根据 registry 中的姿态误差施加扭矩进行自动调

-- 服务端初始化
function server.init()
    server.cm2TelemetryInit(false)
    cm2EffectRuntimeAuthority.init()
    cm2CatalogAuthorityV1.init()
    cm2HotpathBudgetV1.serverInit(cm2WorldHostV1.generation())
    server.presentationPublisherInit()
    destroyedControlsDisabled = false
    requireShipParameter("shiptype", configuredShipType)
    requireShipParameter("bodytag", configuredBodyTag)
    -- -- 当前武器状
    -- -- "idle"      空闲
    -- -- "charging"  充能
    -- -- "launching" 发射
    -- server.weaponState = "idle"

    -- -- 上一帧武器状用于检测状态变化的第一
    -- server.weaponStateLastTick = "idle"

    -- -- 充能所需时间
    -- server.chargeTime = 20

    -- -- 发射持续时间
    -- server.launchTime = 0.2

    -- 初始化当前飞船
    local shipBody = server.shipServerInit(configuredShipType, configuredBodyTag)
    server.weaponRuntimeInit(configuredShipType)
    server.shipRuntimeSyncMainWeapon(shipBody, true)
    server.shipWeaponSyncConfiguration(configuredShipType)
    cm2VehicleInstanceV1.serverInit(
        "ship:" .. configuredShipType .. ":" .. tostring(shipBody),
        configuredShipType,
        shipBody,
        "ship-owner:" .. tostring(shipBody),
        { "register", "heartbeat", "snapshotRead", "presentationPublish", "lifecycleRead" }
    )
    cm2EntityGraphV1.serverInit(
        cm2WorldHostV1.generation(),
        "ship:" .. configuredShipType .. ":" .. tostring(shipBody),
        "ship-owner:" .. tostring(shipBody),
        { rootBodyId = shipBody, definitionId = configuredShipType }
    )
    cm2TransformAnchorV1.serverInit(
        cm2WorldHostV1.generation(),
        "ship:" .. configuredShipType .. ":" .. tostring(shipBody),
        "ship-owner:" .. tostring(shipBody),
        { units = "meters", frame = "right-handed-y-up" }
    )
    cm2TransformAnchorMigrationV1.serverInit(
        cm2WorldHostV1.generation(),
        "ship:" .. configuredShipType .. ":" .. tostring(shipBody),
        "ship-owner:" .. tostring(shipBody),
        { defaultMode = "legacy" }
    )
    cm2VehicleFactoryV1.serverInit(
        cm2WorldHostV1.generation(),
        "ship-owner:" .. tostring(shipBody),
        { mode = "legacy", maxInstances = 16 }
    )
    cm2VehiclePlatformCutoverV1.serverInit(
        cm2WorldHostV1.generation(),
        "ship:" .. configuredShipType .. ":" .. tostring(shipBody),
        "ship-owner:" .. tostring(shipBody),
        { defaultMode = "legacy" }
    )
    cm2PointDefenseAllocatorV1.serverInit(cm2WorldHostV1.generation())
    cm2ProjectileLifecycleV1.serverInit(cm2WorldHostV1.generation())
    cm2ProjectileShieldBroadphaseV1.serverInit(cm2WorldHostV1.generation())
    cm2GuidedCollisionBudgetV1.serverInit(cm2WorldHostV1.generation())

end

-- 在tick中使用到的变
-- server.weaponState 当前武器状"idle"/"charging"/"launching")
-- server.weaponStateLastTick 武器在上一帧的状用于检测状态变化的第一
-- server.chargeTime 飞船充能所需时间
-- server.launchTime 飞船发射持续时间
function server.serverTick(dt)
    server.cm2TelemetryServerTick(dt)
    local destroyed = server.shipServerIsDestroyed()
    cm2VehicleInstanceV1.serverTick(dt, destroyed)
    if destroyed then
        disableDestroyedControls()
        return
    end
    server.networkDebugTick(dt)
    -- server.ensureCurrentShipState(defaultShipType)
    server.weaponRuntimeCommandTick(dt)
    server.weaponRuntimeSimulationTick(dt)
    server.shipServerTick(dt)
    if server.shipServerIsDestroyed() then disableDestroyedControls() end
end

function server.update(dt)
    if server.shipServerIsDestroyed() then return end
    server.weaponRuntimeUpdate(dt)
    server.shipServerUpdate(dt)
end

function server.postUpdate()
    if server.shipServerIsDestroyed() then return end
    server.weaponRuntimePostUpdate()
    server.shipServerPostUpdate()
end

#include "client.lua"


-- 客户tick：只调用总控函数
function client.tick(dt)
    client.clientTick(dt)
end

function client.draw()
    client.clientDraw()
end

function server.tick(dt)
    server.serverTick(dt)

end








