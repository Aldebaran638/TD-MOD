---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- ship_runtime_state.lua
-- 客户端飞船运行时状态管理模块 - 符合规范的模块文件
-- 只导出 client.shipRuntimeStateInit() 和 client.shipRuntimeStateTick()

client = client or {}

-- 模块内部状态
local _stateByShip = {}

-- ============ 内部辅助函数 ============

local function _getOrCreateState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local state = _stateByShip[body]
    if state == nil then
        state = {
            currentMainWeapon = "xSlot",
            xSlotFireMode = "aim",
        }
        _stateByShip[body] = state
    end
    return state
end

-- ============ API函数（内部使用，通过API文件暴露） ============

local _runtimeAPI = {}

function _runtimeAPI.setMainWeaponMode(shipBodyId, mode)
    local state = _getOrCreateState(shipBodyId)
    if state == nil then return end
    
    if mode == "lSlot" then
        state.currentMainWeapon = "lSlot"
    elseif mode == "sSlot" then
        state.currentMainWeapon = "sSlot"
    elseif mode == "hSlot" then
        state.currentMainWeapon = "hSlot"
    else
        state.currentMainWeapon = "xSlot"
    end
end

function _runtimeAPI.getMainWeaponMode(shipBodyId)
    local state = _getOrCreateState(shipBodyId)
    if state == nil then return "xSlot" end
    
    if state.currentMainWeapon == "lSlot" or state.currentMainWeapon == "sSlot" or state.currentMainWeapon == "hSlot" then
        return state.currentMainWeapon
    end
    return "xSlot"
end

function _runtimeAPI.setXSlotFireMode(shipBodyId, mode)
    local state = _getOrCreateState(shipBodyId)
    if state == nil then return end
    
    if mode == "lock" then
        state.xSlotFireMode = "lock"
    else
        state.xSlotFireMode = "aim"
    end
end

function _runtimeAPI.getXSlotFireMode(shipBodyId)
    local state = _getOrCreateState(shipBodyId)
    if state == nil then return "aim" end
    if state.xSlotFireMode == "lock" then
        return "lock"
    end
    return "aim"
end

function _runtimeAPI.toggleXSlotFireMode(shipBodyId)
    local current = _runtimeAPI.getXSlotFireMode(shipBodyId)
    if current == "lock" then
        _runtimeAPI.setXSlotFireMode(shipBodyId, "aim")
    else
        _runtimeAPI.setXSlotFireMode(shipBodyId, "lock")
    end
end

-- 将API导出到client表，供API文件使用
client._shipRuntimeStateAPI = _runtimeAPI

-- ============ 规范化的模块接口 ============

function client.shipRuntimeStateInit()
    _stateByShip = {}
end

function client.shipRuntimeStateTick(dt)
    -- 客户端运行时状态通常不需要每tick更新
    -- 但保留接口以符合规范
end
