---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local moveRequestKeepAliveInterval = 0.2
local inputTestEnabledKey = "StellarisShips/debug/inputTestEnabled"

-- 本地输入同步状态缓存
-- 用途：减少无意义写入，并支持“状态变化立刻发 + 固定间隔保活重发”
client.bodyMoveInputState = client.bodyMoveInputState or {
    localPlayerId = nil,
    lastMoveState = -1,
    lastShipBodyId = 0,
    lastSyncAt = -1000,
}

-- 检测测试模式是否开启（由全局键控制）
local function _inputTestEnabled()
    if GetBool == nil then
        return false
    end
    return GetBool(inputTestEnabledKey)
end

-- 获取本地玩家 ID（并缓存，避免每帧重复查询）
local function _resolveLocalPlayerId()
    local state = client.bodyMoveInputState
    if state.localPlayerId ~= nil and state.localPlayerId ~= 0 then
        return state.localPlayerId
    end

    local pid = GetLocalPlayer()
    if pid ~= nil and pid ~= -1 and pid ~= 0 then
        state.localPlayerId = pid
        return pid
    end

    return nil
end

-- 每帧调试入口（已停用，保留空函数避免外部调用报错）
function client.debugTestBodyMoveInputTick(dt)
end

-- 移动输入主逻辑：把 W/S 输入同步到 Registry 的 move 请求键
function client.bodyMoveInputTick(dt)
    local state = client.bodyMoveInputState

    -- 步骤1：确认本地玩家存在
    local localPlayerId = _resolveLocalPlayerId()
    if localPlayerId == nil then
        return
    end

    -- 步骤2：读取按键并映射 moveState（W=1, S=2, 无输入=0）
    local wDown = InputDown("w") and true or false
    local sDown = InputDown("s") and true or false
    local moveState = 0
    if wDown then
        moveState = 1
    elseif sDown then
        moveState = 2
    end

    -- 步骤3：确认玩家正在驾驶载具
    local veh = GetPlayerVehicle(localPlayerId)
    if veh == nil or veh == 0 then
        return
    end

    -- 步骤4：获取当前载具 bodyId
    local body = GetVehicleBody(veh)
    if body == nil or body == 0 then
        return
    end

    -- 步骤5：通过 exists 判断是否为群星船
    if not client.registryShipExists(body) then
        return
    end

    -- 步骤6：发送策略 = 状态变化立刻发 + 固定间隔保活发
    local now = (GetTime ~= nil) and GetTime() or 0
    local changed = (moveState ~= state.lastMoveState) or (body ~= state.lastShipBodyId)
    local keepAliveDue = (now - (state.lastSyncAt or -1000)) >= moveRequestKeepAliveInterval

    if (not changed) and (not keepAliveDue) then
        return
    end

    -- 步骤7：更新本地已发送状态缓存
    state.lastMoveState = moveState
    state.lastShipBodyId = body
    state.lastSyncAt = now

    -- 步骤8：客户端提交移动请求到服务器
    client.registryShipSetMoveRequestState(body, moveState)
end
