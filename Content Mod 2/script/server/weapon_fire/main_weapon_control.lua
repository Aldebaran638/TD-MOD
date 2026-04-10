---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- main_weapon_control.lua
-- 主武器控制模块 - 符合规范的模块文件
-- 只导出 server.mainWeaponControlInit() 和 server.mainWeaponControlTick()

server = server or {}

-- 模块内部状态
local _requestState = {
    fireRequested = false,
    toggleRequested = false,
}

-- ============ 内部辅助函数 ============

local function _consumeFireRequested()
    local requested = _requestState.fireRequested and true or false
    _requestState.fireRequested = false
    return requested
end

local function _consumeToggleRequested()
    local requested = _requestState.toggleRequested and true or false
    _requestState.toggleRequested = false
    return requested
end

local function _resetRequests()
    _requestState.fireRequested = false
    _requestState.toggleRequested = false
end

-- ============ API函数（内部使用，通过API文件暴露） ============

local _weaponControlAPI = {}

function _weaponControlAPI.setFireRequested(active)
    _requestState.fireRequested = active and true or false
end

function _weaponControlAPI.setToggleRequested(active)
    _requestState.toggleRequested = active and true or false
end

function _weaponControlAPI.resetRequests()
    _resetRequests()
end

-- 将API导出到server表，供API文件使用
server._mainWeaponControlAPI = _weaponControlAPI

-- ============ 规范化的模块接口 ============

function server.mainWeaponControlInit()
    _requestState = {
        fireRequested = false,
        toggleRequested = false,
    }
end

function server.mainWeaponControlTick(dt)
    local _ = dt
    local shipBody = server.shipBody
    if shipBody == nil or shipBody == 0 then
        return
    end
    if not server.registryShipEnsure(shipBody, server.defaultShipType, server.defaultShipType) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(shipBody) then
        _resetRequests()
        if server.xSlotStateSetRequestFire ~= nil then
            server.xSlotStateSetRequestFire(false)
        end
        if server.xSlotStateResetRuntime ~= nil then
            server.xSlotStateResetRuntime()
        end
        server.lSlotStateSetRequestFire(false)
        server.lSlotStateResetRuntime()
        server.lSlotStatePushHudReset(true)
        if server.sSlotStateResetRuntime ~= nil then
            server.sSlotStateResetRuntime()
        end
        if server.hSlotStateResetRuntime ~= nil then
            server.hSlotStateResetRuntime()
        end
        return
    end

    if _consumeToggleRequested() then
        local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
        local nextMode = "xSlot"
        if current == "xSlot" then
            nextMode = "lSlot"
        elseif current == "lSlot" then
            nextMode = "sSlot"
        elseif current == "sSlot" then
            nextMode = "hSlot"
        end
        server.shipRuntimeSetCurrentMainWeapon(shipBody, nextMode)
        server.shipRuntimeSyncMainWeapon(shipBody, true)
        server.lSlotStatePushHud(true)
    end

    if not _consumeFireRequested() then
        return
    end

    local current = server.shipRuntimeGetCurrentMainWeapon(shipBody)
    if current == "lSlot" then
        server.lSlotStateSetRequestFire(true)
    elseif current == "xSlot" then
        if server.xSlotStateSetRequestFire ~= nil then
            server.xSlotStateSetRequestFire(true)
        end
    end
end