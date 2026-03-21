-- x 槽发射光束特效模块
-- 职责：读取所有已注册飞船的 xSlots/render/* 渲染事件，
--       在 launch_start 阶段生成从 firePoint 到 hitPoint 的能量束。
-- 外部接口：client.xSlotLaunchFxTick(dt)  —— 每帧调用

---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

-- 模块内部状态
client.xSlotLaunchFxState = client.xSlotLaunchFxState or {
    activeEffects = {},      -- 光束实例数组，支持多船并发；每项都记录 shipBodyId
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

-- 构建与 forward 正交的 right/up 基向量
local function _buildPerpBasis(forward)
    local upWorld = Vec(0, 1, 0)
    local right = VecCross(upWorld, forward)
    right = _safeNormalize(right, Vec(1, 0, 0))
    local up = VecCross(forward, right)
    up = _safeNormalize(up, Vec(0, 1, 0))
    return right, up
end

-- 内部：追加一条新光束实例到 activeEffects
-- 说明：launch_start 发生后仅追加，不会清空旧光束，避免短时间连射互相覆盖。
local function _xSlotLaunchFxStart(shipBodyId, firePointWorld, hitPointWorld, impactLayer)
    local beamVec = VecSub(hitPointWorld, firePointWorld)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then return end

    table.insert(client.xSlotLaunchFxState.activeEffects, {
        shipBodyId = shipBodyId,
        fire = firePointWorld,
        hit = hitPointWorld,
        age = 0,
        life = 0.18,
        width = 0.45,
        impactLayer = impactLayer or "none",
    })
end

-- x 槽发射特效 tick（公开接口，每帧调用）
function client.xSlotLaunchFxTick(dt)
    local state = client.xSlotLaunchFxState

    -- 步骤1：事件消费——遍历所有注册飞船，检测 launch_start 新事件
    -- 说明：每条飞船的 seq 独立递增；仅当该船 seq 变化才消费。
    --       launch_start 事件触发时为该船追加一条光束实例。
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
                    if render.eventType == "launch_start" then
                        _xSlotLaunchFxStart(shipBodyId, _tableToVec(render.firePoint), _tableToVec(render.hitPoint), render.impactLayer)
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end

    -- 步骤2：实例更新——推进 age，逐帧渲染光束与伴随粒子，过期后移除
    -- 说明：反向迭代删除可避免数组下标错位；appearFrac 让光束平滑出现。
    local effects = state.activeEffects
    local now = GetTime()
    local i = #effects
    while i >= 1 do
        local fx = effects[i]
        fx.age = fx.age + dt

        if fx.age >= fx.life then
            table.remove(effects, i)
        else
            local fire = fx.fire
            local hit = fx.hit
            local width = fx.width
            local pulse = 0.5 + 0.5 * math.sin(now * 45.0)

            local beamVec = VecSub(hit, fire)
            local beamLen = VecLength(beamVec)
            local beamDir = VecScale(beamVec, 1.0 / math.max(beamLen, 0.001))
            local appearFrac = math.min(1.0, fx.age / 0.06)
            local right, up = _buildPerpBasis(beamDir)

            -- 主光束（核心 + 次级辉光）
            DrawLine(fire, hit, width * appearFrac, 1.0, 1.0, 1.0)
            DrawLine(fire, hit, width * 0.55 * appearFrac, 0.75, 1.0, (0.55 + 0.25 * pulse) * appearFrac)

            -- 外圈电弧感：四条偏移细线
            local glowRadius = (0.07 + 0.04 * pulse) * appearFrac
            local offsets = {
                VecScale(right, glowRadius),
                VecScale(right, -glowRadius),
                VecScale(up, glowRadius),
                VecScale(up, -glowRadius),
            }
            for j = 1, #offsets do
                local o = offsets[j]
                DrawLine(VecAdd(fire, o), VecAdd(hit, o), width * 0.18 * appearFrac, 0.85, 1.0, 0.25 * appearFrac)
            end

            -- 光束周边冲击粒子
            ParticleReset()
            ParticleColor(0.20, 0.95, 1.00, 0.10 * appearFrac, 0.35 * appearFrac, 1.00 * appearFrac)
            ParticleRadius(0.09 * appearFrac, 0.02 * appearFrac, "easeout")
            ParticleAlpha(0.9 * appearFrac, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.15)
            ParticleEmissive(16.0 * appearFrac, 0.0)
            ParticleCollide(0.0)
            for _ = 1, 6 do
                local frac = math.random()
                local along = VecAdd(fire, VecScale(beamDir, beamLen * frac))
                local angle = now * 2.0 + math.random() * math.pi * 2
                local offset = VecAdd(
                    VecScale(right, math.cos(angle) * (glowRadius + width * 0.2 * appearFrac)),
                    VecScale(up, math.sin(angle) * (glowRadius + width * 0.2 * appearFrac))
                )
                local p = VecAdd(along, offset)
                local vel = VecAdd(VecScale(beamDir, (18.0 + 8.0 * math.random()) * appearFrac), VecScale(offset, 2.0 * math.random() * appearFrac))
                SpawnParticle(p, vel, (0.12 + 0.08 * math.random()) * appearFrac)
            end

            -- 枪口点光闪烁
            PointLight(fire, 0.2 * appearFrac, 0.9 * appearFrac, 1.0 * appearFrac, (6.0 + 4.0 * pulse) * appearFrac)
        end

        i = i - 1
    end
end
