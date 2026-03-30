---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.missileVisualConfig = client.missileVisualConfig or {
    circleRadius = 0.45,
    circleParticleCount = 32,
    circleInterval = 0.1,
    particleLife = 1.0,
    particleRadius = 0.1,
    emissive = 25.0,
    color = { 0.78, 0.30, 1.0, 1.0 },
}

client.missileVisualState = client.missileVisualState or {
    byId = {},
}

function client.spawnMissileVisual(missileId, px, py, pz, vx, vy, vz)
    client.missileVisualState.byId[missileId] = {
        id = missileId,
        position = Vec(px or 0, py or 0, pz or 0),
        velocity = Vec(vx or 0, vy or 0, vz or 0),
        lastCircleTime = 0,
        lifeRemain = 1.0,
    }
    client.playMissileLoopSound(px or 0, py or 0, pz or 0)
end

function client.finishMissileVisual(missileId)
    client.missileVisualState.byId[missileId] = nil
end

function client.updateMissileVisual(missileId, px, py, pz, vx, vy, vz)
    local visuals = client.missileVisualState.byId
    local missile = visuals[missileId]
    if missile then
        missile.position = Vec(px or 0, py or 0, pz or 0)
        missile.velocity = Vec(vx or 0, vy or 0, vz or 0)
        missile.lifeRemain = 1.0
    end
end

local function _createCircleParticles(pos, velocity, cfg)
    local normal = VecNormalize(velocity)
    
    local up = Vec(0, 1, 0)
    if math.abs(VecDot(normal, up)) > 0.9 then
        up = Vec(1, 0, 0)
    end
    local tangent1 = VecNormalize(VecCross(normal, up))
    local tangent2 = VecNormalize(VecCross(normal, tangent1))
    
    ParticleReset()
    ParticleColor(cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[1], cfg.color[2], cfg.color[3])
    ParticleRadius(cfg.particleRadius, 0.0, "easeout")
    ParticleAlpha(1.0, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.1)
    ParticleEmissive(cfg.emissive, 0.0)
    ParticleCollide(0.0)
    
    local particleCount = cfg.circleParticleCount
    local circleRadius = cfg.circleRadius
    
    for i = 0, particleCount - 1 do
        local angle = (i / particleCount) * math.pi * 2
        local x = math.cos(angle)
        local y = math.sin(angle)
        local circlePos = VecAdd(
            pos,
            VecAdd(
                VecScale(tangent1, x * circleRadius),
                VecScale(tangent2, y * circleRadius)
            )
        )
        local particleVel = VecScale(normal, 0.5)
        SpawnParticle(circlePos, particleVel, cfg.particleLife)
    end
end

function client.missileVisualTick(dt)
    local visuals = client.missileVisualState.byId
    local cfg = client.missileVisualConfig
    local currentTime = GetTime()

    for missileId, missile in pairs(visuals) do
        missile.lifeRemain = missile.lifeRemain - dt
        
        if currentTime - missile.lastCircleTime >= cfg.circleInterval then
            missile.lastCircleTime = currentTime
            local velocity = missile.velocity
            if VecLength(velocity) > 0.1 then
                _createCircleParticles(missile.position, velocity, cfg)
            end
        end

        client.playMissileLoopSound(missile.position[1], missile.position[2], missile.position[3])

        if missile.lifeRemain <= 0.0 then
            visuals[missileId] = nil
        end
    end
end
