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
    return _api.getMaxHP(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetComponentProfile(shipBodyId, profile)
    return _api.setComponentProfile(
        shipBodyId,
        profile,
        server.shipContextGetType()
    )
end

function server.shipRuntimeGetHardening(shipBodyId)
    return _api.getHardening(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeGetMobilityModifiers(shipBodyId)
    return _api.getMobilityModifiers(
        shipBodyId,
        server.shipContextGetType()
    )
end

function server.shipRuntimeGetWeaponDamageMultiplier(shipBodyId)
    return _api.getWeaponDamageMultiplier(
        shipBodyId,
        server.shipContextGetType()
    )
end

function server.shipRuntimeGetCloak(shipBodyId)
    return _api.getCloak(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetCloakActive(shipBodyId, active)
    return _api.setCloakActive(
        shipBodyId,
        active,
        server.shipContextGetType()
    )
end

-- ============ Regen ============
function server.shipRuntimeGetRegenConfig(shipBodyId)
    return _api.getRegenConfig(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeGetRegenLastDamageTimes(shipBodyId)
    return _api.getRegenLastDamageTimes(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeObserveHP(shipBodyId, shieldHP, armorHP, bodyHP, nowTime)
    return _api.observeHP(shipBodyId, shieldHP, armorHP, bodyHP, nowTime, server.shipContextGetType())
end

function server.shipRuntimeSetObservedHP(shipBodyId, shieldHP, armorHP, bodyHP)
    return _api.setObservedHP(shipBodyId, shieldHP, armorHP, bodyHP, server.shipContextGetType())
end

-- ============ Move State ============
function server.shipRuntimeGetMoveState(shipBodyId)
    return _api.getMoveState(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetMoveState(shipBodyId, moveState)
    return _api.setMoveState(shipBodyId, moveState, server.shipContextGetType())
end

function server.shipRuntimeGetMoveRequestState(shipBodyId)
    return _api.getMoveRequestState(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetMoveRequestState(shipBodyId, moveState)
    return _api.setMoveRequestState(shipBodyId, moveState, server.shipContextGetType())
end

-- ============ Driver ============
function server.shipRuntimeGetDriverPlayerId(shipBodyId)
    return _api.getDriverPlayerId(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetDriverPlayerId(shipBodyId, playerId)
    return _api.setDriverPlayerId(shipBodyId, playerId, server.shipContextGetType())
end

function server.shipRuntimeResetControl(shipBodyId)
    return _api.resetControl(shipBodyId, server.shipContextGetType())
end

-- ============ Rotation ============
function server.shipRuntimeGetRotationError(shipBodyId)
    return _api.getRotationError(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetRotationError(shipBodyId, pitchError, yawError)
    return _api.setRotationError(shipBodyId, pitchError, yawError, server.shipContextGetType())
end

function server.shipRuntimeGetRollError(shipBodyId)
    return _api.getRollError(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetRollError(shipBodyId, rollError)
    return _api.setRollError(shipBodyId, rollError, server.shipContextGetType())
end

-- ============ Weapon Aim ============
function server.shipRuntimeGetWeaponAim(shipBodyId)
    return _api.getWeaponAim(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetWeaponAim(shipBodyId, active, localYaw, localPitch)
    return _api.setWeaponAim(shipBodyId, active, localYaw, localPitch, server.shipContextGetType())
end

-- ============ Main Weapon ============
function server.shipRuntimeGetCurrentMainWeapon(shipBodyId)
    return _api.getCurrentMainWeapon(shipBodyId, server.shipContextGetType())
end

function server.shipRuntimeSetCurrentMainWeapon(shipBodyId, mode)
    return _api.setCurrentMainWeapon(shipBodyId, mode, server.shipContextGetType())
end

function server.shipRuntimeSyncMainWeapon(shipBodyId, force)
    return _api.syncMainWeapon(shipBodyId, force, server.shipContextGetType())
end
