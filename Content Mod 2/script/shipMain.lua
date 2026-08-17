#version 2
#include "script/include/common.lua"

#include "data/catalog/catalog_authority_v1.lua"
#include "data/components/component_catalog.lua"
#include "data/targets/external_targets.lua"
#include "data/ships/ship_catalog.lua"
#include "data/configuration/loadout_contract_v1.lua"
#include "data/catalog/generated/vehicle_catalog_v1.lua"
#include "data/catalog/generated/weapon_catalog_v1.lua"
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
local configuredCatalogSource = GetStringParam("cm2_catalog_source", "candidate-v1")
local catalogAuthorityTelemetryRecorded = false
local configuredPresentationLoadout = GetStringParam("presentationLoadout", "")
local catalogObserverScenario = GetStringParam("cm2_catalog_observer", "")
    == "vehicle_component_catalog_v1"
local configuredPresentationLoadoutSlot = string.upper(
    GetStringParam("presentationLoadoutSlot", "X")
)
local destroyedControlsDisabled = false
local aiCandidateProjectionSyncTicks = 0
local aiCandidateRuntimeInitialized = false
local aiCandidateProjectionTelemetryRecorded = false

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

local function aiCandidateProjectionIsActive()
    local aiProjection = cm2AiWeaponRuntimeProjection
    if configuredBodyTag ~= "shipTitanAiCandidate"
        or aiProjection == nil
        or aiProjection.active == nil
        or not aiProjection.active() then
        return false
    end

    return true
end

local function applyAiCandidateLoadout(rebuildRuntime)
    if not aiCandidateProjectionIsActive() then return true, nil, false end

    local aiProjection = cm2AiWeaponRuntimeProjection
    local desiredWeapon = aiProjection.weaponType()
    local state = server.shipSlotLoadoutGetState(configuredShipType) or {}
    local loadout = state.loadout or {}
    local changed = tostring(loadout.M or "") ~= tostring(desiredWeapon)

    if changed then
        local applied, applyError = server.shipSlotLoadoutSetLoadout(
            configuredShipType,
            { M = desiredWeapon }
        )
        if not applied then return false, applyError, false end
    end

    local body = server.shipContextGetBody()
    local currentMode = server.shipRuntimeGetCurrentMainWeapon(body)
    if currentMode ~= "mSlot" then
        server.shipRuntimeSetCurrentMainWeapon(body, "mSlot")
        server.shipRuntimeSyncMainWeapon(body, true)
    end

    if changed and rebuildRuntime and aiCandidateRuntimeInitialized then
        server.weaponRuntimeRebuild(configuredShipType)
        server.shipRuntimeSetCurrentMainWeapon(body, "mSlot")
        server.shipRuntimeSyncMainWeapon(body, true)
    end

    server.shipWeaponSyncConfiguration(configuredShipType)
    return true, nil, changed
end

local function recordAiCandidateProjectionTelemetry()
    if aiCandidateProjectionTelemetryRecorded then
        return
    end
    if not aiCandidateProjectionIsActive() then
        return
    end
    local aiProjection = cm2AiWeaponRuntimeProjection
    if aiProjection == nil or aiProjection.getReport == nil then return end
    server.cm2TelemetryRecord("ai_candidate_runtime_projection", aiProjection.getReport())
    aiCandidateProjectionTelemetryRecorded = true
end

local function recordCatalogAuthorityTelemetry()
    if catalogAuthorityTelemetryRecorded then return end
    if server.cm2TelemetryRecord == nil then return end
    server.cm2TelemetryRecord("catalog_authority", cm2CatalogAuthorityV1.getReport())
    catalogAuthorityTelemetryRecorded = true
end

local function applyPresentationScenarioLoadout()
    if configuredBodyTag ~= "shipPresentationEnigmaPlayer"
        or configuredPresentationLoadout == ""
        or server.shipSlotLoadoutSetLoadout == nil then
        return true, nil
    end
    local modeBySlot = { X = "xSlot", M = "mSlot", P = "pSlot" }
    local mainWeaponMode = modeBySlot[configuredPresentationLoadoutSlot]
    if mainWeaponMode == nil then
        return false, "unsupported presentation loadout slot: "
            .. tostring(configuredPresentationLoadoutSlot)
    end
    local requestedLoadout = {}
    requestedLoadout[configuredPresentationLoadoutSlot] = configuredPresentationLoadout
    local applied, applyError = server.shipSlotLoadoutSetLoadout(
        configuredShipType,
        requestedLoadout
    )
    if not applied then return false, applyError end
    local shipBody = server.shipContextGetBody()
    server.shipRuntimeSetCurrentMainWeapon(shipBody, mainWeaponMode)
    server.shipRuntimeSyncMainWeapon(shipBody, true)
    -- The isolated presentation fixture owns its deterministic loadout for
    -- this spawn; reject the later local-config handshake from replacing it.
    server.weaponLocalConfigurationBound = true
    server.weaponLocalConfigurationPlayerId = nil
    return true, nil
end

server.cm2AiCandidateProjectionObserveWeapon = function(weaponType)
    local aiProjection = cm2AiWeaponRuntimeProjection
    if aiProjection == nil or aiProjection.weaponType == nil
        or tostring(weaponType or "") ~= tostring(aiProjection.weaponType()) then
        return
    end
    recordAiCandidateProjectionTelemetry()
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
    local aiProjection = cm2AiWeaponRuntimeProjection
    if configuredBodyTag == "shipTitanAiCandidate"
        and aiProjection ~= nil and aiProjection.activateForScenario ~= nil then
        aiProjection.activateForScenario("ai_weapon_candidate_preview")
    end
    server.cm2AiCandidateProjectionIsActive = aiCandidateProjectionIsActive
    server.cm2AiCandidateProjectionActive = aiCandidateProjectionIsActive()
    cm2EffectRuntimeAuthority.init()
    cm2CatalogAuthorityV1.init(configuredCatalogSource)
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
    local presentationLoadoutApplied, presentationLoadoutError =
        applyPresentationScenarioLoadout()
    if not presentationLoadoutApplied then
        error("presentation scenario loadout failed: " .. tostring(presentationLoadoutError or "unknown"))
    end
    if aiCandidateProjectionIsActive() then
        local applied, applyError = applyAiCandidateLoadout(false)
        if not applied then
            error("AI candidate loadout projection failed: " .. tostring(applyError or "unknown"))
        end
        recordAiCandidateProjectionTelemetry()
    end
    server.weaponRuntimeInit(configuredShipType)
    if catalogObserverScenario then
        -- The catalog scene observes registration and definitions. Disable
        -- unrelated automatic point-defense fire so low-HP interceptor
        -- fixtures remain stable long enough for the S1 snapshot.
        server.weaponRuntimeDeactivate()
    end
    aiCandidateRuntimeInitialized = true
    applyAiCandidateLoadout(true)
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
    recordAiCandidateProjectionTelemetry()
    if aiCandidateProjectionIsActive() and aiCandidateProjectionSyncTicks < 30 then
        local applied, applyError = applyAiCandidateLoadout(true)
        if not applied then
            error("AI candidate loadout resync failed: " .. tostring(applyError or "unknown"))
        end
        aiCandidateProjectionSyncTicks = aiCandidateProjectionSyncTicks + 1
    end
    server.cm2TelemetryServerTick(dt)
    recordCatalogAuthorityTelemetry()
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








