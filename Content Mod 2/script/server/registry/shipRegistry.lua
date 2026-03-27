---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

#include "../../data/ships/enigmaticCruiser.lua"

local registryShipRoot = "StellarisShips/server/ships/byId/"
local registryShipIndexRoot = "StellarisShips/server/ships/index"

local function _shipKeyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

local function _resolveShipTypeDefinition(shipType, defaultShipType)
    local requestedShipType = shipType or defaultShipType or "enigmaticCruiser"
    local defs = shipTypeRegistryData or {}
    local definition = defs[requestedShipType] or defs[defaultShipType] or defs.enigmaticCruiser or {}
    local resolvedShipType = definition.shipType or requestedShipType
    return resolvedShipType, definition
end

local function _ensureShipBodyIndexed(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local count = GetInt(registryShipIndexRoot .. "/count")
    for i = 1, count do
        if GetInt(registryShipIndexRoot .. "/" .. tostring(i) .. "/bodyId") == shipBodyId then
            return
        end
    end

    local nextIndex = count + 1
    SetInt(registryShipIndexRoot .. "/count", nextIndex, true)
    SetInt(registryShipIndexRoot .. "/" .. tostring(nextIndex) .. "/bodyId", shipBodyId, true)
end

function server.registryShipExists(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    return GetBool(_shipKeyPrefix(shipBodyId) .. "/exists")
end

function server.registryShipIsBodyDead(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return false
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    if GetBool(prefix .. "/destroyed") then
        return true
    end

    local bodyHP = GetFloat(prefix .. "/bodyHP")
    if bodyHP <= 0 then
        SetBool(prefix .. "/destroyed", true, true)
        return true
    end

    return false
end

function server.registryShipRegister(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local resolvedShipType, definition = _resolveShipTypeDefinition(shipType, defaultShipType)
    local prefix = _shipKeyPrefix(shipBodyId)

    SetBool(prefix .. "/exists", true, true)
    _ensureShipBodyIndexed(shipBodyId)
    SetString(prefix .. "/shipType", resolvedShipType, true)
    SetFloat(prefix .. "/shieldRadius", tonumber(definition.shieldRadius) or 0.0, true)
    SetFloat(prefix .. "/shieldHP", tonumber(definition.maxShieldHP) or 0.0, true)
    SetFloat(prefix .. "/armorHP", tonumber(definition.maxArmorHP) or 0.0, true)
    SetFloat(prefix .. "/bodyHP", tonumber(definition.maxBodyHP) or 0.0, true)
    SetBool(prefix .. "/destroyed", false, true)
end

function server.registryShipEnsure(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end

    if not server.registryShipExists(shipBodyId) then
        server.registryShipRegister(shipBodyId, shipType, defaultShipType)
    else
        local prefix = _shipKeyPrefix(shipBodyId)
        local resolvedShipType, definition = _resolveShipTypeDefinition(shipType, defaultShipType)
        local currentShipType = GetString(prefix .. "/shipType")
        if currentShipType == nil or currentShipType == "" then
            SetString(prefix .. "/shipType", resolvedShipType, true)
        end
        if GetFloat(prefix .. "/shieldRadius") <= 0 then
            SetFloat(prefix .. "/shieldRadius", tonumber(definition.shieldRadius) or 0.0, true)
        end
    end
    return true
end

function server.registryShipGetShipType(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return ""
    end
    return GetString(_shipKeyPrefix(shipBodyId) .. "/shipType")
end

function server.registryShipGetHP(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return nil, nil, nil
    end
    local prefix = _shipKeyPrefix(shipBodyId)
    return GetFloat(prefix .. "/shieldHP"), GetFloat(prefix .. "/armorHP"), GetFloat(prefix .. "/bodyHP")
end

function server.registryShipGetShieldRadius(shipBodyId, defaultShipType)
    if not server.registryShipExists(shipBodyId) then
        local _, definition = _resolveShipTypeDefinition(defaultShipType, server.defaultShipType)
        return tonumber(definition.shieldRadius) or 0.0
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    local radius = GetFloat(prefix .. "/shieldRadius")
    if radius > 0 then
        return radius
    end

    local shipType = GetString(prefix .. "/shipType")
    local _, definition = _resolveShipTypeDefinition(shipType, defaultShipType or server.defaultShipType)
    return tonumber(definition.shieldRadius) or 0.0
end

function server.registryShipSetHP(shipBodyId, shieldHP, armorHP, bodyHP)
    if not server.registryShipExists(shipBodyId) then
        return
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    if shieldHP ~= nil then
        SetFloat(prefix .. "/shieldHP", shieldHP, true)
    end
    if armorHP ~= nil then
        SetFloat(prefix .. "/armorHP", armorHP, true)
    end
    if bodyHP ~= nil then
        SetFloat(prefix .. "/bodyHP", bodyHP, true)
        if bodyHP <= 0 then
            SetBool(prefix .. "/destroyed", true, true)
        end
    end
end
