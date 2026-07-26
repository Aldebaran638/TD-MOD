#version 2
#include "script/include/common.lua"

#include "script/data/ships/ship_catalog.lua"
#include "script/data/ships/battlecruiser.lua"
#include "script/data/weapons/weapon_catalog.lua"
#include "script/weapon/server/common/loadout/slot_loadout.lua"
#include "script/weapon/server/common/loadout/slot_loadout_api.lua"
#include "script/weapon/client/config_ui/weapon_config_ui.lua"

server = server or {}
client = client or {}

local function _isConfigurableShipType(shipType)
    return (shipTypeRegistryData or {})[tostring(shipType or "")] ~= nil
end

function server.weaponConfiguratorRequestTemplate(playerId, shipType)
    if IsPlayerValid ~= nil and not IsPlayerValid(playerId) then return false end
    if not _isConfigurableShipType(shipType) then return false end
    server.shipWeaponSyncSpawnTemplate(shipType, playerId)
    return true
end

function server.weaponConfiguratorSaveTemplate(playerId, shipType, configurationId, xWeapon, lWeapon, mWeapon, gWeapon, hWeapon)
    if IsPlayerValid ~= nil and not IsPlayerValid(playerId) then return false end
    if not _isConfigurableShipType(shipType) then return false end
    local ok, err = server.shipWeaponSetSpawnTemplate(shipType, configurationId, {
        X = tostring(xWeapon or ""),
        L = tostring(lWeapon or ""),
        M = tostring(mWeapon or ""),
        G = tostring(gWeapon or ""),
        H = tostring(hWeapon or ""),
    })
    if ok then server.shipWeaponSyncSpawnTemplate(shipType, playerId) end
    ClientCall(playerId, "client.weaponConfigUiApplyResult", ok and 1 or 0, tostring(err or ""))
    return ok
end

function client.weaponConfiguratorRequestTemplate(shipType)
    ServerCall("server.weaponConfiguratorRequestTemplate", GetLocalPlayer(), tostring(shipType or ""))
    return true
end

function client.weaponConfiguratorSaveTemplate(shipType, configurationId, loadout)
    local selected = loadout or {}
    ServerCall(
        "server.weaponConfiguratorSaveTemplate",
        GetLocalPlayer(),
        tostring(shipType or ""),
        tostring(configurationId or ""),
        tostring(selected.X or ""),
        tostring(selected.L or ""),
        tostring(selected.M or ""),
        tostring(selected.G or ""),
        tostring(selected.H or "")
    )
    return true
end

function client.init()
    client.weaponConfigUiSetOpen(false)
end

function client.tick(dt)
    if GetBool("level.stellarisships.weaponconfig.contenthost") then return end
    client.weaponConfigUiTick(dt)
end

function client.draw()
    if GetBool("level.stellarisships.weaponconfig.contenthost") then return end
    client.weaponConfigUiDraw()
end
