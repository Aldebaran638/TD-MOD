---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local registryShipRoot = "StellarisShips/server/ships/byId/"
local registryShipIndexRoot = "StellarisShips/server/ships/index"
local registryShipTypeRoot = "StellarisShips/server/definitions/ships/byType/"

local function _readShipTypeMaxHp(shipType)
    local st = tostring(shipType or "")
    if st == "" then
        st = "enigmaticCruiser"
    end

    local typePrefix = registryShipTypeRoot .. st
    local maxShield = GetFloat(typePrefix .. "/maxShieldHP")
    local maxArmor = GetFloat(typePrefix .. "/maxArmorHP")
    local maxBody = GetFloat(typePrefix .. "/maxBodyHP")
    return maxShield, maxArmor, maxBody
end
function client.registryShipKeyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

-- 客户端函数：判断某艘飞船是否已注册到 Registry
function client.registryShipExists(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    return GetBool(client.registryShipKeyPrefix(shipBodyId) .. "/exists")
end

-- 客户端函数：读取当前已注册飞船数�?
function client.registryShipGetRegisteredCount()
    local count = GetInt(registryShipIndexRoot .. "/count")
    if count < 0 then
        count = 0
    end
    return count
end

-- 客户端函数：读取索引表中�?index 条飞�?bodyId�?-based�?
function client.registryShipGetRegisteredBodyIdAt(index)
    local i = math.floor(index or 0)
    if i <= 0 then
        return 0
    end
    return GetInt(registryShipIndexRoot .. "/" .. tostring(i) .. "/bodyId")
end

-- 客户端函数：读取所有已注册飞船 bodyId 列表
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

-- 客户端函数：读取某艘飞船的快照数据，用于调试或只读逻辑
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

    local prefix = client.registryShipKeyPrefix(shipBodyId)
    local shipType = GetString(prefix .. "/shipType")
    local maxShield = GetFloat(prefix .. "/maxShieldHP")
    local maxArmor = GetFloat(prefix .. "/maxArmorHP")
    local maxBody = GetFloat(prefix .. "/maxBodyHP")

    if maxShield <= 0 or maxArmor <= 0 or maxBody <= 0 then
        local typeMaxShield, typeMaxArmor, typeMaxBody = _readShipTypeMaxHp(shipType)
        if maxShield <= 0 then
            maxShield = typeMaxShield
        end
        if maxArmor <= 0 then
            maxArmor = typeMaxArmor
        end
        if maxBody <= 0 then
            maxBody = typeMaxBody
        end
    end

    local shieldHP, armorHP, bodyHP = client.registryShipGetHP(shipBodyId)
    if maxShield <= 0 then
        maxShield = shieldHP or 0
    end
    if maxArmor <= 0 then
        maxArmor = armorHP or 0
    end
    if maxBody <= 0 then
        maxBody = bodyHP or 0
    end

    return maxShield, maxArmor, maxBody
end

function client.registryShipGetDriverPlayerId(shipBodyId)
    if not client.registryShipExists(shipBodyId) then
        return 0
    end
    return GetInt(client.registryShipKeyPrefix(shipBodyId) .. "/driverPlayerId")
end

function client.registryShipGetCurrentMainWeapon(shipBodyId)
    if not client.registryShipExists(shipBodyId) then
        return "xSlot"
    end
    local mode = GetString(client.registryShipKeyPrefix(shipBodyId) .. "/mainWeapon/current")
    if mode ~= "lSlot" then
        mode = "xSlot"
    end
    return mode
end

-- 客户端函数：写入 x 槽统一 request 键（兼容旧签名，slotIndex 参数已忽略）
-- 客户端函数：明确语义�?xSlots 总请求写入接�?
function client.registryShipSetMainWeaponFireRequest(shipBodyId, request)
    if not client.registryShipExists(shipBodyId) then
        return false
    end
    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    local localPlayerId = GetLocalPlayer()
    ServerCall("server.registryShipRequestSetMainWeaponFireRequest", localPlayerId, shipBodyId, value)
    return true
end

function client.registryShipSetMainWeaponToggleRequest(shipBodyId, request)
    if not client.registryShipExists(shipBodyId) then
        return false
    end
    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    local localPlayerId = GetLocalPlayer()
    ServerCall("server.registryShipRequestSetMainWeaponToggleRequest", localPlayerId, shipBodyId, value)
    return true
end
-- 客户端函数：写入移动 request �?
function client.registryShipSetMoveRequestState(shipBodyId, moveState)
    if not client.registryShipExists(shipBodyId) then
        return false
    end
    local state = math.floor(moveState or 0)
    if state < 0 then state = 0 end
    if state > 2 then state = 2 end

    local localPlayerId = GetLocalPlayer()
    ServerCall("server.registryShipRequestSetMoveRequestState", localPlayerId, shipBodyId, state)
    return true
end


-- client request -> server write rotation error (pitch/yaw)
function client.registryShipSetRotationError(shipBodyId, pitchError, yawError)
    if not client.registryShipExists(shipBodyId) then
        return false
    end
    local pitchOut = pitchError or 0.0
    local yawOut = yawError or 0.0
    local localPlayerId = GetLocalPlayer()
    ServerCall(
        "server.registryShipRequestSetRotationError",
        localPlayerId,
        shipBodyId,
        pitchOut,
        yawOut
    )

    return true
end

-- client request -> server write roll error
function client.registryShipSetRollError(shipBodyId, rollError)
    if not client.registryShipExists(shipBodyId) then
        return false
    end

    local rollOut = tonumber(rollError) or 0.0
    if rollOut ~= rollOut or rollOut == math.huge or rollOut == -math.huge then
        rollOut = 0.0
    end

    local localPlayerId = GetLocalPlayer()
    ServerCall(
        "server.registryShipRequestSetRollError",
        localPlayerId,
        shipBodyId,
        rollOut
    )

    return true
end

