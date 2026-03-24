---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

#include "../../data/ships/enigmaticCruiser.lua"
#include "../../data/weapons/xSlots/tachyonLance.lua"
#include "../../data/weapons/lSlots/kineticArtillery.lua"

local registryShipRoot = "StellarisShips/server/ships/byId/"
local registryShipIndexRoot = "StellarisShips/server/ships/index"
local registryShipTypeRoot = "StellarisShips/server/definitions/ships/byType/"
local registryXSlotWeaponTypeRoot = "StellarisShips/server/definitions/weapons/xSlots/byType/"
local registryLSlotWeaponTypeRoot = "StellarisShips/server/definitions/weapons/lSlots/byType/"

local function _shipKeyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

local function _shipTypeKeyPrefix(shipType)
    return registryShipTypeRoot .. tostring(shipType)
end

local function _xSlotWeaponTypeKeyPrefix(weaponType)
    return registryXSlotWeaponTypeRoot .. tostring(weaponType)
end

local function _lSlotWeaponTypeKeyPrefix(weaponType)
    return registryLSlotWeaponTypeRoot .. tostring(weaponType)
end
local function _writeShipInstanceMaxHpFromType(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local resolvedShipType = shipType or defaultShipType or "enigmaticCruiser"
    server.registryEnsureShipTypeRegistered(resolvedShipType, defaultShipType)

    local typePrefix = _shipTypeKeyPrefix(resolvedShipType)
    local prefix = _shipKeyPrefix(shipBodyId)
    SetFloat(prefix .. "/maxShieldHP", GetFloat(typePrefix .. "/maxShieldHP"), true)
    SetFloat(prefix .. "/maxArmorHP", GetFloat(typePrefix .. "/maxArmorHP"), true)
    SetFloat(prefix .. "/maxBodyHP", GetFloat(typePrefix .. "/maxBodyHP"), true)
end

local function _writeShipInstanceRegenFromType(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local resolvedShipType = shipType or defaultShipType or "enigmaticCruiser"
    server.registryEnsureShipTypeRegistered(resolvedShipType, defaultShipType)

    local typePrefix = _shipTypeKeyPrefix(resolvedShipType)
    local prefix = _shipKeyPrefix(shipBodyId)
    SetFloat(prefix .. "/regen/tickInterval", GetFloat(typePrefix .. "/regen/tickInterval"), true)
    SetFloat(prefix .. "/regen/shieldPerSecond", GetFloat(typePrefix .. "/regen/shieldPerSecond"), true)
    SetFloat(prefix .. "/regen/armorPerSecond", GetFloat(typePrefix .. "/regen/armorPerSecond"), true)
    SetFloat(prefix .. "/regen/bodyPerSecond", GetFloat(typePrefix .. "/regen/bodyPerSecond"), true)
    SetFloat(prefix .. "/regen/shieldNoDamageDelay", GetFloat(typePrefix .. "/regen/shieldNoDamageDelay"), true)
    SetFloat(prefix .. "/regen/armorNoDamageDelay", GetFloat(typePrefix .. "/regen/armorNoDamageDelay"), true)
    SetFloat(prefix .. "/regen/bodyNoDamageDelay", GetFloat(typePrefix .. "/regen/bodyNoDamageDelay"), true)
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

local function _resolveLSlotWeaponTypeDefinition(weaponType)
    local requestedWeaponType = weaponType or "kineticArtillery"
    local defs = lSlotWeaponRegistryData or {}
    local definition = defs[requestedWeaponType] or defs.kineticArtillery or {}
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

-- 婵繐绠戝▍鎺旂尵鐠囪尙鈧兘寮伴姘剨鐎圭寮堕弫鐐哄礃瀹€瀣xSlots 闁糕晝鍣︾槐?
function server.registryXSlotWeaponTypeRegistered(weaponType)
    if weaponType == nil or weaponType == "" or weaponType == "none" then
        return false
    end
    return GetBool(_xSlotWeaponTypeKeyPrefix(weaponType) .. "/registered")
end

-- 婵炲鍔岄崬浠嬪础閺囨岸鍤?xSlots 婵繐绠戝▍鎺旂尵鐠囪尙鈧鈧鐭粻鐔兼晬閸繃鍊辩紒顐ヮ嚙閻庣兘宕ｉ鍛殘闁告劕濂旂粩鏉戔枎閳藉懐绀?
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

-- 缁绢収鍠曠换?xSlots 婵繐绠戝▍鎺旂尵鐠囪尙鈧鈧鐭粻鐔奉啅閸欏鏆堥柛?
function server.registryEnsureXSlotWeaponTypeRegistered(weaponType)
    local resolvedWeaponType = weaponType or "tachyonLance"
    if not server.registryXSlotWeaponTypeRegistered(resolvedWeaponType) then
        server.registryRegisterXSlotWeaponType(resolvedWeaponType)
    end
    return true
end

function server.registryLSlotWeaponTypeRegistered(weaponType)
    if weaponType == nil or weaponType == "" or weaponType == "none" then
        return false
    end
    return GetBool(_lSlotWeaponTypeKeyPrefix(weaponType) .. "/registered")
end

function server.registryRegisterLSlotWeaponType(weaponType)
    local resolvedWeaponType, definition = _resolveLSlotWeaponTypeDefinition(weaponType)
    local prefix = _lSlotWeaponTypeKeyPrefix(resolvedWeaponType)

    SetBool(prefix .. "/registered", true, true)
    SetString(prefix .. "/weaponType", definition.weaponType or resolvedWeaponType, true)
    SetString(prefix .. "/domain", "lSlots", true)
    SetFloat(prefix .. "/cooldown", definition.cooldown or 0, true)
    SetFloat(prefix .. "/maxRange", definition.maxRange or 0, true)
    SetFloat(prefix .. "/projectileSpeed", definition.projectileSpeed or 0, true)
    SetFloat(prefix .. "/projectileLifetime", definition.projectileLifetime or 0, true)
    SetFloat(prefix .. "/projectileRadius", definition.projectileRadius or 0, true)
    SetFloat(prefix .. "/projectileGravityScale", definition.projectileGravityScale or 0, true)
    SetFloat(prefix .. "/damage", definition.damage or 0, true)
    SetFloat(prefix .. "/shieldFix", definition.shieldFix or 1, true)
    SetFloat(prefix .. "/armorFix", definition.armorFix or 1, true)
    SetFloat(prefix .. "/bodyFix", definition.bodyFix or 1, true)
    SetFloat(prefix .. "/explosionRadius", definition.explosionRadius or 0, true)
    SetFloat(prefix .. "/explosionStrength", definition.explosionStrength or 0, true)
    SetFloat(prefix .. "/heatPerShot", definition.heatPerShot or 0, true)
    SetFloat(prefix .. "/heatDissipationPerSecond", definition.heatDissipationPerSecond or 0, true)
    SetFloat(prefix .. "/overheatThreshold", definition.overheatThreshold or 0, true)
    SetFloat(prefix .. "/recoverThreshold", definition.recoverThreshold or 0, true)
end

function server.registryEnsureLSlotWeaponTypeRegistered(weaponType)
    local resolvedWeaponType = weaponType or "kineticArtillery"
    if not server.registryLSlotWeaponTypeRegistered(resolvedWeaponType) then
        server.registryRegisterLSlotWeaponType(resolvedWeaponType)
    end
    return true
end

-- 濡炲鍋犻崺鐐电尵鐠囪尙鈧兘寮伴姘剨鐎圭寮堕弫鐐哄礃?
function server.registryShipTypeRegistered(shipType)
    if shipType == nil or shipType == "" then
        return false
    end
    return GetBool(_shipTypeKeyPrefix(shipType) .. "/registered")
end

-- 婵炲鍔岄崬浠嬪础閺囨岸鍤嬪瀣仩閸╃偟鐚剧拠鑼偓椋庘偓瑙勭煯缁犵喖鏁嶉崼婵囧€辩紒顐ヮ嚙閻庣兘宕ｉ鍛殘闁告劕濂旂粩鏉戔枎閳藉懐绀?
function server.registryRegisterShipType(shipType, defaultShipType)
    local resolvedShipType, definition = _resolveShipTypeDefinition(shipType, defaultShipType)
    local prefix = _shipTypeKeyPrefix(resolvedShipType)
    local xSlots = definition.xSlots or {}
    local lSlots = definition.lSlots or {}
    local definedSlotCount = #xSlots
    local xSlotCount = definition.xSlotCount
    local lSlotCount = #lSlots
    if xSlotCount == nil then
        if definedSlotCount > 0 then
            xSlotCount = definedSlotCount
        else
            xSlotCount = definition.xSlotNum or 1
        end
    end
    xSlotCount = math.floor(xSlotCount or 0)
    if xSlotCount < 0 then
        xSlotCount = 0
    end
    lSlotCount = math.floor(lSlotCount or 0)
    if lSlotCount < 0 then
        lSlotCount = 0
    end

    local regenDef = definition.regen or {}

    SetBool(prefix .. "/registered", true, true)
    SetString(prefix .. "/shipType", definition.shipType or resolvedShipType, true)
    SetFloat(prefix .. "/maxShieldHP", definition.maxShieldHP or 0, true)
    SetFloat(prefix .. "/maxArmorHP", definition.maxArmorHP or 0, true)
    SetFloat(prefix .. "/maxBodyHP", definition.maxBodyHP or 0, true)
    SetFloat(prefix .. "/shieldRadius", definition.shieldRadius or 0, true)
    SetFloat(prefix .. "/regen/tickInterval", regenDef.tickInterval or 0.2, true)
    SetFloat(prefix .. "/regen/shieldPerSecond", regenDef.shieldPerSecond or 0.0, true)
    SetFloat(prefix .. "/regen/armorPerSecond", regenDef.armorPerSecond or 0.0, true)
    SetFloat(prefix .. "/regen/bodyPerSecond", regenDef.bodyPerSecond or 0.0, true)
    SetFloat(prefix .. "/regen/shieldNoDamageDelay", regenDef.shieldNoDamageDelay or 0.0, true)
    SetFloat(prefix .. "/regen/armorNoDamageDelay", regenDef.armorNoDamageDelay or 0.0, true)
    SetFloat(prefix .. "/regen/bodyNoDamageDelay", regenDef.bodyNoDamageDelay or 0.0, true)
    SetInt(prefix .. "/xSlots/count", xSlotCount, true)
    SetInt(prefix .. "/lSlots/count", lSlotCount, true)

    for i = 1, xSlotCount do
        local slotDef = xSlots[i] or {}
        local weaponType = slotDef.weaponType or "none"
        local slotPrefix = prefix .. "/xSlots/" .. tostring(i)

        SetString(slotPrefix .. "/weaponType", weaponType, true)
        _writeVec3ToRegistry(slotPrefix .. "/mount/firePosOffset", slotDef.firePosOffset)
        _writeVec3ToRegistry(slotPrefix .. "/mount/fireDirRelative", slotDef.fireDirRelative)

        if weaponType ~= "none" then
            server.registryEnsureXSlotWeaponTypeRegistered(weaponType)
        end
    end

    for i = 1, lSlotCount do
        local slotDef = lSlots[i] or {}
        local weaponType = slotDef.weaponType or "none"
        local slotPrefix = prefix .. "/lSlots/" .. tostring(i)

        SetString(slotPrefix .. "/weaponType", weaponType, true)
        _writeVec3ToRegistry(slotPrefix .. "/mount/firePosOffset", slotDef.firePosOffset)
        _writeVec3ToRegistry(slotPrefix .. "/mount/fireDirRelative", slotDef.fireDirRelative)
        SetString(slotPrefix .. "/mount/aimMode", tostring(slotDef.aimMode or "fixed"), true)

        if weaponType ~= "none" then
            server.registryEnsureLSlotWeaponTypeRegistered(weaponType)
        end
    end
end

-- 缁绢収鍠曠换姘槹閻愯泛鐓樼紒顐ヮ嚙閻庨鈧鐭粻鐔奉啅閸欏鏆堥柛鎰焿缁辨繈鐛幆棰佺矒闁告柣鍔庨垾妯荤┍濠靛棗寰撻柟绋垮€藉ù鍥儍閸曨剦鍔呴柛锝冨妿鐞氼偊宕圭€ｂ晝鐦嶇€圭寮堕弫鐐哄礃?
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
    _writeShipInstanceMaxHpFromType(shipBodyId, resolvedShipType, defaultShipType)
    _writeShipInstanceRegenFromType(shipBodyId, resolvedShipType, defaultShipType)
    SetFloat(prefix .. "/shieldHP", GetFloat(typePrefix .. "/maxShieldHP"), true)
    SetFloat(prefix .. "/armorHP", GetFloat(typePrefix .. "/maxArmorHP"), true)
    SetFloat(prefix .. "/bodyHP", GetFloat(typePrefix .. "/maxBodyHP"), true)

    local nowTime = (GetTime ~= nil) and GetTime() or 0.0
    SetInt(prefix .. "/driverPlayerId", 0, true)
    SetInt(prefix .. "/moveState", 0, true)
    SetInt(prefix .. "/move/request", 0, true)
    SetInt(prefix .. "/move/requestState", 0, true)
    SetBool(prefix .. "/destroyed", false, true)
    SetFloat(prefix .. "/regen/state/lastDamageTimeShield", nowTime, true)
    SetFloat(prefix .. "/regen/state/lastDamageTimeArmor", nowTime, true)
    SetFloat(prefix .. "/regen/state/lastDamageTimeBody", nowTime, true)
    -- 濠殿喗瀵ч埀顑挎祰椤曘倕顔忛鍡欑闁汇垼椴哥敮鍫曞礆鐠虹儤鐝?閻庡箍鍨洪崺娑氱博椤栨艾鏅搁柛蹇嬪劵�?
    SetFloat(prefix .. "/pitchError", 0.0, true)
    SetFloat(prefix .. "/yawError", 0.0, true)
    SetFloat(prefix .. "/rollError", 0.0, true)
    SetString(prefix .. "/mainWeapon/current", "xSlot", true)
    SetInt(prefix .. "/mainWeapon/fireRequest", 0, true)
    SetInt(prefix .. "/mainWeapon/toggleRequest", 0, true)
    local xSlotCount = GetInt(typePrefix .. "/xSlots/count")
    if xSlotCount < 0 then
        xSlotCount = 0
    end
    local lSlotCount = GetInt(typePrefix .. "/lSlots/count")
    if lSlotCount < 0 then
        lSlotCount = 0
    end

    SetInt(prefix .. "/xSlots/count", xSlotCount, true)
    SetInt(prefix .. "/xSlots/request", 0, true)
    SetInt(prefix .. "/xSlots/writeSeq", -1, true)
    SetInt(prefix .. "/xSlots/lastReadSeq", -1, true)
    SetInt(prefix .. "/lSlots/count", lSlotCount, true)
    SetInt(prefix .. "/lSlots/request", 0, true)
    SetFloat(prefix .. "/lSlots/heat", 0.0, true)
    SetInt(prefix .. "/lSlots/overheated", 0, true)
    SetFloat(prefix .. "/lSlots/cooldownRemain", 0.0, true)

    -- x 婵¤尪濮ょ憰鍡涘蓟閹捐尙鐨戝ù鐘烘硾鐏忣垶鏁嶅杈ㄦ殢濞存粌瀛╁﹢鍥礉閿涘嫷浼傞柛鎰懃閸欏棝鍨惧鍕粯闁哄倿顣︾粩鏉戔枎閿涘嫬笑闁诡兛绀佽ぐ澶愬�?闁告瑦鍨甸惃鐘电磼閹惧浜柍銉︾箰缁辨繃绗熷☉姗嗗悅闁规挳顥撻顒勫箯婢跺﹤绲挎繛鎾冲级閻?
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
        if weaponType == nil or weaponType == "" then
            weaponType = "none"
        end
        local weaponTypePrefix = _xSlotWeaponTypeKeyPrefix(weaponType)

        SetString(slotPrefix .. "/weaponType", weaponType, true)
        SetFloat(slotPrefix .. "/cd", 0, true)
        SetString(slotPrefix .. "/state", "idle", true)
        SetFloat(slotPrefix .. "/chargeRemain", 0, true)
        SetFloat(slotPrefix .. "/launchRemain", 0, true)
        if weaponType == "none" then
            SetFloat(slotPrefix .. "/chargeDuration", 0, true)
            SetFloat(slotPrefix .. "/launchDuration", 0, true)
            SetFloat(slotPrefix .. "/randomTrajectoryAngle", 0, true)
        else
            SetFloat(slotPrefix .. "/chargeDuration", GetFloat(weaponTypePrefix .. "/chargeDuration"), true)
            SetFloat(slotPrefix .. "/launchDuration", GetFloat(weaponTypePrefix .. "/launchDuration"), true)
            SetFloat(slotPrefix .. "/randomTrajectoryAngle", GetFloat(weaponTypePrefix .. "/randomTrajectoryAngle"), true)
        end

        local firePosOffset = _readVec3FromRegistry(typeSlotPrefix .. "/mount/firePosOffset")
        local fireDirRelative = _readVec3FromRegistry(typeSlotPrefix .. "/mount/fireDirRelative")
        _writeVec3ToRegistry(slotPrefix .. "/mount/firePosOffset", firePosOffset)
        _writeVec3ToRegistry(slotPrefix .. "/mount/fireDirRelative", fireDirRelative)
    end

    for i = 1, lSlotCount do
        local slotPrefix = prefix .. "/lSlots/" .. tostring(i)
        local typeSlotPrefix = typePrefix .. "/lSlots/" .. tostring(i)
        local weaponType = GetString(typeSlotPrefix .. "/weaponType")
        if weaponType == nil or weaponType == "" then
            weaponType = "none"
        end

        SetString(slotPrefix .. "/weaponType", weaponType, true)
        _writeVec3ToRegistry(slotPrefix .. "/mount/firePosOffset", _readVec3FromRegistry(typeSlotPrefix .. "/mount/firePosOffset"))
        _writeVec3ToRegistry(slotPrefix .. "/mount/fireDirRelative", _readVec3FromRegistry(typeSlotPrefix .. "/mount/fireDirRelative"))
        SetString(slotPrefix .. "/mount/aimMode", GetString(typeSlotPrefix .. "/mount/aimMode"), true)
    end
end

function server.registryShipEnsure(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end

    if not server.registryShipExists(shipBodyId) then
        server.registryShipRegister(shipBodyId, shipType, defaultShipType)
    else
        local prefix = _shipKeyPrefix(shipBodyId)
        local maxShield = GetFloat(prefix .. "/maxShieldHP")
        local maxArmor = GetFloat(prefix .. "/maxArmorHP")
        local maxBody = GetFloat(prefix .. "/maxBodyHP")
        local existingShipType = GetString(prefix .. "/shipType")
        if existingShipType == nil or existingShipType == "" then
            existingShipType = shipType or defaultShipType or "enigmaticCruiser"
            SetString(prefix .. "/shipType", existingShipType, true)
        end
        if GetString(prefix .. "/mainWeapon/current") == "" then
            SetString(prefix .. "/mainWeapon/current", "xSlot", true)
        end
        if GetFloat(prefix .. "/lSlots/heat") < 0 then
            SetFloat(prefix .. "/lSlots/heat", 0.0, true)
        end
        if maxShield <= 0 or maxArmor <= 0 or maxBody <= 0 then
            _writeShipInstanceMaxHpFromType(shipBodyId, existingShipType, defaultShipType)
        end

        local tickInterval = GetFloat(prefix .. "/regen/tickInterval")
        if tickInterval <= 0 then
            local nowTime = (GetTime ~= nil) and GetTime() or 0.0
            _writeShipInstanceRegenFromType(shipBodyId, existingShipType, defaultShipType)
            SetFloat(prefix .. "/regen/state/lastDamageTimeShield", nowTime, true)
            SetFloat(prefix .. "/regen/state/lastDamageTimeArmor", nowTime, true)
            SetFloat(prefix .. "/regen/state/lastDamageTimeBody", nowTime, true)
        end

        if GetInt(prefix .. "/lSlots/count") <= 0 then
            local typeLSlotCount = GetInt(_shipTypeKeyPrefix(existingShipType) .. "/lSlots/count")
            SetInt(prefix .. "/lSlots/count", typeLSlotCount, true)
            SetInt(prefix .. "/lSlots/request", 0, true)
            SetFloat(prefix .. "/lSlots/heat", 0.0, true)
            SetInt(prefix .. "/lSlots/overheated", 0, true)
            SetFloat(prefix .. "/lSlots/cooldownRemain", 0.0, true)
            for i = 1, typeLSlotCount do
                local slotPrefix = prefix .. "/lSlots/" .. tostring(i)
                local typeSlotPrefix = _shipTypeKeyPrefix(existingShipType) .. "/lSlots/" .. tostring(i)
                SetString(slotPrefix .. "/weaponType", GetString(typeSlotPrefix .. "/weaponType"), true)
                _writeVec3ToRegistry(slotPrefix .. "/mount/firePosOffset", _readVec3FromRegistry(typeSlotPrefix .. "/mount/firePosOffset"))
                _writeVec3ToRegistry(slotPrefix .. "/mount/fireDirRelative", _readVec3FromRegistry(typeSlotPrefix .. "/mount/fireDirRelative"))
                SetString(slotPrefix .. "/mount/aimMode", GetString(typeSlotPrefix .. "/mount/aimMode"), true)
            end
        end
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
        currentMainWeapon = GetString(prefix .. "/mainWeapon/current"),
        mainWeaponFireRequest = GetInt(prefix .. "/mainWeapon/fireRequest"),
        mainWeaponToggleRequest = GetInt(prefix .. "/mainWeapon/toggleRequest"),
        xSlotsRequest = GetInt(prefix .. "/xSlots/request"),
        xSlotsWriteSeq = GetInt(prefix .. "/xSlots/writeSeq"),
        xSlotsLastReadSeq = GetInt(prefix .. "/xSlots/lastReadSeq"),
        lSlotsRequest = GetInt(prefix .. "/lSlots/request"),
        lSlotsHeat = GetFloat(prefix .. "/lSlots/heat"),
        lSlotsOverheated = GetInt(prefix .. "/lSlots/overheated"),
        lSlotsCooldownRemain = GetFloat(prefix .. "/lSlots/cooldownRemain"),
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
        lSlots = {},
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

    local lSlotCount = GetInt(prefix .. "/lSlots/count")
    snapshot.lSlotCount = lSlotCount
    for i = 1, lSlotCount do
        local slotPrefix = prefix .. "/lSlots/" .. tostring(i)
        snapshot.lSlots[i] = {
            weaponType = GetString(slotPrefix .. "/weaponType"),
            firePosOffset = _readVec3FromRegistry(slotPrefix .. "/mount/firePosOffset"),
            fireDirRelative = _readVec3FromRegistry(slotPrefix .. "/mount/fireDirRelative"),
            aimMode = GetString(slotPrefix .. "/mount/aimMode"),
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

function server.registryShipGetRegenConfig(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return nil
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    return {
        tickInterval = GetFloat(prefix .. "/regen/tickInterval"),
        shieldPerSecond = GetFloat(prefix .. "/regen/shieldPerSecond"),
        armorPerSecond = GetFloat(prefix .. "/regen/armorPerSecond"),
        bodyPerSecond = GetFloat(prefix .. "/regen/bodyPerSecond"),
        shieldNoDamageDelay = GetFloat(prefix .. "/regen/shieldNoDamageDelay"),
        armorNoDamageDelay = GetFloat(prefix .. "/regen/armorNoDamageDelay"),
        bodyNoDamageDelay = GetFloat(prefix .. "/regen/bodyNoDamageDelay"),
    }
end

function server.registryShipGetRegenLastDamageTimes(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return nil
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    return {
        shield = GetFloat(prefix .. "/regen/state/lastDamageTimeShield"),
        armor = GetFloat(prefix .. "/regen/state/lastDamageTimeArmor"),
        body = GetFloat(prefix .. "/regen/state/lastDamageTimeBody"),
    }
end

function server.registryShipSetHP(shipBodyId, shieldHP, armorHP, bodyHP)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local prefix = _shipKeyPrefix(shipBodyId)
    local oldShield = GetFloat(prefix .. "/shieldHP")
    local oldArmor = GetFloat(prefix .. "/armorHP")
    local oldBody = GetFloat(prefix .. "/bodyHP")
    local nowTime = (GetTime ~= nil) and GetTime() or 0.0

    if shieldHP ~= nil then
        SetFloat(prefix .. "/shieldHP", shieldHP, true)
        if shieldHP < oldShield then
            SetFloat(prefix .. "/regen/state/lastDamageTimeShield", nowTime, true)
        end
    end

    if armorHP ~= nil then
        SetFloat(prefix .. "/armorHP", armorHP, true)
        if armorHP < oldArmor then
            SetFloat(prefix .. "/regen/state/lastDamageTimeArmor", nowTime, true)
        end
    end

    if bodyHP ~= nil then
        SetFloat(prefix .. "/bodyHP", bodyHP, true)
        if bodyHP < oldBody then
            SetFloat(prefix .. "/regen/state/lastDamageTimeBody", nowTime, true)
        end
        if bodyHP <= 0 then
            SetBool(prefix .. "/destroyed", true, true)
        end
    end
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

function server.registryShipGetCurrentMainWeapon(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return "xSlot"
    end
    local mode = GetString(_shipKeyPrefix(shipBodyId) .. "/mainWeapon/current")
    if mode ~= "lSlot" then
        mode = "xSlot"
    end
    return mode
end

function server.registryShipSetCurrentMainWeapon(shipBodyId, mode)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local normalized = (mode == "lSlot") and "lSlot" or "xSlot"
    SetString(_shipKeyPrefix(shipBodyId) .. "/mainWeapon/current", normalized, true)
end

function server.registryShipGetMainWeaponFireRequest(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/mainWeapon/fireRequest")
end

function server.registryShipSetMainWeaponFireRequest(shipBodyId, request)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    SetInt(_shipKeyPrefix(shipBodyId) .. "/mainWeapon/fireRequest", value, true)
end

function server.registryShipGetMainWeaponToggleRequest(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/mainWeapon/toggleRequest")
end

function server.registryShipSetMainWeaponToggleRequest(shipBodyId, request)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    SetInt(_shipKeyPrefix(shipBodyId) .. "/mainWeapon/toggleRequest", value, true)
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

function server.registryShipGetLSlotsRequest(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/lSlots/request")
end

function server.registryShipSetLSlotsRequest(shipBodyId, request)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    local value = (math.floor(request or 0) ~= 0) and 1 or 0
    SetInt(_shipKeyPrefix(shipBodyId) .. "/lSlots/request", value, true)
end

function server.registryShipGetLSlotsHeat(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0.0
    end
    return GetFloat(_shipKeyPrefix(shipBodyId) .. "/lSlots/heat")
end

function server.registryShipSetLSlotsHeat(shipBodyId, heat)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    SetFloat(_shipKeyPrefix(shipBodyId) .. "/lSlots/heat", heat or 0.0, true)
end

function server.registryShipGetLSlotsOverheated(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return false
    end
    return GetInt(_shipKeyPrefix(shipBodyId) .. "/lSlots/overheated") ~= 0
end

function server.registryShipSetLSlotsOverheated(shipBodyId, overheated)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    SetInt(_shipKeyPrefix(shipBodyId) .. "/lSlots/overheated", overheated and 1 or 0, true)
end

function server.registryShipGetLSlotsCooldownRemain(shipBodyId)
    if not server.registryShipExists(shipBodyId) then
        return 0.0
    end
    return GetFloat(_shipKeyPrefix(shipBodyId) .. "/lSlots/cooldownRemain")
end

function server.registryShipSetLSlotsCooldownRemain(shipBodyId, remain)
    if not server.registryShipExists(shipBodyId) then
        return
    end
    SetFloat(_shipKeyPrefix(shipBodyId) .. "/lSlots/cooldownRemain", remain or 0.0, true)
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

-- 闁告劖鐟ラ崣?x 婵¤尪濮ょ憰鍡涘蓟閹捐尙鐨戝ù鐘侯啇缁辨瑧绱掗悢鍓侇伇闁稿繈鍎辫ぐ娑㈡晬?
-- payload 閻庢稒顨嗛宀勬晬?
-- eventType, slotIndex, weaponType, serverTime, firePoint, hitPoint,
-- didHit, didHitStellarisBody, didHitShield, hitTargetBodyId, normal, impactLayer,
-- incrementShotId(闁告瑯鍨堕埀顒€顧€�? 閻炴稏鍔庨妵姘跺嫉椤掍緡鍋уù婊冾儎濞嗐垽妫侀埀顒傛啺娴ｇ懓鑵归�?shotId)
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

