#version 2
#include "script/include/common.lua"

#include "script/data/ships/ship_catalog.lua"
#include "script/data/weapons/weapon_catalog.lua"
#include "script/weapon/client/config_ui/local_weapon_config.lua"
#include "script/weapon/client/config_ui/weapon_config_ui.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

function client.init()
    SetBool("level.stellarisships.weaponconfig.contenthost", true)
    client.weaponConfigUiSetOpen(false)
end

function client.tick(dt)
    client.weaponConfigUiTick(dt)
end

function client.draw()
    client.weaponConfigUiDraw()
end
