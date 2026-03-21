-- 命中点粒子特效模块
-- 职责：读取所有已注册飞船的 xSlots/render/* 渲染事件，
--       在 launch_start 命中帧生成爆炸性粒子特效。
-- 外部接口：client.hitPointFxTick(dt)  —— 每帧调用

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

-- 模块内部状态
client.hitPointFxState = client.hitPointFxState or {
    activeEffects = {},      -- 特效实例数组，支持多船并发；每项都记录 shipBodyId
    lastRenderSeqByShip = {},-- 按船记录已消费 seq，用于门控新事件
    lastShotIdByShip = {},   -- 按船记录已消费 shotId，辅助调试与去重追踪
}

-- {x,y,z} 表格 → Teardown Vec
local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

-- 安全归一化：向量长度过小时返回 fallback
local function _safeNormalize(v, fallback)
    local l = VecLength(v)
    if l < 0.0001 then return fallback end
    return VecScale(v, 1.0 / l)
end

-- 构建法线垂直基（用于环形散射粒子）
local function _buildPerpBasis(n)
    local up = Vec(0, 1, 0)
    local t1 = VecCross(up, n)
    t1 = _safeNormalize(t1, Vec(1, 0, 0))
    local t2 = VecCross(n, t1)
    t2 = _safeNormalize(t2, Vec(0, 1, 0))
    return t1, t2
end

-- 内部：根据 impactLayer 选定粒子颜色对（明色/暗色）
local function _resolveLayerColors(impactLayer)
    if impactLayer == "shield" then
        return 0.20, 0.95, 1.00,  0.10, 0.35, 1.00   -- 护盾：青白
    elseif impactLayer == "armor" then
        return 1.00, 0.80, 0.20,  1.00, 0.40, 0.10   -- 装甲：橙黄
    elseif impactLayer == "body" then
        return 1.00, 0.30, 0.15,  0.90, 0.20, 0.05   -- 船体：红橙
    else
        return 0.80, 0.80, 0.80,  0.50, 0.50, 0.50   -- 环境/未知：灰白
    end
end

-- 内部：一次性喷发命中粒子（仅在特效第一帧调用）
-- 说明：launch_start 事件在 Registry 中会持续整个 launchDuration 期间，
--       客户端不会因单帧延迟而错过命中数据；粒子由 Teardown 粒子系统独立维持。
local function _spawnHitParticles(entry)
    local pos    = entry.pos
    local n      = _safeNormalize(entry.normal, Vec(0, 1, 0))
    local t1, t2 = _buildPerpBasis(n)
    local r1, g1, b1, r2, g2, b2 = _resolveLayerColors(entry.impactLayer)

    -- 单帧点光闪烁（视觉冲击感）
    PointLight(pos, r1, g1, b1, 4.0)

    -- 环形冲击波粒子（多圈由内向外）
    ParticleReset()
    ParticleColor(r1, g1, b1, r2, g2, b2)
    ParticleRadius(0.13, 0.03, "easeout")
    ParticleAlpha(0.85, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.18)
    ParticleEmissive(18.0, 0.0)
    ParticleCollide(0.0)
    for ring = 1, 4 do
        local count  = (20 + ring * 6) + math.random(-4, 4)
        local radius = 0.15 * ring + 0.10 * math.random()
        local speed  = 5.0 + ring * 2.0
        for i = 1, count do
            local a   = ((i - 1) / count) * math.pi * 2.0
            local lat = VecAdd(VecScale(t1, math.cos(a)), VecScale(t2, math.sin(a)))
            local p   = VecAdd(pos, VecScale(lat, radius))
            local vel = VecAdd(
                VecScale(lat, speed + 2.0 * math.random()),
                VecScale(n,   1.5 * math.random())
            )
            SpawnParticle(p, vel, 0.16 + 0.12 * math.random())
        end
    end

    -- 飞溅粒子（法线方向半球面随机喷射）
    ParticleReset()
    ParticleColor(r1, g1, b1, r2, g2, b2)
    ParticleRadius(0.09, 0.02, "easeout")
    ParticleAlpha(0.9, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.15)
    ParticleEmissive(16.0, 0.0)
    ParticleCollide(0.0)
    for i = 1, 24 do
        local dx  = (math.random() - 0.5) * 1.6
        local dz  = (math.random() - 0.5) * 1.6
        local dir = VecAdd(VecAdd(VecScale(n, 1.0), VecScale(t1, dx)), VecScale(t2, dz))
        local l   = VecLength(dir)
        if l < 0.001 then l = 1.0 end
        dir = VecScale(dir, 1.0 / l)
        SpawnParticle(pos, VecScale(dir, 12.0 + 8.0 * math.random()), 0.16 + 0.10 * math.random())
    end
end

-- 内部：追加一条新特效实例到 activeEffects
local function _hitPointFxStart(shipBodyId, pos, normal, impactLayer, didHitShield)
    table.insert(client.hitPointFxState.activeEffects, {
        shipBodyId   = shipBodyId,
        pos          = pos,
        normal       = normal,
        age          = 0,
        life         = 0.6,        -- 特效生命期（秒）；粒子本身由 Teardown 自行管理
        impactLayer  = impactLayer or "none",
        didHitShield = didHitShield,
        played       = false,      -- false = 尚未喷发粒子
    })
end

-- 命中点特效 tick（公开接口，每帧调用）
function client.hitPointFxTick(dt)
    local state = client.hitPointFxState

    -- 步骤1：事件消费——遍历所有注册飞船，检测 launch_start 新命中事件
    -- 说明：每条飞船的 seq 独立递增；仅当该船 seq 变化、eventType 为 launch_start
    --       且 didHit==1 时创建实例，避免同一事件重复触发。
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
                    if render.eventType == "launch_start" and render.didHit == 1 then
                        local pos = _tableToVec(render.hitPoint)
                        local normal = _tableToVec(render.normal)
                        _hitPointFxStart(shipBodyId, pos, normal, render.impactLayer, render.didHitShield == 1)
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end

    -- 步骤2：实例更新——推进 age，第一帧喷发粒子，移除过期实例
    -- 说明：反向迭代以安全地 table.remove，不影响未处理下标。
    local effects = state.activeEffects
    local i = #effects
    while i >= 1 do
        local entry = effects[i]
        entry.age = entry.age + dt

        -- 第一帧（age 从 0 被推进后）：立即喷发粒子
        if not entry.played then
            _spawnHitParticles(entry)
            entry.played = true
        end

        -- 超过生命期则移除
        if entry.age >= entry.life then
            table.remove(effects, i)
        end

        i = i - 1
    end
end
