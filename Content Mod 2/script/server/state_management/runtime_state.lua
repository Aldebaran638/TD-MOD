---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- runtime_state.lua
-- 飞船运行时状态管理模块 - 符合规范的模块文件
-- 只导出 server.runtimeStateInit() 和 server.runtimeStateTick()

server = server or {}

local _mainWeaponSyncKeepAlive = 0.5

-- 模块内部状态，不暴露给外部
local _runtimeState = {
    byBody = {},
}

-- ============ 内部辅助函数 ============

local function _resolveShipDefinition(shipType, defaultShipType)
    local requestedShipType = shipType or defaultShipType or "enigmaticCruiser"
    local defs = shipTypeRegistryData or {}
    local definition = defs[requestedShipType] or defs[defaultShipType] or defs.enigmaticCruiser or {}
    local resolvedShipType = definition.shipType or requestedShipType
    return resolvedShipType, definition
end

local function _cloneRegenConfig(definition)
    local regenDef = (definition and definition.regen) or {}
    return {
        tickInterval = tonumber(regenDef.tickInterval) or 0.2,
        shieldPerSecond = tonumber(regenDef.shieldPerSecond) or 0.0,
        armorPerSecond = tonumber(regenDef.armorPerSecond) or 0.0,
        bodyPerSecond = tonumber(regenDef.bodyPerSecond) or 0.0,
        shieldNoDamageDelay = tonumber(regenDef.shieldNoDamageDelay) or 0.0,
        armorNoDamageDelay = tonumber(regenDef.armorNoDamageDelay) or 0.0,
        bodyNoDamageDelay = tonumber(regenDef.bodyNoDamageDelay) or 0.0,
    }
end

local function _clampMoveState(moveState)
    local state = math.floor(moveState or 0)
    if state < 0 then state = 0 end
    if state > 2 then state = 2 end
    return state
end

local function _normalizeMode(mode)
    if mode == "lSlot" then return "lSlot" end
    if mode == "sSlot" then return "sSlot" end
    if mode == "hSlot" then return "hSlot" end
    return "xSlot"
end

local function _getOrCreateState(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return nil
    end
    
    local byBody = _runtimeState.byBody
    local state = byBody[shipBodyId]
    if state ~= nil then
        return state
    end
    
    local resolvedShipType, definition = _resolveShipDefinition(shipType, defaultShipType)
    local nowTime = (GetTime ~= nil and GetTime()) or 0.0
    
    local maxShield = tonumber(definition.maxShieldHP) or 0.0
    local maxArmor = tonumber(definition.maxArmorHP) or 0.0
    local maxBody = tonumber(definition.maxBodyHP) or 0.0
    
    state = {
        shipType = resolvedShipType,
        maxHP = { shield = maxShield, armor = maxArmor, body = maxBody },
        regen = {
            config = _cloneRegenConfig(definition),
            lastDamageTimes = { shield = nowTime, armor = nowTime, body = nowTime },
            lastObservedHP = { shield = maxShield, armor = maxArmor, body = maxBody },
        },
        move = { requestState = 0, currentState = 0 },
        driverPlayerId = 0,
        rotation = { pitchError = 0.0, yawError = 0.0, rollError = 0.0 },
        mainWeapon = { current = "xSlot", lastSentMode = "", lastSentAt = -1000.0 },
        weaponAim = { active = false, localYaw = 0.0, localPitch = 0.0 },
    }
    
    byBody[shipBodyId] = state
    return state
end

local function _safeNumber(v, fallback)
    local n = tonumber(v)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then
        return fallback or 0.0
    end
    return n
end

-- ============ API函数（内部使用，通过API文件暴露） ============

local _runtimeAPI = {}

function _runtimeAPI.getMaxHP(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return 0.0, 0.0, 0.0 end
    local maxHP = state.maxHP or {}
    return maxHP.shield or 0.0, maxHP.armor or 0.0, maxHP.body or 0.0
end

function _runtimeAPI.getRegenConfig(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return nil end
    return state.regen and state.regen.config or nil
end

function _runtimeAPI.getRegenLastDamageTimes(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return nil end
    return state.regen and state.regen.lastDamageTimes or nil
end

function _runtimeAPI.observeHP(shipBodyId, shieldHP, armorHP, bodyHP, nowTime, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return nil end
    
    local regen = state.regen
    local lastObserved = regen.lastObservedHP
    local lastDamage = regen.lastDamageTimes
    local t = _safeNumber(nowTime, (GetTime ~= nil and GetTime()) or 0.0)
    
    if shieldHP ~= nil and shieldHP < (lastObserved.shield or shieldHP) then
        lastDamage.shield = t
    end
    if armorHP ~= nil and armorHP < (lastObserved.armor or armorHP) then
        lastDamage.armor = t
    end
    if bodyHP ~= nil and bodyHP < (lastObserved.body or bodyHP) then
        lastDamage.body = t
    end
    
    if shieldHP ~= nil then lastObserved.shield = shieldHP end
    if armorHP ~= nil then lastObserved.armor = armorHP end
    if bodyHP ~= nil then lastObserved.body = bodyHP end
    
    return lastDamage
end

function _runtimeAPI.setObservedHP(shipBodyId, shieldHP, armorHP, bodyHP, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    
    local lastObserved = state.regen.lastObservedHP
    if shieldHP ~= nil then lastObserved.shield = shieldHP end
    if armorHP ~= nil then lastObserved.armor = armorHP end
    if bodyHP ~= nil then lastObserved.body = bodyHP end
end

function _runtimeAPI.getMoveState(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return 0 end
    return state.move.currentState or 0
end

function _runtimeAPI.setMoveState(shipBodyId, moveState, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    state.move.currentState = _clampMoveState(moveState)
end

function _runtimeAPI.getMoveRequestState(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return 0 end
    return state.move.requestState or 0
end

function _runtimeAPI.setMoveRequestState(shipBodyId, moveState, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    state.move.requestState = _clampMoveState(moveState)
end

function _runtimeAPI.getDriverPlayerId(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return 0 end
    return math.floor(state.driverPlayerId or 0)
end

function _runtimeAPI.setDriverPlayerId(shipBodyId, playerId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    state.driverPlayerId = math.floor(playerId or 0)
end

function _runtimeAPI.getRotationError(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return 0.0, 0.0 end
    local rotation = state.rotation or {}
    return _safeNumber(rotation.pitchError, 0.0), _safeNumber(rotation.yawError, 0.0)
end

function _runtimeAPI.setRotationError(shipBodyId, pitchError, yawError, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    local rotation = state.rotation
    rotation.pitchError = _safeNumber(pitchError, 0.0)
    rotation.yawError = _safeNumber(yawError, 0.0)
end

function _runtimeAPI.getWeaponAim(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return false, 0.0, 0.0 end
    local weaponAim = state.weaponAim or {}
    return weaponAim.active and true or false, _safeNumber(weaponAim.localYaw, 0.0), _safeNumber(weaponAim.localPitch, 0.0)
end

function _runtimeAPI.setWeaponAim(shipBodyId, active, localYaw, localPitch, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    local weaponAim = state.weaponAim or {}
    weaponAim.active = active and true or false
    weaponAim.localYaw = _safeNumber(localYaw, 0.0)
    weaponAim.localPitch = _safeNumber(localPitch, 0.0)
    state.weaponAim = weaponAim
end

function _runtimeAPI.getRollError(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return 0.0 end
    return _safeNumber((state.rotation or {}).rollError, 0.0)
end

function _runtimeAPI.setRollError(shipBodyId, rollError, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    state.rotation.rollError = _safeNumber(rollError, 0.0)
end

function _runtimeAPI.getCurrentMainWeapon(shipBodyId, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return "xSlot" end
    return _normalizeMode((state.mainWeapon or {}).current)
end

function _runtimeAPI.setCurrentMainWeapon(shipBodyId, mode, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    state.mainWeapon.current = _normalizeMode(mode)
end

function _runtimeAPI.syncMainWeapon(shipBodyId, force, defaultShipType)
    local state = _getOrCreateState(shipBodyId, defaultShipType, defaultShipType)
    if state == nil then return end
    
    local mainWeapon = state.mainWeapon
    local currentMode = _normalizeMode(mainWeapon.current)
    local nowTime = (GetTime ~= nil and GetTime()) or 0.0
    local changed = currentMode ~= (mainWeapon.lastSentMode or "")
    local keepAliveDue = (nowTime - (mainWeapon.lastSentAt or -1000.0)) >= _mainWeaponSyncKeepAlive
    
    if (not force) and (not changed) and (not keepAliveDue) then
        return
    end
    
    ClientCall(0, "client.setShipMainWeaponMode", shipBodyId, currentMode)
    mainWeapon.lastSentMode = currentMode
    mainWeapon.lastSentAt = nowTime
end

-- 将API导出到server表，供API文件使用
server._runtimeStateAPI = _runtimeAPI

-- ============ 规范化的模块接口 ============

function server.runtimeStateInit(shipBodyId, shipType, defaultShipType)
    if shipBodyId == nil or shipBodyId == 0 then
        return nil
    end
    _runtimeState.byBody[shipBodyId] = nil
    return _getOrCreateState(shipBodyId, shipType, defaultShipType)
end

function server.runtimeStateTick(dt)
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end
    -- 主武器模式同步
    _runtimeAPI.syncMainWeapon(shipBodyId, false, server.defaultShipType)
end