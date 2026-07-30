-- 该脚本的body点击左键以后向前方发射快子光
-- 111
#version 2
#include "script/include/common.lua"

#include "data/ships/ship_catalog.lua"
#include "data/weapons/weapon_catalog.lua"

#include "net/server_sync_limiter.lua"
#include "net/network_debug.lua"
#include "ship/common/server/bootstrap.lua"
#include "weapon/server/bootstrap.lua"

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

local configuredShipType = GetStringParam("shiptype", "enigmaticCruiser")

-- server = server or {}

-- -- registry 访问

-- x 槽控制模块位于独立的武器系统目录中。
-- 移动类模块：根据 body 质量施加竖直向上
-- 移动类模块：根据 W/S 输入施加前后推进
-- 移动类模块：接收客户moveState 更新
-- 移动类模块：始终施加与速度反向的平方阻
-- 移动类模根据 registry 中的姿态误差施加扭矩进行自动调

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
    local shipBody = server.shipServerInit(configuredShipType)
    server.slotLoadoutInit(configuredShipType)
    server.weaponRuntimeInit(configuredShipType)
    server.shipRuntimeSyncMainWeapon(shipBody, true)
    server.shipWeaponSyncConfiguration(configuredShipType)

end

-- 在tick中使用到的变
-- server.weaponState 当前武器状"idle"/"charging"/"launching")
-- server.weaponStateLastTick 武器在上一帧的状用于检测状态变化的第一
-- server.chargeTime 飞船充能所需时间
-- server.launchTime 飞船发射持续时间
function server.serverTick(dt)
    server.networkDebugTick(dt)
    -- server.ensureCurrentShipState(defaultShipType)
    server.weaponRuntimeCommandTick(dt)
    server.weaponRuntimeSimulationTick(dt)
    server.shipServerTick(dt)
end

function server.update(dt)
    server.weaponRuntimeUpdate(dt)
    server.shipServerUpdate(dt)
end

function server.postUpdate()
    server.weaponRuntimePostUpdate()
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








