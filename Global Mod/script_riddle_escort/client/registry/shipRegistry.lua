---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local registryShipRoot = "StellarisShips/server/ships/byId/"
local registryShipIndexRoot = "StellarisShips/server/ships/index"

local function _readShipTypeMaxHp(shipType)
    local defs = shipTypeRegistryData or {}
    local st = tostring(shipType or "")
    local definition = defs[st] or defs.riddle_escort or {}
    return tonumber(definition.maxShieldHP) or 0.0, tonumber(definition.maxArmorHP) or 0.0, tonumber(definition.maxBodyHP) or 0.0
end

function client.registryShipKeyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

function client.registryShipExists(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    return GetBool(client.registryShipKeyPrefix(shipBodyId) .. "/exists")
end

function client.registryShipGetRegisteredCount()
    local count = GetInt(registryShipIndexRoot .. "/count")
    if count < 0 then
        count = 0
    end
    return count
end

function client.registryShipGetRegisteredBodyIdAt(index)
    local i = math.floor(index or 0)
    if i <= 0 then
        return 0
    end
    return GetInt(registryShipIndexRoot .. "/" .. tostring(i) .. "/bodyId")
end

function client.registryShipGetRegisteredBodyIds()
    local ids = {}
    local count = client.registryShipGetRegisteredCount()
    for i = 1, count do
        local bodyId = client.registryShipGetRegisteredBodyIdAt(i)
        if bodyId ~= nil and bodyId ~= 0 then
            ids[#ids + 1] = bodyId
        end
    end
    return ids
end

function client.registryShipGetShipType(shipBodyId)
    if not client.registryShipExists(shipBodyId) then
        return ""
    end
    return GetString(client.registryShipKeyPrefix(shipBodyId) .. "/shipType")
end

function client.registryShipGetHP(shipBodyId)
    if not client.registryShipExists(shipBodyId) then
        return nil, nil, nil
    end
    local prefix = client.registryShipKeyPrefix(shipBodyId)
    return GetFloat(prefix .. "/shieldHP"), GetFloat(prefix .. "/armorHP"), GetFloat(prefix .. "/bodyHP")
end

function client.registryShipGetMaxHP(shipBodyId)
    if not client.registryShipExists(shipBodyId) then
        return nil, nil, nil
    end

    local shipType = client.registryShipGetShipType(shipBodyId)
    local maxShield, maxArmor, maxBody = _readShipTypeMaxHp(shipType)
    local shieldHP, armorHP, bodyHP = client.registryShipGetHP(shipBodyId)

    if maxShield <= 0 then
        maxShield = shieldHP or 0.0
    end
    if maxArmor <= 0 then
        maxArmor = armorHP or 0.0
    end
    if maxBody <= 0 then
        maxBody = bodyHP or 0.0
    end

    return maxShield, maxArmor, maxBody
end

function client.shipRequestMainWeaponFire(shipBodyId, request)
    if not client.registryShipExists(shipBodyId) then
        return false
    end
    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    local localPlayerId = GetLocalPlayer()
    ServerCall("server.shipRequestMainWeaponFire", localPlayerId, shipBodyId, value)
    return true
end

function client.shipRequestTWeaponHold(shipBodyId, active)
    if not client.registryShipExists(shipBodyId) then
        return false
    end

    local value = active and 1 or 0
    local localPlayerId = GetLocalPlayer()
    ServerCall("server.shipRequestTWeaponHold", localPlayerId, shipBodyId, value)
    return true
end

function client.shipRequestTWeaponRelease(shipBodyId)
    if not client.registryShipExists(shipBodyId) then
        return false
    end

    local localPlayerId = GetLocalPlayer()
    ServerCall("server.shipRequestTWeaponRelease", localPlayerId, shipBodyId)
    return true
end

function client.shipRequestSWeaponFire(shipBodyId, targetVehicleId)
    if not client.registryShipExists(shipBodyId) then
        return false
    end

    local vehicleId = math.floor(targetVehicleId or 0)
    if vehicleId <= 0 then
        return false
    end

    local localPlayerId = GetLocalPlayer()
    ServerCall("server.shipRequestSWeaponFire", localPlayerId, shipBodyId, vehicleId)
    return true
end

function client.shipRequestMainWeaponToggle(shipBodyId, request)
    if not client.registryShipExists(shipBodyId) then
        return false
    end
    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    local localPlayerId = GetLocalPlayer()
    ServerCall("server.shipRequestMainWeaponToggle", localPlayerId, shipBodyId, value)
    return true
end

function client.shipRequestMoveState(shipBodyId, moveState)
    if not client.registryShipExists(shipBodyId) then
        return false
    end

    local state = math.floor(moveState or 0)
    if state < 0 then
        state = 0
    end
    if state > 2 then
        state = 2
    end

    local localPlayerId = GetLocalPlayer()
    ServerCall("server.shipRequestMoveState", localPlayerId, shipBodyId, state)
    return true
end

function client.shipRequestRotationError(shipBodyId, pitchError, yawError)
    if not client.registryShipExists(shipBodyId) then
        return false
    end

    local pitchOut = pitchError or 0.0
    local yawOut = yawError or 0.0
    local localPlayerId = GetLocalPlayer()
    ServerCall("server.shipRequestRotationError", localPlayerId, shipBodyId, pitchOut, yawOut)
    return true
end

function client.shipRequestRollError(shipBodyId, rollError)
    if not client.registryShipExists(shipBodyId) then
        return false
    end

    local rollOut = tonumber(rollError) or 0.0
    if rollOut ~= rollOut or rollOut == math.huge or rollOut == -math.huge then
        rollOut = 0.0
    end

    local localPlayerId = GetLocalPlayer()
    ServerCall("server.shipRequestRollError", localPlayerId, shipBodyId, rollOut)
    return true
end
