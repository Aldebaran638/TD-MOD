---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- runtime_state_api.lua
-- 运行时状态管理的API文件
-- 提供对外访问运行时状态的接口

server = server or {}

-- 从主模块获取内部API实现
local _api = server._runtimeStateAPI

-- 如果API未加载，提供空实现
if _api == nil then
    _api = {}
end

-- ============ Max HP ============
function server.shipRuntimeGetMaxHP(shipBodyId)
    return _api.getMaxHP(shipBodyId, server.defaultShipType)
end

-- ============ Regen ============
function server.shipRuntimeGetRegenConfig(shipBodyId)
    return _api.getRegenConfig(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeGetRegenLastDamageTimes(shipBodyId)
    return _api.getRegenLastDamageTimes(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeObserveHP(shipBodyId, shieldHP, armorHP, bodyHP, nowTime)
    return _api.observeHP(shipBodyId, shieldHP, armorHP, bodyHP, nowTime, server.defaultShipType)
end

function server.shipRuntimeSetObservedHP(shipBodyId, shieldHP, armorHP, bodyHP)
    return _api.setObservedHP(shipBodyId, shieldHP, armorHP, bodyHP, server.defaultShipType)
end

-- ============ Move State ============
function server.shipRuntimeGetMoveState(shipBodyId)
    return _api.getMoveState(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeSetMoveState(shipBodyId, moveState)
    return _api.setMoveState(shipBodyId, moveState, server.defaultShipType)
end

function server.shipRuntimeGetMoveRequestState(shipBodyId)
    return _api.getMoveRequestState(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeSetMoveRequestState(shipBodyId, moveState)
    return _api.setMoveRequestState(shipBodyId, moveState, server.defaultShipType)
end

-- ============ Driver ============
function server.shipRuntimeGetDriverPlayerId(shipBodyId)
    return _api.getDriverPlayerId(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeSetDriverPlayerId(shipBodyId, playerId)
    return _api.setDriverPlayerId(shipBodyId, playerId, server.defaultShipType)
end

-- ============ Rotation ============
function server.shipRuntimeGetRotationError(shipBodyId)
    return _api.getRotationError(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeSetRotationError(shipBodyId, pitchError, yawError)
    return _api.setRotationError(shipBodyId, pitchError, yawError, server.defaultShipType)
end

function server.shipRuntimeGetRollError(shipBodyId)
    return _api.getRollError(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeSetRollError(shipBodyId, rollError)
    return _api.setRollError(shipBodyId, rollError, server.defaultShipType)
end

-- ============ Weapon Aim ============
function server.shipRuntimeGetWeaponAim(shipBodyId)
    return _api.getWeaponAim(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeSetWeaponAim(shipBodyId, active, localYaw, localPitch)
    return _api.setWeaponAim(shipBodyId, active, localYaw, localPitch, server.defaultShipType)
end

-- ============ Main Weapon ============
function server.shipRuntimeGetCurrentMainWeapon(shipBodyId)
    return _api.getCurrentMainWeapon(shipBodyId, server.defaultShipType)
end

function server.shipRuntimeSetCurrentMainWeapon(shipBodyId, mode)
    return _api.setCurrentMainWeapon(shipBodyId, mode, server.defaultShipType)
end

function server.shipRuntimeSyncMainWeapon(shipBodyId, force)
    return _api.syncMainWeapon(shipBodyId, force, server.defaultShipType)
end