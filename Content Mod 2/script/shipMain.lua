-- 该脚本的body点击左键以后向前方发射快子光
-- 111
#version 2
#include "script/include/common.lua"

#include "data/ships/ship_catalog.lua"
#include "data/weapons/weapon_catalog.lua"

#include "net/server_sync_limiter.lua"
#include "net/network_debug.lua"
#include "ship/battlecruiser/server/state/runtime_state.lua"
#include "ship/battlecruiser/server/state/runtime_state_api.lua"
#include "weapon/server/common/loadout/slot_loadout.lua"
#include "weapon/server/common/loadout/slot_loadout_api.lua"
#include "ship/battlecruiser/server/registry/ship_registry.lua"
#include "ship/battlecruiser/server/registry/ship_registry_request.lua"
#include "ship/battlecruiser/server/bootstrap/ship_init.lua"
#include "weapon/server/common/runtime/damage.lua"
#include "weapon/server/common/runtime/behavior_registry.lua"
#include "weapon/server/behaviors/common.lua"
#include "weapon/server/behaviors/raycast.lua"
#include "weapon/server/behaviors/projectile.lua"
#include "weapon/server/behaviors/rocket_projectile.lua"
#include "weapon/server/behaviors/guided_projectile.lua"
#include "weapon/server/behaviors/strike_craft.lua"
#include "weapon/server/common/runtime/weapon_group.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field


-- server = server or {}

-- -- registry 访问

-- x 槽控制模块位于独立的武器系统目录中。
#include "weapon/server/slots/l/kinetic_artillery/state.lua"
#include "ship/battlecruiser/server/control/main_weapon_control.lua"
#include "ship/battlecruiser/server/control/main_weapon_control_api.lua"
#include "weapon/server/slots/x/tachyon_lance/state.lua"
#include "weapon/server/slots/x/tachyon_lance/render_state.lua"
#include "weapon/server/slots/x/tachyon_lance/muzzle_light.lua"
#include "weapon/server/slots/x/tachyon_lance/control.lua"
#include "weapon/server/slots/l/kinetic_artillery/control.lua"
#include "weapon/server/guided/runtime.lua"
#include "weapon/server/guided/movement.lua"
#include "weapon/server/guided/collider.lua"
#include "ship/battlecruiser/server/control/guided_slot_group.lua"
#include "ship/battlecruiser/server/control/m_slot_control.lua"
#include "ship/battlecruiser/server/control/g_slot_control.lua"
#include "weapon/server/slots/h/gamma_strike_craft/control.lua"
#include "weapon/server/slots/l/kinetic_artillery/projectile_manager.lua"
-- 移动类模块：根据 body 质量施加竖直向上
#include "ship/battlecruiser/server/movement/body_mass_upward_move.lua"
-- 移动类模块：根据 W/S 输入施加前后推进
#include "ship/battlecruiser/server/movement/body_directional_move.lua"
-- 移动类模块：接收客户moveState 更新
#include "ship/battlecruiser/server/movement/body_move_state_receive.lua"
-- 移动类模块：始终施加与速度反向的平方阻
#include "ship/battlecruiser/server/movement/body_velocity_quadratic_damping.lua"
-- 移动类模根据 registry 中的姿态误差施加扭矩进行自动调
#include "ship/battlecruiser/server/movement/ship_attitude_controller.lua"
#include "ship/battlecruiser/server/movement/ship_roll_stabilizer.lua"
#include "ship/battlecruiser/server/movement/ship_death_explosion.lua"
#include "ship/battlecruiser/server/recovery/ship_hp_recovery.lua"

-- 服务端初始化
function server.init()
    -- -- 当前武器状
    -- -- "idle"      空闲
    -- -- "charging"  充能
    -- -- "launching" 发射
    -- server.weaponState = "idle"

    -- -- 上一帧武器状用于检测状态变化的第一
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
    server.tachyonMuzzleLightInit()
    server.lSlotStateInit("enigmaticCruiser")
    server.guidedProjectileRuntimeInit()
    server.mSlotControlInit("enigmaticCruiser")
    server.gSlotControlInit("enigmaticCruiser")
    server.hSlotStateInit("enigmaticCruiser")
    server.weaponGroupInit("enigmaticCruiser")
    server.shipRuntimeSyncMainWeapon(server.shipBody, true)
    server.shipWeaponSyncConfiguration("enigmaticCruiser")

end

-- 在tick中使用到的变
-- server.weaponState 当前武器状"idle"/"charging"/"launching")
-- server.weaponStateLastTick 武器在上一帧的状用于检测状态变化的第一
-- server.chargeTime 飞船充能所需时间
-- server.launchTime 飞船发射持续时间
function server.serverTick(dt)
    server.networkDebugTick(dt)
    -- server.ensureCurrentShipState(defaultShipType)
    server.mainWeaponControlTick(dt)
    server.weaponGroupTick(dt)
    server.runtimeStateTick(dt)
    server.xSlotControlTick(dt)
    server.tachyonMuzzleLightTick(dt)
    server.lSlotControlTick(dt)
    server.mSlotControlTick(dt)
    server.gSlotControlTick(dt)
    server.guidedProjectileRuntimeTick(dt)
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
    server.guidedProjectileMovementUpdate(dt)
    server.shipAttitudeControllerUpdate(dt)
    server.shipRollStabilizerUpdate(dt)
end

function server.postUpdate()
    server.guidedProjectileColliderPostUpdate()
end

#include "client.lua"


-- 客户tick：只调用总控函数
function client.tick(dt)
    client.clientTick(dt)
end

function client.draw()
    client.clientDraw()
end

function server.tick(dt)
    server.serverTick(dt)

end








