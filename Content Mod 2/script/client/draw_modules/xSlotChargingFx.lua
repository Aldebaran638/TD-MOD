-- x 槽蓄力粒子特效模块
-- 职责：读取所有已注册飞船的 xSlots/render/* 渲染事件，
--       在 charging_start 阶段生成飞向炮口的能量汇聚光点。
-- 外部接口：client.xSlotChargingFxTick(dt)  —— 每帧调用

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

-- 模块内部状态
client.xSlotChargingFxState = client.xSlotChargingFxState or {
    activeEffects = {},      -- 特效实例数组，支持多船并发；每项都记录 shipBodyId
    lastRenderSeqByShip = {},-- 按船记录已消费 seq，用于门控新事件
    lastShotIdByShip = {},   -- 按船记录已消费 shotId，辅助调试与去重追踪
}

-- {x,y,z} 表格 → Teardown Vec
local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

-- 清理指定飞船的全部蓄力特效实例
local function _clearEffectsByShip(shipBodyId)
    local effects = client.xSlotChargingFxState.activeEffects
    local i = #effects
    while i >= 1 do
        if effects[i].shipBodyId == shipBodyId then
            table.remove(effects, i)
        end
        i = i - 1
    end
end

-- 内部：追加一批蓄力光点到 activeEffects
-- 说明：该函数只做追加，不主动清空旧实例；是否清空由事件分支控制。
local function _xSlotChargingFxStart(shipBodyId, firePointWorld)
    local fxRadius = 1.8
    local fxCount = 5
    local fxDuration = 0.7

    for _ = 1, fxCount do
        local theta = math.random() * math.pi * 2
        local phi = math.acos(2 * math.random() - 1)
        local r = math.random() * fxRadius
        local dx = r * math.sin(phi) * math.cos(theta)
        local dy = r * math.sin(phi) * math.sin(theta)
        local dz = r * math.cos(phi)

        table.insert(client.xSlotChargingFxState.activeEffects, {
            shipBodyId = shipBodyId,
            spawnPos = VecAdd(firePointWorld, Vec(dx, dy, dz)),
            targetPos = firePointWorld,
            age = 0,
            life = fxDuration,
            radius = 0.08 + 0.04 * math.random(),
        })
    end
end

-- x 槽蓄力特效 tick（公开接口，每帧调用）
function client.xSlotChargingFxTick(dt)
    local state = client.xSlotChargingFxState

    -- 步骤1：事件消费——遍历所有注册飞船，检测 charging_start 新事件
    -- 说明：每条飞船的 seq 独立递增；仅当该船 seq 变化才消费。
    --       charging_start 为该船新建蓄力实例；launch_start/idle 清理该船残留蓄力实例。
    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local snapshot = client.registryShipGetSnapshot(shipBodyId)
            if snapshot ~= nil then
                local render = snapshot.xSlotsRender or {}
                local seq = render.seq or -1
                local shotId = render.shotId or -1
                local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1

                if seq ~= lastSeq then
                    if render.eventType == "charging_start" then
                        _clearEffectsByShip(shipBodyId)
                        _xSlotChargingFxStart(shipBodyId, _tableToVec(render.firePoint))
                    else
                        _clearEffectsByShip(shipBodyId)
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end

    -- 步骤2：实例更新——推进 age，插值渲染并移除过期实例
    -- 说明：反向迭代以安全地 table.remove，不影响未处理下标。
    local effects = state.activeEffects
    local i = #effects
    while i >= 1 do
        local entry = effects[i]
        entry.age = entry.age + dt

        if entry.age >= entry.life then
            table.remove(effects, i)
        else
            local t = math.min(1.0, entry.age / entry.life)
            local dir = VecSub(entry.targetPos, entry.spawnPos)
            local cur = VecAdd(entry.spawnPos, VecScale(dir, t))

            ParticleReset()
            ParticleColor(0.95, 1.0, 1.0, 0.10, 0.35, 1.00)
            ParticleRadius(entry.radius, 0.01, "easeout")
            ParticleAlpha(0.9, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.1)
            ParticleEmissive(12.0, 0.0)
            ParticleCollide(0.0)
            SpawnParticle(cur, Vec(0, 0, 0), entry.life - entry.age)
            PointLight(cur, 0.95, 1.0, 1.0, 2.0)
        end

        i = i - 1
    end
end
