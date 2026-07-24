-- 该脚本的body点击左键以后向前方发射快子光�?
-- 111
#version 2
#include "script/include/common.lua"

#include "data/ship/ship_data.lua"
#include "data/weapon/weapon_data.lua"

#include "ship/battlecruiser/server/state/runtime_state.lua"
#include "ship/battlecruiser/server/state/runtime_state_api.lua"
#include "weapon/server/loadout/slot_loadout.lua"
#include "weapon/server/loadout/slot_loadout_api.lua"
#include "ship/battlecruiser/server/registry/shipRegistry.lua"
#include "ship/battlecruiser/server/registry/shipRegistryRequest.lua"
#include "ship/battlecruiser/server/initialization/ship_init.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field


-- server = server or {}

-- -- registry 访问�?
-- #include "ship/battlecruiser/server/registry/shipRegistry.lua"

-- x 槽控制模块位于独立的武器系统目录中。
#include "weapon/server/controllers/lSlotState.lua"
#include "weapon/server/controllers/main_weapon_control.lua"
#include "weapon/server/controllers/main_weapon_control_api.lua"
#include "weapon/server/controllers/xSlotState.lua"
#include "weapon/server/controllers/xSlotRenderState.lua"
#include "weapon/server/controllers/xSlotControl.lua"
#include "weapon/server/controllers/lSlotControl.lua"
#include "weapon/server/controllers/sSlotState.lua"
#include "weapon/server/controllers/sSlotLauncher.lua"
#include "weapon/server/controllers/sSlotMovement.lua"
#include "weapon/server/controllers/sSlotCollider.lua"
#include "weapon/server/controllers/hSlotControl.lua"
#include "weapon/server/controllers/projectileManager.lua"
-- 移动类模块：根据 body 质量施加竖直向上�?
#include "ship/battlecruiser/server/movement/bodyMassUpwardMove.lua"
-- 移动类模块：根据 W/S 输入施加前后推进�?
#include "ship/battlecruiser/server/movement/bodyDirectionalMove.lua"
-- 移动类模块：接收客户�?moveState 更新
#include "ship/battlecruiser/server/movement/bodyMoveStateReceive.lua"
-- 移动类模块：始终施加与速度反向的平方阻�?
#include "ship/battlecruiser/server/movement/bodyVelocityQuadraticDamping.lua"
-- 移动类模�?根据 registry 中的姿态误差施加扭矩进行自动调�?
#include "ship/battlecruiser/server/movement/shipAttitudeController.lua"
#include "ship/battlecruiser/server/movement/shipRollStabilizer.lua"
#include "ship/battlecruiser/server/movement/shipDeathExplosion.lua"
#include "ship/battlecruiser/server/recovery/shipHpRecovery.lua"

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
    server.shipInitInit("enigmaticCruiser")
    server.runtimeStateInit(server.shipBody, "enigmaticCruiser", server.defaultShipType)
    server.slotLoadoutInit("enigmaticCruiser")
    server.mainWeaponControlInit()
    server.xSlotStateInit("enigmaticCruiser")
    server.xSlotRenderStateInit()
    server.lSlotStateInit("enigmaticCruiser")
    server.sSlotStateInit("enigmaticCruiser")
    server.hSlotStateInit("enigmaticCruiser")
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
    server.runtimeStateTick(dt)
    server.xSlotControlTick(dt)
    server.lSlotControlTick(dt)
    server.sSlotLauncherTick(dt)
    server.hSlotControlTick(dt)
    server.projectileManagerTick(dt)
    server.shipHpRecoveryTick(dt)
    server.shipDeathExplosionTick(dt)
    server.bodyMoveStateReceiveTick(dt)
    server.bodyMassUpwardMoveTick(dt)
    server.bodyDirectionalMoveTick(dt)
    server.bodyVelocityQuadraticDampingTick(dt)
end

function server.update(dt)
    server.sSlotMovementUpdate(dt)
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end

function server.postUpdate()
    server.sSlotColliderPostUpdate()
end

#include "client.lua"


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








