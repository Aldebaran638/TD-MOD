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
    -- Set this before shared initialization so a failed optional weapon module
    -- can never leave a strike craft with the full-size ship blast.
    server.shipDeathExplosionConfig.explosionSize = 4.0 * 0.20
    server.shipServerInit(configuredShipType)
    -- Strike craft use the same destruction path as ships, but their death
    -- blast is intentionally limited to 20% of the standard ship effect.
    server.shipDeathExplosionConfig.explosionSize = 4.0 * 0.20
end

function server.tick(dt)
    if server.shipServerIsDestroyed() then
        server.shipServerFinalizeDestroyed()
        return
    end
    server.networkDebugTick(dt)
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
    client.shipClientInit(configuredShipType)
end

function client.tick(dt)
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
