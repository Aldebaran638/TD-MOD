---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.missileWarpFxConfig = client.missileWarpFxConfig or {
    preFlashDuration = 0.03,
    mainFlashDuration = 0.05,
    energyRipDuration = 0.15,
    afterglowDuration = 0.3,
    totalDuration = 0.5,
    preFlashIntensity = 10.0,
    mainFlashIntensity = 40.0,
    afterglowIntensity = 8.0,
    energyRipParticleCount = 240,
    energyRipParticleSpeed = 16.0,
    energyRipSwirlStrength = 1.0,
    energyRipColorStart = { 0.2, 0.5, 1.0, 1.0 },
    energyRipColorEnd = { 1.0, 1.0, 1.0, 0.0 },
    mainFlashSize = 6.0,
}

client.missileWarpFxState = client.missileWarpFxState or {
    effects = {},
}

function client.spawnMissileWarpFx(x, y, z)
    table.insert(client.missileWarpFxState.effects, {
        position = Vec(x or 0, y or 0, z or 0),
        life = 0,
        maxLife = client.missileWarpFxConfig.totalDuration,
    })
end

function client.missileWarpFxClear()
    client.missileWarpFxState.effects = {}
end

function client.missileWarpFxTick(dt)
    local effects = client.missileWarpFxState.effects
    local cfg = client.missileWarpFxConfig
    local i = #effects
    while i >= 1 do
        local effect = effects[i]
        effect.life = effect.life + dt
        local progress = effect.life / effect.maxLife
        
        if effect.life <= cfg.preFlashDuration then
            -- Phase 1: 预闪
            local preFlashProgress = effect.life / cfg.preFlashDuration
            local intensity = cfg.preFlashIntensity * math.pow(preFlashProgress, 2)
            
            -- 快速增强的光源
            PointLight(effect.position, 1.0, 1.0, 1.0, intensity)
            
            -- 微弱的能量粒子开始聚集
            if preFlashProgress > 0.5 then
                ParticleReset()
                ParticleColor(0.2, 0.5, 1.0, 1.0, 0.2, 0.5, 1.0, 0.0)
                ParticleRadius(0.1, 0.0, "easeout")
                ParticleAlpha(0.3, 0.0)
                ParticleGravity(0.0)
                ParticleDrag(0.5)
                ParticleEmissive(5.0, 0.0)
                ParticleCollide(0.0)
                
                for j = 1, 8 do
                    local angle1 = math.random() * math.pi * 2
                    local angle2 = math.acos(2 * math.random() - 1)
                    local x = math.sin(angle2) * math.cos(angle1)
                    local y = math.sin(angle2) * math.sin(angle1)
                    local z = math.cos(angle2)
                    local dir = Vec(x, y, z)
                    local pos = VecAdd(effect.position, VecScale(dir, 0.1 + preFlashProgress * 0.4))
                    local vel = VecScale(dir, -2.0)
                    SpawnParticle(pos, vel, 0.1)
                end
            end
        elseif effect.life <= cfg.preFlashDuration + cfg.mainFlashDuration then
            -- Phase 2: 主闪光
            local mainFlashProgress = (effect.life - cfg.preFlashDuration) / cfg.mainFlashDuration
            
            -- 极高亮度的白爆
            local flashSize = cfg.mainFlashSize * mainFlashProgress
            local alpha = 1.0 - mainFlashProgress
            
            -- 使用粒子模拟白爆效果
            ParticleReset()
            ParticleColor(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0)
            ParticleRadius(flashSize, 0.0, "linear")
            ParticleAlpha(alpha, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.0)
            ParticleEmissive(cfg.mainFlashIntensity, 0.0)
            ParticleCollide(0.0)
            
            SpawnParticle(effect.position, Vec(0, 0, 0), cfg.mainFlashDuration)
            
            -- 同时开始能量撕裂效果
            if mainFlashProgress < 0.3 then
                -- 能量撕裂的初始爆发
                ParticleReset()
                ParticleColor(
                    cfg.energyRipColorStart[1], cfg.energyRipColorStart[2], cfg.energyRipColorStart[3], cfg.energyRipColorStart[4],
                    cfg.energyRipColorEnd[1], cfg.energyRipColorEnd[2], cfg.energyRipColorEnd[3], cfg.energyRipColorEnd[4]
                )
                ParticleRadius(0.2, 0.0, "easeout")
                ParticleAlpha(1.0, 0.0)
                ParticleGravity(0.0)
                ParticleDrag(0.2)
                ParticleEmissive(15.0, 0.0)
                ParticleCollide(0.0)
                
                for j = 1, cfg.energyRipParticleCount do
                    local angle1 = math.random() * math.pi * 2
                    local angle2 = math.acos(2 * math.random() - 1)
                    local x = math.sin(angle2) * math.cos(angle1)
                    local y = math.sin(angle2) * math.sin(angle1)
                    local z = math.cos(angle2)
                    local dir = Vec(x, y, z)
                    
                    -- 添加旋转/涡流效果
                    local swirl = Vec(
                        y * cfg.energyRipSwirlStrength,
                        -x * cfg.energyRipSwirlStrength,
                        0
                    )
                    local vel = VecAdd(VecScale(dir, cfg.energyRipParticleSpeed), swirl)
                    
                    SpawnParticle(effect.position, vel, cfg.energyRipDuration)
                end
            end
        elseif effect.life <= cfg.preFlashDuration + cfg.mainFlashDuration + cfg.energyRipDuration then
            -- Phase 3: 能量撕裂（持续）
            -- 已经在主闪光阶段开始了能量撕裂效果
            -- 这里可以添加一些额外的粒子来增强效果
            local ripProgress = (effect.life - cfg.preFlashDuration - cfg.mainFlashDuration) / cfg.energyRipDuration
            
            if ripProgress < 0.3 then
                -- 补充一些粒子
                ParticleReset()
                ParticleColor(
                    cfg.energyRipColorStart[1], cfg.energyRipColorStart[2], cfg.energyRipColorStart[3], cfg.energyRipColorStart[4],
                    cfg.energyRipColorEnd[1], cfg.energyRipColorEnd[2], cfg.energyRipColorEnd[3], cfg.energyRipColorEnd[4]
                )
                ParticleRadius(0.1, 0.0, "easeout")
                ParticleAlpha(0.8, 0.0)
                ParticleGravity(0.0)
                ParticleDrag(0.3)
                ParticleEmissive(20.0, 0.0)
                ParticleCollide(0.0)
                
                for j = 1, 40 do
                    local angle1 = math.random() * math.pi * 2
                    local angle2 = math.acos(2 * math.random() - 1)
                    local x = math.sin(angle2) * math.cos(angle1)
                    local y = math.sin(angle2) * math.sin(angle1)
                    local z = math.cos(angle2)
                    local dir = Vec(x, y, z)
                    local vel = VecScale(dir, cfg.energyRipParticleSpeed * 0.7)
                    
                    SpawnParticle(effect.position, vel, cfg.energyRipDuration * 0.7)
                end
            end
        elseif effect.life <= cfg.totalDuration then
            -- Phase 4: 余辉（收尾）
            local afterglowProgress = (effect.life - cfg.preFlashDuration - cfg.mainFlashDuration - cfg.energyRipDuration) / cfg.afterglowDuration
            local afterglowIntensity = cfg.afterglowIntensity * math.exp(-afterglowProgress * 3)
            
            -- 残留微光
            PointLight(effect.position, 0.2, 0.5, 1.0, afterglowIntensity)
            
            -- 少量粒子逐渐消散
            if afterglowProgress < 0.5 then
                ParticleReset()
                ParticleColor(
                    cfg.energyRipColorStart[1], cfg.energyRipColorStart[2], cfg.energyRipColorStart[3], 0.5,
                    cfg.energyRipColorEnd[1], cfg.energyRipColorEnd[2], cfg.energyRipColorEnd[3], 0.0
                )
                ParticleRadius(0.2, 0.0, "easeout")
                ParticleAlpha(0.5, 0.0)
                ParticleGravity(0.0)
                ParticleDrag(0.5)
                ParticleEmissive(15.0, 0.0)
                ParticleCollide(0.0)
                
                for j = 1, 15 do
                    local angle1 = math.random() * math.pi * 2
                    local angle2 = math.acos(2 * math.random() - 1)
                    local x = math.sin(angle2) * math.cos(angle1)
                    local y = math.sin(angle2) * math.sin(angle1)
                    local z = math.cos(angle2)
                    local dir = Vec(x, y, z)
                    local vel = VecScale(dir, cfg.energyRipParticleSpeed * 0.3)
                    
                    SpawnParticle(effect.position, vel, cfg.afterglowDuration * 0.8)
                end
            end
        else
            -- 特效结束
            table.remove(effects, i)
        end
        
        i = i - 1
    end
end