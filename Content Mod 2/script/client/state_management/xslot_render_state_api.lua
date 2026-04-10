---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- xslot_render_state_api.lua
-- 客户端X槽渲染状态管理的API文件
-- 提供对外访问渲染状态的接口

client = client or {}

-- 从主模块获取内部API实现
local _api = client._xSlotRenderStateAPI

-- 如果API未加载，提供空实现
if _api == nil then
    _api = {}
end

-- 服务端调用的回调函数，接收渲染事件
function client.receiveXSlotRenderEvent(
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
    _api.receiveRenderEvent(
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
end

function client.xSlotRenderGetEvent(shipBodyId)
    return _api.getEvent(shipBodyId)
end