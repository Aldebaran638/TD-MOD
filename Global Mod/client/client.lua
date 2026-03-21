---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

-- -- 先广播接收模块，再输入模块，最后渲染模�?
-- #include "receive_boardcast/xSlotReceiveBroadcast.lua"
#include "registry/shipRegistry.lua"
#include "input_handling/xSlotInput.lua"
#include "input_handling/bodyMoveInput.lua"
#include "input_handling/rotationInput.lua"

-- 获取本地玩家 ID（用于定位当前玩家所在飞船）
local function _resolveLocalPlayerId()
    return GetLocalPlayer()
end

function client.clientTick(dt)
    DebugWatch("client.clientTick",00000)
    local localPlayerId = _resolveLocalPlayerId()
    if localPlayerId ~= nil then
        local veh = GetPlayerVehicle(localPlayerId)
        if veh ~= nil and veh ~= 0 then
            local body = GetVehicleBody(veh)
        else

        end
    else

    end
    DebugWatch("client.clientTick",11111)
    -- 输入处理（请求写入）
    client.xSlotInputTick(dt)
    client.bodyMoveInputTick(dt)
    client.rotationInputTick(dt)
    
    -- 输入模块调试（受 StellarisShips/debug/inputTestEnabled 控制�?
    if client.debugTestXSlotInputTick ~= nil then
        client.debugTestXSlotInputTick(dt)
    end
    if client.debugTestBodyMoveInputTick ~= nil then
        client.debugTestBodyMoveInputTick(dt)
    end
    -- 渲染更新
    client.xSlotChargingFxTick(dt)
    client.xSlotLaunchFxTick(dt)
    client.shieldHitFxTick(dt)
    client.hitPointFxTick(dt)

end

function client.clientDraw()

end

function client.render()

end

