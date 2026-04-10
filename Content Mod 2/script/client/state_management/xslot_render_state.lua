---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- xslot_render_state.lua
-- 客户端X槽渲染状态管理模块 - 符合规范的模块文件
-- 只导出 client.xSlotRenderStateInit() 和 client.xSlotRenderStateTick()

client = client or {}

-- 模块内部状态
local _stateByShip = {}

-- ============ 内部辅助函数 ============

local function _ensureState(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then
        return nil
    end

    local state = _stateByShip[body]
    if state == nil then
        state = {
            seq = -1,
            shotId = 0,
            eventType = "idle",
            slotIndex = 1,
            weaponType = "",
            serverTime = 0.0,
            firePoint = { x = 0.0, y = 0.0, z = 0.0 },
            hitPoint = { x = 0.0, y = 0.0, z = 0.0 },
            didHit = 0,
            didHitStellarisBody = 0,
            didHitShield = 0,
            hitTargetBodyId = 0,
            normal = { x = 0.0, y = 1.0, z = 0.0 },
            impactLayer = "none",
        }
        _stateByShip[body] = state
    end
    return state
end

-- ============ API函数（内部使用，通过API文件暴露） ============

local _renderAPI = {}

function _renderAPI.receiveRenderEvent(
    shipBodyId,
    seq,
    shotId,
    eventType,
    slotIndex,
    weaponType,
    serverTime,
    fireX,
    fireY,
    fireZ,
    hitX,
    hitY,
    hitZ,
    didHit,
    didHitStellarisBody,
    didHitShield,
    hitTargetBodyId,
    normalX,
    normalY,
    normalZ,
    impactLayer
)
    local state = _ensureState(shipBodyId)
    if state == nil then return end

    state.seq = math.floor(seq or -1)
    state.shotId = math.floor(shotId or 0)
    state.eventType = tostring(eventType or "idle")
    state.slotIndex = math.floor(slotIndex or 1)
    state.weaponType = tostring(weaponType or "")
    state.serverTime = tonumber(serverTime) or 0.0
    state.firePoint = { x = tonumber(fireX) or 0.0, y = tonumber(fireY) or 0.0, z = tonumber(fireZ) or 0.0 }
    state.hitPoint = { x = tonumber(hitX) or 0.0, y = tonumber(hitY) or 0.0, z = tonumber(hitZ) or 0.0 }
    state.didHit = math.floor(didHit or 0)
    state.didHitStellarisBody = math.floor(didHitStellarisBody or 0)
    state.didHitShield = math.floor(didHitShield or 0)
    state.hitTargetBodyId = math.floor(hitTargetBodyId or 0)
    state.normal = { x = tonumber(normalX) or 0.0, y = tonumber(normalY) or 1.0, z = tonumber(normalZ) or 0.0 }
    state.impactLayer = tostring(impactLayer or "none")
end

function _renderAPI.getEvent(shipBodyId)
    local body = math.floor(shipBodyId or 0)
    if body <= 0 then return nil end
    return _stateByShip[body]
end

-- 将API导出到client表，供API文件使用
client._xSlotRenderStateAPI = _renderAPI

-- ============ 规范化的模块接口 ============

function client.xSlotRenderStateInit()
    _stateByShip = {}
end

function client.xSlotRenderStateTick(dt)
    -- X槽渲染状态通常不需要每tick更新
    -- 但保留接口以符合规范
end
