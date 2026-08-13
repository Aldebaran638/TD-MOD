-- Riddle escort standalone script entry
#version 2
#include "script/include/common.lua"
#include "../script/net/world_protocol_v1.lua"
#include "../script/net/world_command_snapshot_v1.lua"
#include "../script/world/host/world_host_v1.lua"
#include "../script/world/adapter/ship_instance_adapter_v1.lua"
#include "../script/weapon/server/behavior/point_defense/allocator_v1.lua"

#include "server/ship_data.lua"
#include "server/weapon_data.lua"

#include "server/shipRuntimeState.lua"
#include "server/registry/shipRegistry.lua"
#include "server/registry/shipRegistryRequest.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

local escortShipType = "riddle_escort"
local escortBodyTag = "stellarisShip"

function server.registerCurrentShip(shipType)
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    server.registryShipRegister(shipBodyId, shipType, server.defaultShipType)
    return true
end

function server.ensureCurrentShipState(shipType)
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    return server.registryShipEnsure(shipBodyId, shipType or server.defaultShipType, server.defaultShipType)
end

#include "server/weapon_fire/mainWeaponControl.lua"
#include "server/weapon_fire/escortSSlotState.lua"
#include "server/weapon_fire/escortSSlotRenderState.lua"
#include "server/weapon_fire/escortSSlotControl.lua"
#include "server/weapon_fire/escortPSlotState.lua"
#include "server/weapon_fire/escortPProjectileManager.lua"
#include "server/weapon_fire/escortPSlotControl.lua"
#include "server/weapon_fire/escortGSlotControl.lua"

#include "server/movement/bodyMassUpwardMove.lua"
#include "server/movement/bodyDirectionalMove.lua"
#include "server/movement/bodyMoveStateReceive.lua"
#include "server/movement/bodyVelocityQuadraticDamping.lua"
#include "server/movement/shipAttitudeController.lua"
#include "server/movement/shipRollStabilizer.lua"
#include "server/movement/shipDeathExplosion.lua"
#include "server/recovery/shipHpRecovery.lua"

function server.init()
    server.shipBody = FindBody(escortBodyTag, false)
    SetBool("StellarisShips/debug/inputTestEnabled", false)

    server.registerCurrentShip(escortShipType)
    server.shipRuntimeStateInit(server.shipBody, escortShipType, server.defaultShipType)
    server.mainWeaponRequestInit()
    server.escortSSlotStateInit(escortShipType)
    server.escortSSlotRenderStateInit()
    server.escortPSlotStateInit(escortShipType)
    server.escortGSlotStateInit(escortShipType)

    local initialMode = "sSlot"
    if server.shipRuntimeSetCurrentMainWeapon ~= nil and server.mainWeaponResolvePreferredMode ~= nil then
        initialMode = server.mainWeaponResolvePreferredMode()
        server.shipRuntimeSetCurrentMainWeapon(server.shipBody, initialMode)
    end
    server.shipRuntimeSyncMainWeapon(server.shipBody, true)
    cm2ShipInstanceAdapterV1.serverInit(
        "escort:" .. tostring(server.shipBody),
        { "register", "heartbeat", "snapshotRead", "presentationPublish", "lifecycleRead" },
        "ship-owner:" .. tostring(server.shipBody)
    )
    cm2PointDefenseAllocatorV1.serverInit(cm2WorldHostV1.generation())

    if initialMode == "sSlot" then
        server.escortSSlotStatePushHud(true)
    elseif initialMode == "pSlot" then
        server.escortPSlotStatePushHud(true)
    elseif initialMode == "gSlot" then
        server.escortGSlotControlSyncHud(true)
    end
end

function server.serverTick(dt)
    local destroyed = server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(server.shipBody)
    cm2ShipInstanceAdapterV1.serverTick(dt, destroyed)
    server.mainWeaponControlTick(dt)
    server.shipRuntimeStateSyncTick(dt)
    server.escortSSlotControlTick(dt)
    server.escortPSlotControlTick(dt)
    server.escortGSlotControlTick(dt)
    server.escortPProjectileManagerTick(dt)
    server.shipHpRecoveryTick(dt)
    server.shipDeathExplosionTick(dt)
    server.bodyMoveStateReceiveTick(dt)
    server.bodyMassUpwardMoveTick(dt)
    server.bodyDirectionalMoveTick(dt)
    server.bodyVelocityQuadraticDampingTick(dt)
end

function server.update(dt)
    server.escortGSlotControlUpdate(dt)
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end

function server.postUpdate()
    server.escortGSlotControlPostUpdate()
end

#include "client/client.lua"

function client.tick(dt)
    client.clientTick(dt)
end

function client.draw()
    client.clientDraw()
end

function server.tick(dt)
    server.serverTick(dt)
end
