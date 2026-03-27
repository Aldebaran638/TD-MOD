-- 该脚本的body点击左键以后向前方发射快子光�?
-- 111
#version 2
#include "script/include/common.lua"

#include "server/ship_data.lua"
#include "server/weapon_data.lua"

#include "server/shipRuntimeState.lua"
#include "server/registry/shipRegistry.lua"
#include "server/registry/shipRegistryRequest.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field


-- server = server or {}

-- -- registry 访问�?
-- #include "server/registry/shipRegistry.lua"

-- 服务端函数：注册“当前这艘飞船”到 Registry�?
-- 当前飞船�?server.shipBody 指定；该脚本只维护这一艘飞船�?
function server.registerCurrentShip(shipType)

    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    server.registryShipRegister(shipBodyId, shipType, server.defaultShipType)
    return true
end

-- 服务端函数：确保“当前这艘飞船”在 Registry 中存在�?
-- 若当前飞船还未注册，则按默认飞船模板补齐运行时状态�?
function server.ensureCurrentShipState(shipType)
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return false
    end
    return server.registryShipEnsure(shipBodyId, shipType or server.defaultShipType, server.defaultShipType)
end

-- x 槽控制模块从外部抽取为独立文件：script/server/weapon_fire/xSlotControl.lua
#include "server/weapon_fire/lSlotState.lua"
#include "server/weapon_fire/mainWeaponControl.lua"
#include "server/weapon_fire/xSlotState.lua"
#include "server/weapon_fire/xSlotRenderState.lua"
#include "server/weapon_fire/xSlotControl.lua"
#include "server/weapon_fire/lSlotControl.lua"
#include "server/weapon_fire/projectileManager.lua"
-- 移动类模块：根据 body 质量施加竖直向上�?
#include "server/movement/bodyMassUpwardMove.lua"
-- 移动类模块：根据 W/S 输入施加前后推进�?
#include "server/movement/bodyDirectionalMove.lua"
-- 移动类模块：接收客户�?moveState 更新
#include "server/movement/bodyMoveStateReceive.lua"
-- 移动类模块：始终施加与速度反向的平方阻�?
#include "server/movement/bodyVelocityQuadraticDamping.lua"
-- 移动类模�?根据 registry 中的姿态误差施加扭矩进行自动调�?
#include "server/movement/shipAttitudeController.lua"
#include "server/movement/shipRollStabilizer.lua"
#include "server/movement/shipDeathExplosion.lua"
#include "server/recovery/shipHpRecovery.lua"

-- 服务端初始化
function server.init()
    -- -- 当前武器状�?
    -- -- "idle"      空闲
    -- -- "charging"  充能�?
    -- -- "launching" 发射�?
    -- server.weaponState = "idle"

    -- -- 上一帧武器状�?用于检测状态变化的第一�?
    -- server.weaponStateLastTick = "idle"

    -- -- 充能所需时间
    -- server.chargeTime = 20

    -- -- 发射持续时间
    -- server.launchTime = 0.2

    -- 初始化当前飞船
    server.shipBody = FindBody("stellarisShip", false)
    SetBool("StellarisShips/debug/inputTestEnabled", false)
    -- 注册当前飞船并加载飞船数�?
    server.registerCurrentShip("enigmaticCruiser")
    server.shipRuntimeStateInit(server.shipBody, "enigmaticCruiser", server.defaultShipType)
    server.mainWeaponRequestInit()
    server.xSlotStateInit("enigmaticCruiser")
    server.xSlotRenderStateInit()
    server.lSlotStateInit("enigmaticCruiser")
    server.shipRuntimeSyncMainWeapon(server.shipBody, true)

end

-- 在tick中使用到的变�?
-- server.weaponState 当前武器状�?"idle"/"charging"/"launching")
-- server.weaponStateLastTick 武器在上一帧的状�?用于检测状态变化的第一�?
-- server.chargeTime 飞船充能所需时间
-- server.launchTime 飞船发射持续时间
function server.serverTick(dt)
    -- server.ensureCurrentShipState(defaultShipType)
    server.mainWeaponControlTick(dt)
    server.shipRuntimeStateSyncTick(dt)
    server.xSlotControlTick(dt)
    server.lSlotControlTick(dt)
    server.projectileManagerTick(dt)
    server.shipHpRecoveryTick(dt)
    server.shipDeathExplosionTick(dt)
    server.bodyMoveStateReceiveTick(dt)
    server.bodyMassUpwardMoveTick(dt)
    server.bodyDirectionalMoveTick(dt)
    server.bodyVelocityQuadraticDampingTick(dt)
end

function server.update(dt)
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end

#include "client/client.lua"


-- 客户�?tick：只调用总控函数
function client.tick(dt)
    client.clientTick(dt)
end

function client.draw()
    client.clientDraw()
end

function server.tick(dt)
    server.serverTick(dt)

end








