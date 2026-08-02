#version 2
#include "script/include/common.lua"

#include "script/data/components/component_catalog.lua"
#include "script/data/ships/ship_catalog.lua"
#include "script/data/weapons/weapon_catalog.lua"
#include "script/map/space_battlefield.lua"
#include "script/weapon/client/config_ui/local_weapon_config.lua"
#include "script/weapon/client/config_ui/weapon_config_ui.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}
server = server or {}

function server.init()
    server.spaceBattlefieldInit()
end

function server.tick(dt)
    server.spaceBattlefieldTick(dt)
end

function client.init()
    SetBool("level.stellarisships.weaponconfig.contenthost", true)
    client.weaponConfigUiSetOpen(false)
    client.spaceBattlefieldInit()
end

function client.tick(dt)
    client.spaceBattlefieldTick(dt)
    client.weaponConfigUiTick(dt)
end

function client.draw()
    client.weaponConfigUiDraw()
end
