---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- main_weapon_control_api.lua
-- 主武器控制的API文件
-- 提供对外设置武器请求状态的接口

server = server or {}

-- 从主模块获取内部API实现
local _api = server._mainWeaponControlAPI

-- 如果API未加载，提供空实现
if _api == nil then
    _api = {}
end

function server.mainWeaponRequestInit()
    -- 为了保持兼容性，在API层也提供init函数
    -- 实际上会调用主模块的init
    if server.mainWeaponControlInit then
        server.mainWeaponControlInit()
    end
end

function server.mainWeaponRequestReset()
    _api.resetRequests()
end

function server.mainWeaponRequestSetFireRequested(active)
    _api.setFireRequested(active)
end

function server.mainWeaponRequestSetToggleRequested(active)
    _api.setToggleRequested(active)
end