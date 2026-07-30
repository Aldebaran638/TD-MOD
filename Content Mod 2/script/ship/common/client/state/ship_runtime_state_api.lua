---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- ship_runtime_state_api.lua
-- 客户端飞船运行时状态管理的API文件
-- 提供对外访问运行时状态的接口

client = client or {}

-- 从主模块获取内部API实现
local _api = client._shipRuntimeStateAPI

-- 如果API未加载，提供空实现
if _api == nil then
    _api = {}
end

-- 服务端调用的回调函数，设置主武器模式
function client.setShipMainWeaponMode(shipBodyId, mode)
    _api.setMainWeaponMode(shipBodyId, mode)
end

function client.getShipMainWeaponMode(shipBodyId)
    return _api.getMainWeaponMode(shipBodyId)
end

function client.setShipXSlotFireMode(shipBodyId, mode)
    _api.setXSlotFireMode(shipBodyId, mode)
end

function client.getShipXSlotFireMode(shipBodyId)
    return _api.getXSlotFireMode(shipBodyId)
end

function client.toggleShipXSlotFireMode(shipBodyId)
    _api.toggleXSlotFireMode(shipBodyId)
end
