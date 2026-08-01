-- Titan standalone script entry
#version 2
#include "script/include/common.lua"

#include "server/ship_data.lua"
#include "server/weapon_data.lua"

#include "server/shipRuntimeState.lua"
#include "server/registry/shipRegistry.lua"
#include "server/registry/shipRegistryRequest.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

local titanShipType = "titan"
local titanBodyTag = "stellarisShip"
local destroyedControlsDisabled = false

local function _titanIsDestroyed()
    return server.shipBody ~= nil
        and server.shipBody ~= 0
        and server.registryShipExists(server.shipBody)
        and server.registryShipIsBodyDead(server.shipBody)
end

local function _titanDisableDestroyedControls()
    if destroyedControlsDisabled then return end
    server.mainWeaponRequestReset()
    server.tSlotStateResetRuntime()
    server.lSlotStateResetRuntime()
    server.sSlotStateResetRuntime()
    server.projectileManagerState.active = {}
    server.shipDeathExplosionTick(0.0)
    destroyedControlsDisabled = true
end

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

#include "server/weapon_fire/lSlotState.lua"
#include "server/weapon_fire/mainWeaponControl.lua"
#include "server/weapon_fire/tSlotState.lua"
#include "server/weapon_fire/tSlotRenderState.lua"
#include "server/weapon_fire/tSlotControl.lua"
#include "server/weapon_fire/lSlotControl.lua"
#include "server/weapon_fire/sSlotControl.lua"
#include "server/weapon_fire/projectileManager.lua"

#include "server/movement/bodyMassUpwardMove.lua"
#include "server/movement/bodyDirectionalMove.lua"
#include "server/movement/bodyMoveStateReceive.lua"
#include "server/movement/bodyVelocityQuadraticDamping.lua"
#include "server/movement/shipAttitudeController.lua"
#include "server/movement/shipRollStabilizer.lua"
#include "server/movement/shipDeathExplosion.lua"
#include "server/recovery/shipHpRecovery.lua"

function server.init()
    destroyedControlsDisabled = false
    server.shipBody = FindBody(titanBodyTag, false)
    SetBool("StellarisShips/debug/inputTestEnabled", false)

    server.registerCurrentShip(titanShipType)
    server.shipRuntimeStateInit(server.shipBody, titanShipType, server.defaultShipType)
    server.mainWeaponRequestInit()
    server.tSlotStateInit(titanShipType)
    server.tSlotRenderStateInit()
    server.lSlotStateInit(titanShipType)
    server.sSlotStateInit(titanShipType)
    local initialMode = "tSlot"
    if server.shipRuntimeSetCurrentMainWeapon ~= nil and server.mainWeaponResolvePreferredMode ~= nil then
        initialMode = server.mainWeaponResolvePreferredMode()
        server.shipRuntimeSetCurrentMainWeapon(server.shipBody, initialMode)
    end
    server.shipRuntimeSyncMainWeapon(server.shipBody, true)
    if initialMode == "lSlot" then
        server.lSlotStatePushHud(true)
    elseif initialMode == "tSlot" then
        server.tSlotStatePushHud(true)
    elseif initialMode == "mSlot" and server.sSlotControlSyncHud ~= nil then
        server.sSlotControlSyncHud()
    end
end

function server.serverTick(dt)
    if _titanIsDestroyed() then
        _titanDisableDestroyedControls()
        return
    end
    server.mainWeaponControlTick(dt)
    server.shipRuntimeStateSyncTick(dt)
    server.tSlotControlTick(dt)
    server.lSlotControlTick(dt)
    server.sSlotControlTick(dt)
    server.projectileManagerTick(dt)
    server.shipHpRecoveryTick(dt)
    server.shipDeathExplosionTick(dt)
    server.bodyMoveStateReceiveTick(dt)
    server.bodyMassUpwardMoveTick(dt)
    server.bodyDirectionalMoveTick(dt)
    server.bodyVelocityQuadraticDampingTick(dt)
end

function server.update(dt)
    if _titanIsDestroyed() then return end
    server.sSlotControlUpdate(dt)
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end

function server.postUpdate()
    if _titanIsDestroyed() then return end
    server.sSlotControlPostUpdate()
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
