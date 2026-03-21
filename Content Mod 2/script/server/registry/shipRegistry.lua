---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

#include "../../data/ships/enigmaticCruiser.lua"
#include "../../data/weapons/xSlots/tachyonLance.lua"

local registryShipRoot = "StellarisShips/server/ships/byId/"
local registryShipIndexRoot = "StellarisShips/server/ships/index"
local registryShipTypeRoot = "StellarisShips/server/definitions/ships/byType/"
local registryXSlotWeaponTypeRoot = "StellarisShips/server/definitions/weapons/xSlots/byType/"

local function _shipKeyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

local function _shipTypeKeyPrefix(shipType)
    return registryShipTypeRoot .. tostring(shipType)
end

local function _xSlotWeaponTypeKeyPrefix(weaponType)
    return registryXSlotWeaponTypeRoot .. tostring(weaponType)
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

local function _normalizeSlotIndex(slotIndex)
    return math.max(1, math.floor(slotIndex or 1))
end

local function _resolveShipTypeDefinition(shipType, defaultShipType)
    local requestedShipType = shipType or defaultShipType or "enigmaticCruiser"
    local defs = shipTypeRegistryData or {}
    local definition = defs[requestedShipType] or defs[defaultShipType] or defs.enigmaticCruiser or {}
    local resolvedShipType = definition.shipType or requestedShipType
    return resolvedShipType, definition
end

local function _resolveXSlotWeaponTypeDefinition(weaponType)
    local requestedWeaponType = weaponType or "tachyonLance"
    local defs = xSlotWeaponRegistryData or {}
    local definition = defs[requestedWeaponType] or defs.tachyonLance or {}
    local resolvedWeaponType = definition.weaponType or requestedWeaponType
    return resolvedWeaponType, definition
end

local function _readVec3FromRegistry(prefix)
    return {
        x = GetFloat(prefix .. "/x"),
        y = GetFloat(prefix .. "/y"),
        z = GetFloat(prefix .. "/z"),
    }
end

local function _writeVec3ToRegistry(prefix, vec3)
    local v = vec3

    local function _getComp(obj, namedKey, indexKey)
        if obj == nil then
            return 0
        end

        local namedVal = nil
        local okNamed, resultNamed = pcall(function()
            return obj[namedKey]
        end)
        if okNamed then
            namedVal = resultNamed
        end
        if namedVal ~= nil then
            return namedVal
        end

        local indexedVal = nil
        local okIndexed, resultIndexed = pcall(function()
            return obj[indexKey]
        end)
        if okIndexed then
            indexedVal = resultIndexed
        end
        if indexedVal ~= nil then
            return indexedVal
        end

        return 0
    end

    SetFloat(prefix .. "/x", _getComp(v, "x", 1), true)
    SetFloat(prefix .. "/y", _getComp(v, "y", 2), true)
    SetFloat(prefix .. "/z", _getComp(v, "z", 3), true)
end

-- 武器类型是否已注册（xSlots 域）
function server.registryXSlotWeaponTypeRegistered(weaponType)
    if weaponType == nil or weaponType == "" then
        return false
    end
    return GetBool(_xSlotWeaponTypeKeyPrefix(weaponType) .. "/registered")
end

-- 注册单个 xSlots 武器类型定义（同类型只注册一次）
function server.registryRegisterXSlotWeaponType(weaponType)
    local resolvedWeaponType, definition = _resolveXSlotWeaponTypeDefinition(weaponType)
    local prefix = _xSlotWeaponTypeKeyPrefix(resolvedWeaponType)

    SetBool(prefix .. "/registered", true, true)
    SetString(prefix .. "/weaponType", definition.weaponType or resolvedWeaponType, true)
    SetString(prefix .. "/domain", "xSlots", true)
    SetFloat(prefix .. "/maxRange", definition.maxRange or 0, true)
    SetFloat(prefix .. "/damageMin", definition.damageMin or 0, true)
    SetFloat(prefix .. "/damageMax", definition.damageMax or 0, true)
    SetFloat(prefix .. "/shieldFix", definition.shieldFix or 1, true)
    SetFloat(prefix .. "/armorFix", definition.armorFix or 1, true)
    SetFloat(prefix .. "/bodyFix", definition.bodyFix or 1, true)
    SetFloat(prefix .. "/cooldown", definition.cooldown or 0, true)
    SetFloat(prefix .. "/chargeDuration", definition.chargeDuration or 0, true)
    SetFloat(prefix .. "/launchDuration", definition.launchDuration or 0, true)
    SetFloat(prefix .. "/randomTrajectoryAngle", definition.randomTrajectoryAngle or 0, true)
end

-- 确保 xSlots 武器类型定义已注册
function server.registryEnsureXSlotWeaponTypeRegistered(weaponType)
    local resolvedWeaponType = weaponType or "tachyonLance"
    if not server.registryXSlotWeaponTypeRegistered(resolvedWeaponType) then
        server.registryRegisterXSlotWeaponType(resolvedWeaponType)
    end
    return true
end

-- 飞船类型是否已注册
function server.registryShipTypeRegistered(shipType)
    if shipType == nil or shipType == "" then
        return false
    end
    return GetBool(_shipTypeKeyPrefix(shipType) .. "/registered")
end

-- 注册单个飞船类型定义（同类型只注册一次）
function server.registryRegisterShipType(shipType, defaultShipType)
    local resolvedShipType, definition = _resolveShipTypeDefinition(shipType, defaultShipType)
    local prefix = _shipTypeKeyPrefix(resolvedShipType)
    local xSlots = definition.xSlots or {}
    local xSlotCount = #xSlots
    if xSlotCount <= 0 then
        xSlotCount = definition.xSlotNum or 1
    end

    SetBool(prefix .. "/registered", true, true)
    SetString(prefix .. "/shipType", definition.shipType or resolvedShipType, true)
    SetFloat(prefix .. "/maxShieldHP", definition.maxShieldHP or 0, true)
    SetFloat(prefix .. "/maxArmorHP", definition.maxArmorHP or 0, true)
    SetFloat(prefix .. "/maxBodyHP", definition.maxBodyHP or 0, true)
    SetFloat(prefix .. "/shieldRadius", definition.shieldRadius or 0, true)
    SetInt(prefix .. "/xSlots/count", xSlotCount, true)

    for i = 1, xSlotCount do
        local slotDef = xSlots[i] or {}
        local weaponType = slotDef.weaponType or "tachyonLance"
        local slotPrefix = prefix .. "/xSlots/" .. tostring(i)

        SetString(slotPrefix .. "/weaponType", weaponType, true)
        _writeVec3ToRegistry(slotPrefix .. "/mount/firePosOffset", slotDef.firePosOffset)
        _writeVec3ToRegistry(slotPrefix .. "/mount/fireDirRelative", slotDef.fireDirRelative)

        server.registryEnsureXSlotWeaponTypeRegistered(weaponType)
    end
end

-- 确保飞船类型定义已注册，并联动确保其挂载的武器类型也已注册
function server.registryEnsureShipTypeRegistered(shipType, defaultShipType)
    local resolvedShipType = select(1, _resolveShipTypeDefinition(shipType, defaultShipType))
    if not server.registryShipTypeRegistered(resolvedShipType) then
        server.registryRegisterShipType(resolvedShipType, defaultShipType)
    end
    return true
end

function server.registryShipExists(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    return GetBool(_shipKeyPrefix(shipBodyId) .. "/exists")
end

function server.registryShipGetRotationError(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0.0, 0.0
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    return GetFloat(prefix .. "/pitchError"), GetFloat(prefix .. "/yawError")
end

function server.registryShipSetRotationError(shipBodyId, pitchError, yawError)
    if not server.registryShipExists(shipBodyId) then
        return
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    SetFloat(prefix .. "/pitchError", pitchError or 0.0, true)
    SetFloat(prefix .. "/yawError", yawError or 0.0, true)
end

function server.registryShipGetRollError(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0.0
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    return GetFloat(prefix .. "/rollError")
end

function server.registryShipSetRollError(shipBodyId, rollError)
    if not server.registryShipExists(shipBodyId) then
        return
    end

    local value = tonumber(rollError) or 0.0
    if value ~= value or value == math.huge or value == -math.huge then
        value = 0.0
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    SetFloat(prefix .. "/rollError", value, true)
end

function server.registryShipRegister(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end
    local resolvedShipType = shipType or defaultShipType or "enigmaticCruiser"
    server.registryEnsureShipTypeRegistered(resolvedShipType, defaultShipType)

    local typePrefix = _shipTypeKeyPrefix(resolvedShipType)
    local prefix = _shipKeyPrefix(shipBodyId)

    SetBool(prefix .. "/exists", true, true)
    _ensureShipBodyIndexed(shipBodyId)
    SetString(prefix .. "/shipType", GetString(typePrefix .. "/shipType"), true)
    SetFloat(prefix .. "/shieldHP", GetFloat(typePrefix .. "/maxShieldHP"), true)
    SetFloat(prefix .. "/armorHP", GetFloat(typePrefix .. "/maxArmorHP"), true)
    SetFloat(prefix .. "/bodyHP", GetFloat(typePrefix .. "/maxBodyHP"), true)

    SetInt(prefix .. "/driverPlayerId", 0, true)
    SetInt(prefix .. "/moveState", 0, true)
    SetInt(prefix .. "/move/request", 0, true)
    SetInt(prefix .. "/move/requestState", 0, true)
    -- 姿态误差（由控制器/客户端写入）
    SetFloat(prefix .. "/pitchError", 0.0, true)
    SetFloat(prefix .. "/yawError", 0.0, true)
    SetFloat(prefix .. "/rollError", 0.0, true)
    local xSlotCount = GetInt(typePrefix .. "/xSlots/count")
    if xSlotCount <= 0 then
        xSlotCount = 1
    end

    SetInt(prefix .. "/xSlots/count", xSlotCount, true)
    SetInt(prefix .. "/xSlots/request", 0, true)
    SetInt(prefix .. "/xSlots/writeSeq", -1, true)
    SetInt(prefix .. "/xSlots/lastReadSeq", -1, true)

    -- x 槽渲染事件区：用于服务端写入“最新一次状态变化/发射结果”，供客户端拉取渲染
    SetInt(prefix .. "/xSlots/render/seq", 0, true)
    SetInt(prefix .. "/xSlots/render/shotId", 0, true)
    SetString(prefix .. "/xSlots/render/eventType", "idle", true)
    SetInt(prefix .. "/xSlots/render/slotIndex", 1, true)
    SetString(prefix .. "/xSlots/render/weaponType", "", true)
    SetFloat(prefix .. "/xSlots/render/serverTime", 0, true)
    _writeVec3ToRegistry(prefix .. "/xSlots/render/firePoint", { x = 0, y = 0, z = 0 })
    _writeVec3ToRegistry(prefix .. "/xSlots/render/hitPoint", { x = 0, y = 0, z = 0 })
    SetInt(prefix .. "/xSlots/render/didHit", 0, true)
    SetInt(prefix .. "/xSlots/render/didHitStellarisBody", 0, true)
    SetInt(prefix .. "/xSlots/render/didHitShield", 0, true)
    SetInt(prefix .. "/xSlots/render/hitTargetBodyId", 0, true)
    _writeVec3ToRegistry(prefix .. "/xSlots/render/normal", { x = 0, y = 1, z = 0 })
    SetString(prefix .. "/xSlots/render/impactLayer", "none", true)

    for i = 1, xSlotCount do
        local slotPrefix = prefix .. "/xSlots/" .. tostring(i)
        local typeSlotPrefix = typePrefix .. "/xSlots/" .. tostring(i)
        local weaponType = GetString(typeSlotPrefix .. "/weaponType")
        local weaponTypePrefix = _xSlotWeaponTypeKeyPrefix(weaponType)

        SetString(slotPrefix .. "/weaponType", weaponType, true)
        SetFloat(slotPrefix .. "/cd", 0, true)
        SetString(slotPrefix .. "/state", "idle", true)
        SetFloat(slotPrefix .. "/chargeRemain", 0, true)
        SetFloat(slotPrefix .. "/launchRemain", 0, true)
        SetFloat(slotPrefix .. "/chargeDuration", GetFloat(weaponTypePrefix .. "/chargeDuration"), true)
        SetFloat(slotPrefix .. "/launchDuration", GetFloat(weaponTypePrefix .. "/launchDuration"), true)
        SetFloat(slotPrefix .. "/randomTrajectoryAngle", GetFloat(weaponTypePrefix .. "/randomTrajectoryAngle"), true)

        local firePosOffset = _readVec3FromRegistry(typeSlotPrefix .. "/mount/firePosOffset")
        local fireDirRelative = _readVec3FromRegistry(typeSlotPrefix .. "/mount/fireDirRelative")
        _writeVec3ToRegistry(slotPrefix .. "/mount/firePosOffset", firePosOffset)
        _writeVec3ToRegistry(slotPrefix .. "/mount/fireDirRelative", fireDirRelative)
    end
end

function server.registryShipEnsure(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end

    if not server.registryShipExists(shipBodyId) then
        server.registryShipRegister(shipBodyId, shipType, defaultShipType)
    end
    return true
end

function server.registryShipGetSnapshot(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return nil
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    local snapshot = {
        id = shipBodyId,
        exists = GetBool(prefix .. "/exists"),
        shipType = GetString(prefix .. "/shipType"),
        shieldHP = GetFloat(prefix .. "/shieldHP"),
        armorHP = GetFloat(prefix .. "/armorHP"),
        bodyHP = GetFloat(prefix .. "/bodyHP"),
        driverPlayerId = GetInt(prefix .. "/driverPlayerId"),
        moveState = GetInt(prefix .. "/moveState"),
        moveRequest = GetInt(prefix .. "/move/request"),
        moveRequestState = GetInt(prefix .. "/move/requestState"),
        xSlotsRequest = GetInt(prefix .. "/xSlots/request"),
        xSlotsWriteSeq = GetInt(prefix .. "/xSlots/writeSeq"),
        xSlotsLastReadSeq = GetInt(prefix .. "/xSlots/lastReadSeq"),
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
        xSlots = {},
    }

    local xSlotCount = GetInt(prefix .. "/xSlots/count")
    snapshot.xSlotCount = xSlotCount
    for i = 1, xSlotCount do
        local slotPrefix = prefix .. "/xSlots/" .. tostring(i)
        snapshot.xSlots[i] = {
            weaponType = GetString(slotPrefix .. "/weaponType"),
            cd = GetFloat(slotPrefix .. "/cd"),
            state = GetString(slotPrefix .. "/state"),
            chargeRemain = GetFloat(slotPrefix .. "/chargeRemain"),
            launchRemain = GetFloat(slotPrefix .. "/launchRemain"),
            chargeDuration = GetFloat(slotPrefix .. "/chargeDuration"),
            launchDuration = GetFloat(slotPrefix .. "/launchDuration"),
            randomTrajectoryAngle = GetFloat(slotPrefix .. "/randomTrajectoryAngle"),
            firePosOffset = _readVec3FromRegistry(slotPrefix .. "/mount/firePosOffset"),
            fireDirRelative = _readVec3FromRegistry(slotPrefix .. "/mount/fireDirRelative"),
        }
    end

    return snapshot
end

function server.registryShipGetHP(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return nil, nil, nil
    end
    local prefix = _shipKeyPrefix(shipBodyId)
    return GetFloat(prefix .. "/shieldHP"), GetFloat(prefix .. "/armorHP"), GetFloat(prefix .. "/bodyHP")
end

function server.registryShipSetHP(shipBodyId, shieldHP, armorHP, bodyHP)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local prefix = _shipKeyPrefix(shipBodyId)
    if shieldHP ~= nil then SetFloat(prefix .. "/shieldHP", shieldHP, true) end
    if armorHP ~= nil then SetFloat(prefix .. "/armorHP", armorHP, true) end
    if bodyHP ~= nil then SetFloat(prefix .. "/bodyHP", bodyHP, true) end
end

function server.registryShipGetMoveState(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/moveState")
end

function server.registryShipSetMoveState(shipBodyId, moveState)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local state = math.floor(moveState or 0)
    if state < 0 then state = 0 end
    if state > 2 then state = 2 end
    SetInt(_shipKeyPrefix(shipBodyId) .. "/moveState", state, true)
end

function server.registryShipGetDriverPlayerId(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/driverPlayerId")
end

function server.registryShipSetDriverPlayerId(shipBodyId, playerId)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    SetInt(_shipKeyPrefix(shipBodyId) .. "/driverPlayerId", math.floor(playerId or 0), true)
end

function server.registryShipGetMoveRequestState(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/move/requestState")
end

function server.registryShipSetMoveRequestState(shipBodyId, requestState)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local state = math.floor(requestState or 0)
    if state < 0 then state = 0 end
    if state > 2 then state = 2 end
    local prefix = _shipKeyPrefix(shipBodyId)
    SetInt(prefix .. "/move/requestState", state, true)
    SetInt(prefix .. "/move/request", (state == 0) and 0 or 1, true)
end

function server.registryShipGetXSlotRequest(shipBodyId, slotIndex)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/xSlots/request")
end

function server.registryShipSetXSlotRequest(shipBodyId, slotIndex, request)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    SetInt(_shipKeyPrefix(shipBodyId) .. "/xSlots/request", value, true)
end

function server.registryShipGetXSlotsRequest(shipBodyId)
    return server.registryShipGetXSlotRequest(shipBodyId, 1)
end

function server.registryShipSetXSlotsRequest(shipBodyId, request)
    server.registryShipSetXSlotRequest(shipBodyId, 1, request)
end

function server.registryShipGetXSlotsWriteSeq(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return -1
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/xSlots/writeSeq")
end

function server.registryShipSetXSlotsWriteSeq(shipBodyId, slotId)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local value = math.floor(slotId or -1)
    SetInt(_shipKeyPrefix(shipBodyId) .. "/xSlots/writeSeq", value, true)
end

function server.registryShipGetXSlotsLastReadSeq(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return -1
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/xSlots/lastReadSeq")
end

function server.registryShipSetXSlotsLastReadSeq(shipBodyId, slotId)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local value = math.floor(slotId or -1)
    SetInt(_shipKeyPrefix(shipBodyId) .. "/xSlots/lastReadSeq", value, true)
end

function server.registryShipGetXSlotCD(shipBodyId, slotIndex)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    local slot = _normalizeSlotIndex(slotIndex)
    return GetFloat(_shipKeyPrefix(shipBodyId) .. "/xSlots/" .. tostring(slot) .. "/cd")
end

function server.registryShipSetXSlotCD(shipBodyId, slotIndex, cd)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local slot = _normalizeSlotIndex(slotIndex)
    SetFloat(_shipKeyPrefix(shipBodyId) .. "/xSlots/" .. tostring(slot) .. "/cd", cd or 0, true)
end

function server.registryShipGetXSlotChargeRemain(shipBodyId, slotIndex)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    local slot = _normalizeSlotIndex(slotIndex)
    return GetFloat(_shipKeyPrefix(shipBodyId) .. "/xSlots/" .. tostring(slot) .. "/chargeRemain")
end

function server.registryShipSetXSlotChargeRemain(shipBodyId, slotIndex, remain)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local slot = _normalizeSlotIndex(slotIndex)
    SetFloat(_shipKeyPrefix(shipBodyId) .. "/xSlots/" .. tostring(slot) .. "/chargeRemain", remain or 0, true)
end

function server.registryShipGetXSlotLaunchRemain(shipBodyId, slotIndex)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    local slot = _normalizeSlotIndex(slotIndex)
    return GetFloat(_shipKeyPrefix(shipBodyId) .. "/xSlots/" .. tostring(slot) .. "/launchRemain")
end

function server.registryShipSetXSlotLaunchRemain(shipBodyId, slotIndex, remain)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local slot = _normalizeSlotIndex(slotIndex)
    SetFloat(_shipKeyPrefix(shipBodyId) .. "/xSlots/" .. tostring(slot) .. "/launchRemain", remain or 0, true)
end

function server.registryShipGetXSlotState(shipBodyId, slotIndex)
    if not server.registryShipExists(shipBodyId) then
        return "idle"
    end
    local slot = _normalizeSlotIndex(slotIndex)
    local state = GetString(_shipKeyPrefix(shipBodyId) .. "/xSlots/" .. tostring(slot) .. "/state")
    if state == "charging" or state == "launching" or state == "idle" then
        return state
    end
    return "idle"
end

function server.registryShipSetXSlotState(shipBodyId, slotIndex, state)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local slot = _normalizeSlotIndex(slotIndex)
    local normalized = (state == "charging" or state == "launching") and state or "idle"
    SetString(_shipKeyPrefix(shipBodyId) .. "/xSlots/" .. tostring(slot) .. "/state", normalized, true)
end

-- 写入 x 槽渲染事件（统一入口）
-- payload 字段：
-- eventType, slotIndex, weaponType, serverTime, firePoint, hitPoint,
-- didHit, didHitStellarisBody, didHitShield, hitTargetBodyId, normal, impactLayer,
-- incrementShotId(可选，1 表示本次事件需要推进 shotId)
function server.registryShipWriteXSlotsRenderEvent(shipBodyId, payload)
    if not server.registryShipExists(shipBodyId) then
        return false
    end

    local p = payload or {}
    local prefix = _shipKeyPrefix(shipBodyId) .. "/xSlots/render"

    local function _asInt01(v)
        return (v and 1 or 0)
    end

    local nextSeq = GetInt(prefix .. "/seq") + 1
    SetInt(prefix .. "/seq", nextSeq, true)

    if p.incrementShotId ~= nil and math.floor(p.incrementShotId) ~= 0 then
        SetInt(prefix .. "/shotId", GetInt(prefix .. "/shotId") + 1, true)
    end

    SetString(prefix .. "/eventType", tostring(p.eventType or "idle"), true)
    SetInt(prefix .. "/slotIndex", math.floor(p.slotIndex or 1), true)
    SetString(prefix .. "/weaponType", tostring(p.weaponType or ""), true)
    SetFloat(prefix .. "/serverTime", p.serverTime or ((GetTime ~= nil) and GetTime() or 0), true)

    _writeVec3ToRegistry(prefix .. "/firePoint", p.firePoint)
    _writeVec3ToRegistry(prefix .. "/hitPoint", p.hitPoint)
    _writeVec3ToRegistry(prefix .. "/normal", p.normal)

    SetInt(prefix .. "/didHit", _asInt01(p.didHit), true)
    SetInt(prefix .. "/didHitStellarisBody", _asInt01(p.didHitStellarisBody), true)
    SetInt(prefix .. "/didHitShield", _asInt01(p.didHitShield), true)
    SetInt(prefix .. "/hitTargetBodyId", math.floor(p.hitTargetBodyId or 0), true)

    local impactLayer = p.impactLayer or "none"
    if impactLayer ~= "none" and impactLayer ~= "shield" and impactLayer ~= "armor" and impactLayer ~= "body" and impactLayer ~= "environment" then
        impactLayer = "none"
    end
    SetString(prefix .. "/impactLayer", impactLayer, true)

    return true
end
