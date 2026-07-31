#version 2
#include "script/include/common.lua"

#include "data/components/component_catalog.lua"
#include "data/targets/external_targets.lua"
#include "data/ships/ship_catalog.lua"
#include "data/weapons/weapon_catalog.lua"
#include "net/server_sync_limiter.lua"
#include "net/network_debug.lua"
#include "ship/common/server/bootstrap.lua"
#include "ship/common/client/bootstrap.lua"

local configuredShipType = GetStringParam("shiptype", "advancedStrikeCraft")

function server.init()
    server.shipServerInit(configuredShipType)
    server.shipDeathExplosionConfig.explosionSize = 0.0
end

function server.tick(dt)
    server.networkDebugTick(dt)
    server.shipServerTick(dt)
end

function server.update(dt)
    server.shipServerUpdate(dt)
end

function server.postUpdate()
    server.shipServerPostUpdate()
end

function client.init()
    client.shipClientInit(configuredShipType)
end

function client.tick(dt)
    client.shipClientBeforeWeaponTick(dt)
    client.shipClientAfterWeaponTick(dt)
end

function client.draw()
    client.shipClientDrawHealth()
    client.shipClientDrawSensors()
    client.shipClientSuppressNativeHud()
end

function client.render()
    client.shipClientRender()
    client.shipClientRenderEffects()
end
