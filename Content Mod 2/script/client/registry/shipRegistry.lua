---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local registryShipRoot = "StellarisShips/server/ships/byId/"
local registryShipIndexRoot = "StellarisShips/server/ships/index"
local registryShipTypeRoot = "StellarisShips/server/definitions/ships/byType/"

local function _readVec3FromRegistry(prefix)
    return {
        x = GetFloat(prefix .. "/x"),
        y = GetFloat(prefix .. "/y"),
        z = GetFloat(prefix .. "/z"),
    }
end

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
function client.registryShipGetSnapshot(shipBodyId)
    if not client.registryShipExists(shipBodyId) then
        return nil
    end

    local prefix = client.registryShipKeyPrefix(shipBodyId)
    local snapshot = {
        id = shipBodyId,
        exists = GetBool(prefix .. "/exists"),
        shipType = GetString(prefix .. "/shipType"),
        maxShieldHP = GetFloat(prefix .. "/maxShieldHP"),
        maxArmorHP = GetFloat(prefix .. "/maxArmorHP"),
        maxBodyHP = GetFloat(prefix .. "/maxBodyHP"),
        shieldHP = GetFloat(prefix .. "/shieldHP"),
        armorHP = GetFloat(prefix .. "/armorHP"),
        bodyHP = GetFloat(prefix .. "/bodyHP"),
        driverPlayerId = GetInt(prefix .. "/driverPlayerId"),
        moveState = GetInt(prefix .. "/moveState"),
        moveRequest = GetInt(prefix .. "/move/request"),
        moveRequestState = GetInt(prefix .. "/move/requestState"),
        currentMainWeapon = GetString(prefix .. "/mainWeapon/current"),
        xSlotsRender = {
            seq = GetInt(prefix .. "/xSlots/render/seq"),
            shotId = GetInt(prefix .. "/xSlots/render/shotId"),
            eventType = GetString(prefix .. "/xSlots/render/eventType"),
            slotIndex = GetInt(prefix .. "/xSlots/render/slotIndex"),
            weaponType = GetString(prefix .. "/xSlots/render/weaponType"),
            serverTime = GetFloat(prefix .. "/xSlots/render/serverTime"),
            firePoint = _readVec3FromRegistry(prefix .. "/xSlots/render/firePoint"),
            hitPoint = _readVec3FromRegistry(prefix .. "/xSlots/render/hitPoint"),
            didHit = GetInt(prefix .. "/xSlots/render/didHit"),
            didHitStellarisBody = GetInt(prefix .. "/xSlots/render/didHitStellarisBody"),
            didHitShield = GetInt(prefix .. "/xSlots/render/didHitShield"),
            hitTargetBodyId = GetInt(prefix .. "/xSlots/render/hitTargetBodyId"),
            normal = _readVec3FromRegistry(prefix .. "/xSlots/render/normal"),
            impactLayer = GetString(prefix .. "/xSlots/render/impactLayer"),
        },
    }

    if snapshot.maxShieldHP <= 0 or snapshot.maxArmorHP <= 0 or snapshot.maxBodyHP <= 0 then
        local typeMaxShield, typeMaxArmor, typeMaxBody = _readShipTypeMaxHp(snapshot.shipType)
        if snapshot.maxShieldHP <= 0 then
            snapshot.maxShieldHP = typeMaxShield
        end
        if snapshot.maxArmorHP <= 0 then
            snapshot.maxArmorHP = typeMaxArmor
        end
        if snapshot.maxBodyHP <= 0 then
            snapshot.maxBodyHP = typeMaxBody
        end
    end

    if snapshot.maxShieldHP <= 0 then
        snapshot.maxShieldHP = snapshot.shieldHP or 0
    end
    if snapshot.maxArmorHP <= 0 then
        snapshot.maxArmorHP = snapshot.armorHP or 0
    end
    if snapshot.maxBodyHP <= 0 then
        snapshot.maxBodyHP = snapshot.bodyHP or 0
    end
    return snapshot
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

