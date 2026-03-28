-- x-slot charging fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotChargingFxState = client.xSlotChargingFxState or {
    chargeStateByShip = {},
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
    activeParticles = {},  -- 存储活跃的粒子
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _safeNormalize(v, fallback)
    local len = VecLength(v)
    if len < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / len)
end

local function _vecLerp(a, b, t)
    return Vec(
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t
    )
end

local function _clearChargeState(shipBodyId)
    client.xSlotChargingFxState.chargeStateByShip[shipBodyId] = nil
end

local function _beginInfernalChargeState(shipBodyId, render)
    local shipT = GetBodyTransform(shipBodyId)
    local fireWorld = _tableToVec(render.firePoint)
    local fireLocal = TransformToLocalPoint(shipT, fireWorld)
    client.xSlotChargingFxState.chargeStateByShip[shipBodyId] = {
        weaponType = tostring(render.weaponType or ""),
        slotIndex = math.floor(render.slotIndex or 1),
        phase = "charging",
        fireLocal = fireLocal,
        chargeStartedAt = (GetTime ~= nil) and GetTime() or 0.0,
    }
end

local function _createParticle(spawnPos, targetPoint, initialVel, finalVel, life)
    -- 限制粒子数量最多为1000个
    local particles = client.xSlotChargingFxState.activeParticles
    if #particles >= 1000 then
        return
    end
    
    local particle = {
        pos = Vec(spawnPos[1], spawnPos[2], spawnPos[3]),
        vel = Vec(initialVel[1], initialVel[2], initialVel[3]),
        targetPoint = Vec(targetPoint[1], targetPoint[2], targetPoint[3]),
        initialVel = Vec(initialVel[1], initialVel[2], initialVel[3]),
        finalVel = Vec(finalVel[1], finalVel[2], finalVel[3]),
        maxLife = life,
        startTime = (GetTime ~= nil) and GetTime() or 0.0,
        arrived = false,
        arrivedTime = 0.0,
        baseRadius = 0.1,  -- 初始半径很小
    }
    table.insert(client.xSlotChargingFxState.activeParticles, particle)
end

local function _updateParticles(dt)
    local particles = client.xSlotChargingFxState.activeParticles
    local i = #particles
    
    -- DebugWatch调试信息
    if DebugWatch ~= nil then
        DebugWatch("ChargingFX.ActiveParticles", i)
    end
    
    while i >= 1 do
        local p = particles[i]
        
        -- 计算生命周期进度
        local elapsed = ((GetTime ~= nil) and GetTime() or 0.0) - p.startTime
        local t = elapsed / math.max(0.0001, p.maxLife)
        
        -- 计算到目标点的距离
        local distToTarget = VecLength(VecSub(p.targetPoint, p.pos))
        
        -- 检查是否到达目标点
        if not p.arrived and distToTarget < 1.0 then
            p.arrived = true
            p.arrivedTime = (GetTime ~= nil) and GetTime() or 0.0
        end
        
        if p.arrived then
            -- 到达后的效果：半径翻倍，强烈发光持续0.4秒
            local arrivedElapsed = ((GetTime ~= nil) and GetTime() or 0.0) - p.arrivedTime
            local arrivedT = arrivedElapsed / 0.4  -- 0.4秒持续时间
            
            if arrivedT >= 1.0 then
                -- 效果结束，移除粒子
                particles[i] = particles[#particles]
                particles[#particles] = nil
            else
                -- 渲染到达后的粒子
                local alpha = 1.0 - arrivedT
                local radius = p.baseRadius * 8.0  -- 半径变为8倍（原来4倍+100%）
                
                ParticleReset()
                ParticleColor(1.0, 0.9, 0.5, 1.0, 0.6, 0.2)  -- 更亮的颜色
                ParticleRadius(radius, 0.02, "easeout")
                ParticleAlpha(alpha * 1.0, 0.0)  -- 更强的透明度
                ParticleGravity(0.0)
                ParticleDrag(0.0)
                ParticleEmissive(50.0 + alpha * 30.0, 0.0)  -- 更强的发光
                ParticleCollide(0.0)
                
                local randomVel = Vec(
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1
                )
                SpawnParticle(p.pos, randomVel, 0.1)
            end
        else
            -- 到达前的效果：根据到xz平面的距离调整速度
            if t >= 1.0 then
                -- 生命周期结束，移除粒子
                particles[i] = particles[#particles]
                particles[#particles] = nil
            else
                -- 计算到xz平面的距离（y值的绝对值）
                local distToXZPlane = math.abs(p.pos[2] - p.targetPoint[2])
                
                -- 计算到目标点的方向
                local toTargetDir = VecSub(p.targetPoint, p.pos)
                toTargetDir = _safeNormalize(toTargetDir, Vec(0, 0, 0))
                
                -- 根据到xz平面的距离调整速度分量
                -- 距离越远，y方向速度越大；距离越近，xz方向速度越大
                local maxDist = 7.0  -- 最大距离
                local distRatio = math.min(1.0, distToXZPlane / maxDist)  -- 归一化距离
                
                -- y方向速度：使用四次方根衰减，确保粒子能到达xz平面
                -- 设置最小速度阈值，确保粒子始终有足够的速度到达xz平面
                local minYSpeed = 3.33  -- 最小y速度（降低到2/3）
                local maxYSpeed = 13.6  -- 最大y速度（降低到2/3）
                local ySpeed = minYSpeed + math.pow(distRatio, 0.25) * (maxYSpeed - minYSpeed)  -- 四次方根衰减
                
                -- xz方向速度：随距离减小而增大（降低到2/3）
                local xzSpeed = (1.0 - distRatio) * 5.6 + 0.93  -- 最小0.93，最大6.53
                
                -- 计算xz方向（指向目标点）
                local xzDir = Vec(toTargetDir[1], 0, toTargetDir[3])
                xzDir = _safeNormalize(xzDir, Vec(0, 0, 0))
                
                -- 合成速度
                p.vel = Vec(
                    xzDir[1] * xzSpeed,
                    toTargetDir[2] * ySpeed,  -- y方向指向目标点
                    xzDir[3] * xzSpeed
                )
                
                -- 更新位置
                p.pos = VecAdd(p.pos, VecScale(p.vel, dt))
                
                -- 计算半径：随时间增大（从0.1到0.3）
                local radius = p.baseRadius + t * 0.2
                
                -- 渲染粒子
                local alpha = 1.0 - t
                ParticleReset()
                ParticleColor(1.0, 0.8, 0.2, 1.0, 0.4, 0.0)
                ParticleRadius(radius, 0.01, "easeout")
                ParticleAlpha(alpha * 0.9, 0.0)
                ParticleGravity(0.0)
                ParticleDrag(0.0)
                ParticleEmissive(25.0 + alpha * 15.0, 0.0)
                ParticleCollide(0.0)
                
                local randomVel = Vec(
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1,
                    (math.random() - 0.5) * 0.1
                )
                SpawnParticle(p.pos, randomVel, 0.1)
            end
        end
        
        i = i - 1
    end
end

local function _spawnChargingParticles(shipBodyId, chargeState, frameDt)
    local shipT = GetBodyTransform(shipBodyId)
    local fireLocal = chargeState.fireLocal or Vec(0, 0, 0)
    local fireWorld = TransformToParentPoint(shipT, fireLocal)
    local barrelDir = _safeNormalize(TransformToParentVec(shipT, Vec(0, 0, -1)), Vec(0, 0, -1))
    local segmentLength = 11.5
    local segmentEnd = VecAdd(fireWorld, VecScale(barrelDir, segmentLength))
    
    -- 将线段分成10份，得到11个点
    local divisions = 10
    local points = {}
    for i = 0, divisions do
        local t = i / divisions
        points[i] = VecAdd(fireWorld, VecScale(VecSub(segmentEnd, fireWorld), t))
    end
    
    -- 计算粒子数量（降低30%）
    local particleCount = math.max(1, math.floor((1.05) * math.max(0.68, (frameDt or 0.016) * 60.0)))
    
    -- 获取飞船的右向量和上向量用于计算方向
    local shipRight = TransformToParentVec(shipT, Vec(1, 0, 0))
    local shipUp = TransformToParentVec(shipT, Vec(0, 1, 0))
    
    -- 为前10个点生成扇形汇聚粒子（不包括第11个点）
    for pointIndex = 0, divisions - 1 do
        local targetPoint = points[pointIndex]
        
        -- 根据点的索引确定角度范围
        local angleRanges
        if pointIndex <= 7 then
            -- 前8个点（索引0-7）：30°~150°和-30°~-150°
            angleRanges = {
                {math.rad(30), math.rad(150)},   -- 右侧范围
                {math.rad(-150), math.rad(-30)}  -- 左侧范围
            }
        else
            -- 后2个点（索引8-9）：0°~150°和0°~-150°
            angleRanges = {
                {math.rad(0), math.rad(150)},    -- 右侧范围
                {math.rad(-150), math.rad(0)}    -- 左侧范围
            }
        end
        
        -- 生成扇形汇聚粒子
        for _ = 1, particleCount do
            -- 随机选择一个角度范围
            local rangeIndex = math.random(1, 2)
            local minAngle = angleRanges[rangeIndex][1]
            local maxAngle = angleRanges[rangeIndex][2]
            
            -- 在角度范围内随机选择角度
            local angle = minAngle + math.random() * (maxAngle - minAngle)
            
            -- 随机半径：3~6
            local radius = 3.0 + math.random() * 3.0
            
            -- 随机y值：-7~-2或2~7（两个区间）
            local yOffset
            if math.random() < 0.5 then
                yOffset = -7.0 + math.random() * 5.0  -- -7~-2
            else
                yOffset = 2.0 + math.random() * 5.0   -- 2~7
            end
            
            -- 计算粒子生成位置（在xz平面上）
            -- 使用barrelDir作为前方向，shipRight作为右方向
            local cosAngle = math.cos(angle)
            local sinAngle = math.sin(angle)
            
            -- 方向：在barrelDir和shipRight构成的平面上
            local dir = VecAdd(VecScale(barrelDir, cosAngle), VecScale(shipRight, sinAngle))
            dir = _safeNormalize(dir, barrelDir)
            
            -- 粒子生成位置：目标点 + 方向 * 半径 + y偏移
            local spawnPos = VecAdd(targetPoint, VecScale(dir, radius))
            spawnPos[2] = spawnPos[2] + yOffset
            
            -- 计算初始速度：快速向xz平面靠近（y方向）
            local initialSpeed = 6.0 + math.random() * 6.0  -- 调大为原来的3倍
            
            -- 初始速度：主要沿y方向（向xz平面靠近）
            -- 如果粒子在上方，给一个向下的速度；如果在下方，给一个向上的速度
            local yVel = -yOffset * 0.8  -- 向xz平面靠近的速度
            local initialVel = Vec(0, yVel, 0)
            
            -- 计算最终速度：指向目标点，速度较快
            local velDir = VecSub(targetPoint, spawnPos)
            velDir = _safeNormalize(velDir, barrelDir)
            local finalSpeed = 5.0 + math.random() * 5.0
            local finalVel = VecScale(velDir, finalSpeed)
            
            -- 粒子生命周期（增加以确保能到达目标点）
            local life = 2.0 + math.random() * 1.0
            
            -- 创建自定义粒子
            _createParticle(spawnPos, targetPoint, initialVel, finalVel, life)
        end
        
        -- 在目标点添加光源
        PointLight(targetPoint, 1.0, 0.8, 0.2, 4.0)
    end
end

function client.xSlotChargingFxTick(dt)
    local state = client.xSlotChargingFxState
    local frameDt = dt or 0.0
    
    -- 更新所有活跃的粒子
    _updateParticles(frameDt)

    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local render = client.xSlotRenderGetEvent(shipBodyId)
            if render ~= nil then
                local seq = render.seq or -1
                local shotId = render.shotId or -1
                local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1

                if seq ~= lastSeq then
                    if render.weaponType == "infernalRay" then
                        if render.eventType == "charging_start" or render.eventType == "charged_hold" then
                            _beginInfernalChargeState(shipBodyId, render)
                        else
                            _clearChargeState(shipBodyId)
                        end
                    else
                        _clearChargeState(shipBodyId)
                    end

                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        else
            _clearChargeState(shipBodyId)
        end
    end

    for shipBodyId, chargeState in pairs(state.chargeStateByShip) do
        if not client.registryShipExists(shipBodyId) then
            state.chargeStateByShip[shipBodyId] = nil
        else
            _spawnChargingParticles(shipBodyId, chargeState, frameDt)
        end
    end
end
