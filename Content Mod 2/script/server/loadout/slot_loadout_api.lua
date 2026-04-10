---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- slot_loadout_api.lua
-- 飞船槽位装载管理的API文件
-- 提供对外访问槽位配置的接口

server = server or {}

-- 从主模块获取内部API实现
local _api = server._slotLoadoutAPI

-- 如果API未加载，提供空实现
if _api == nil then
    _api = {}
end

function server.shipSlotLoadoutGetState(shipType)
    return _api.getState(shipType)
end

function server.shipSlotLoadoutSetConfiguration(shipType, configurationId)
    return _api.setConfiguration(shipType, configurationId)
end

function server.shipSlotLoadoutSetLoadout(shipType, requestedLoadout)
    return _api.setLoadout(shipType, requestedLoadout)
end

function server.shipSlotLoadoutResolveShipDefinition(shipType)
    return _api.resolveShipDefinition(shipType)
end