---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local inputTestEnabledKey = "StellarisShips/debug/inputTestEnabled"

-- 检测测试模式是否开启（由全局键控制）
local function _inputTestEnabled()
    if GetBool == nil then
        return false
    end
    return GetBool(inputTestEnabledKey)
end

-- 获取本地玩家 ID（用于后续读取玩家所驾驶的载具）
local function _resolveLocalPlayerId()
    return GetLocalPlayer()
end

-- 每帧调试入口（已停用，保留空函数避免外部调用报错）
function client.debugTestXSlotInputTick(dt)
end

-- x 槽输入主逻辑
-- 目标：检测左键输入，并把“开火请求”写入 Registry，交给服务端状态机消费
function client.xSlotInputTick(dt)
    -- 步骤1：检测玩家左键状态（只在“按下瞬间”触发）
    if not InputPressed("lmb") then
        return
    end

    -- 步骤2：确认本地玩家存在
    local localPlayerId = _resolveLocalPlayerId()
    if localPlayerId == nil then
        return
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

    -- 步骤6：客户端修改全局键（提交 x 槽总开火请求）
    -- 说明：这里只负责“提请求”，不直接改变武器状态；真正的 charging/launching 由服务端决定
    client.registryShipSetXSlotsRequest(body, 1)
end
