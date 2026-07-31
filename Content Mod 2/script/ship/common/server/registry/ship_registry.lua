---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local registryShipRoot = "StellarisShips/server/ships/byId/"
local registryShipIndexRoot = "StellarisShips/server/ships/index"

local function _shipKeyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

local function _resolveShipTypeDefinition(shipType, defaultShipType)
    local requestedShipType = shipType or defaultShipType
    local definition = shipDefinitionGet(requestedShipType, defaultShipType)
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

function server.registryShipUnregister(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then return end
    local prefix = _shipKeyPrefix(shipBodyId)
    SetBool(prefix .. "/exists", false, true)
    SetBool(prefix .. "/destroyed", true, true)
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
    SetFloat(prefix .. "/maxShieldHP", tonumber(definition.maxShieldHP) or 0.0, true)
    SetFloat(prefix .. "/maxArmorHP", tonumber(definition.maxArmorHP) or 0.0, true)
    SetFloat(prefix .. "/maxBodyHP", tonumber(definition.maxBodyHP) or 0.0, true)
    SetFloat(prefix .. "/shieldHardening", 0.0, true)
    SetFloat(prefix .. "/armorHardening", 0.0, true)
    SetBool(prefix .. "/destroyed", false, true)
end

function server.registryShipSetProtectionProfile(shipBodyId, profile, restoreFull)
    if not server.registryShipExists(shipBodyId) then return false end
    local prefix = _shipKeyPrefix(shipBodyId)
    local resolved = profile or {}
    local maxShield = math.max(0.0, tonumber(resolved.maxShieldHP) or 0.0)
    local maxArmor = math.max(0.0, tonumber(resolved.maxArmorHP) or 0.0)
    local maxBody = math.max(0.0, tonumber(resolved.maxBodyHP) or 0.0)
    SetFloat(prefix .. "/maxShieldHP", maxShield, true)
    SetFloat(prefix .. "/maxArmorHP", maxArmor, true)
    SetFloat(prefix .. "/maxBodyHP", maxBody, true)
    SetFloat(prefix .. "/shieldHardening",
        math.max(0.0, math.min(1.0, tonumber(resolved.shieldHardening) or 0.0)), true)
    SetFloat(prefix .. "/armorHardening",
        math.max(0.0, math.min(1.0, tonumber(resolved.armorHardening) or 0.0)), true)
    if restoreFull then
        SetFloat(prefix .. "/shieldHP", maxShield, true)
        SetFloat(prefix .. "/armorHP", maxArmor, true)
        SetFloat(prefix .. "/bodyHP", maxBody, true)
        SetBool(prefix .. "/destroyed", false, true)
    end
    return true
end

function server.registryShipGetMaxHP(shipBodyId)
    if not server.registryShipExists(shipBodyId) then return nil, nil, nil end
    local prefix = _shipKeyPrefix(shipBodyId)
    return GetFloat(prefix .. "/maxShieldHP"),
        GetFloat(prefix .. "/maxArmorHP"),
        GetFloat(prefix .. "/maxBodyHP")
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
        local _, definition = _resolveShipTypeDefinition(defaultShipType, server.shipContextGetType())
        return tonumber(definition.shieldRadius) or 0.0
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    local radius = GetFloat(prefix .. "/shieldRadius")
    if radius > 0 then
        return radius
    end

    local shipType = GetString(prefix .. "/shipType")
    local _, definition = _resolveShipTypeDefinition(shipType, defaultShipType or server.shipContextGetType())
    return tonumber(definition.shieldRadius) or 0.0
end

function server.registryShipSetHP(shipBodyId, shieldHP, armorHP, bodyHP)
    if not server.registryShipExists(shipBodyId) then
        return
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    local threshold = 0.01
    if shieldHP ~= nil then
        local nextShield = tonumber(shieldHP) or 0.0
        local oldShield = GetFloat(prefix .. "/shieldHP")
        if math.abs(oldShield - nextShield) >= threshold then
            SetFloat(prefix .. "/shieldHP", nextShield, true)
        end
    end
    if armorHP ~= nil then
        local nextArmor = tonumber(armorHP) or 0.0
        local oldArmor = GetFloat(prefix .. "/armorHP")
        if math.abs(oldArmor - nextArmor) >= threshold then
            SetFloat(prefix .. "/armorHP", nextArmor, true)
        end
    end
    if bodyHP ~= nil then
        local nextBody = tonumber(bodyHP) or 0.0
        local oldBody = GetFloat(prefix .. "/bodyHP")
        if math.abs(oldBody - nextBody) >= threshold then
            SetFloat(prefix .. "/bodyHP", nextBody, true)
        end
        if nextBody <= 0 and not GetBool(prefix .. "/destroyed") then
            SetBool(prefix .. "/destroyed", true, true)
        end
    end
end
