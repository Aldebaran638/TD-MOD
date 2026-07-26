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
    color = { 0.2, 0.5, 1.0, 1.0 },
    nearDistance = 100.0,
    mediumDistance = 300.0,
    farDistance = 600.0,
}

client.missileVisualState = client.missileVisualState or {
    byId = {},
}

function client.spawnMissileVisual(missileId, px, py, pz, vx, vy, vz, lifetime)
    client.missileVisualState.byId[missileId] = {
        id = missileId,
        position = Vec(px or 0, py or 0, pz or 0),
        velocity = Vec(vx or 0, vy or 0, vz or 0),
        lastCircleTime = 0,
        lifeRemain = math.max(1.0, tonumber(lifetime) or 10.0) + 2.0,
        correctionTargetPos = nil,
        correctionTargetVel = nil,
        correctionRemain = 0.0,
        correctionDuration = 0.15,
    }
    client.playMissileLoopSound(px or 0, py or 0, pz or 0)
end

function client.finishMissileVisual(missileId)
    client.missileVisualState.byId[missileId] = nil
end

function client.correctMissileVisual(missileId, px, py, pz, vx, vy, vz, serverTime)
    local visuals = client.missileVisualState.byId
    local missile = visuals[missileId]
    if missile then
        local _ = serverTime
        missile.correctionTargetPos = Vec(px or 0, py or 0, pz or 0)
        missile.correctionTargetVel = Vec(vx or 0, vy or 0, vz or 0)
        missile.correctionRemain = missile.correctionDuration or 0.15
    end
end

function client.updateMissileVisual(missileId, px, py, pz, vx, vy, vz)
    client.correctMissileVisual(missileId, px, py, pz, vx, vy, vz, 0.0)
end

local function _createCircleParticles(pos, velocity, cfg, particleCount)
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
    
    local count = math.max(1, math.floor(particleCount or cfg.circleParticleCount))
    local circleRadius = cfg.circleRadius
    
    for i = 0, count - 1 do
        local angle = (i / count) * math.pi * 2
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

local function _missileVisualResolveLod(distance, cfg)
    if distance < (cfg.nearDistance or 100.0) then
        return 20, 0.10
    end
    if distance < (cfg.mediumDistance or 300.0) then
        return 10, 0.15
    end
    if distance < (cfg.farDistance or 600.0) then
        return 5, 0.25
    end
    return 0, 1.0
end

function client.missileVisualTick(dt)
    local visuals = client.missileVisualState.byId
    local cfg = client.missileVisualConfig
    local currentTime = GetTime()
    local cameraPos = GetCameraTransform().pos

    for missileId, missile in pairs(visuals) do
        missile.lifeRemain = missile.lifeRemain - dt
        missile.position = VecAdd(
            missile.position,
            VecScale(missile.velocity, math.max(0.0, dt or 0.0))
        )

        if (missile.correctionRemain or 0.0) > 0.0
            and missile.correctionTargetPos ~= nil
            and missile.correctionTargetVel ~= nil then
            local remain = math.max(0.0001, missile.correctionRemain)
            local alpha = math.min(1.0, math.max(0.0, dt or 0.0) / remain)
            missile.position = VecAdd(
                missile.position,
                VecScale(
                    VecSub(missile.correctionTargetPos, missile.position),
                    alpha
                )
            )
            missile.velocity = VecAdd(
                missile.velocity,
                VecScale(
                    VecSub(missile.correctionTargetVel, missile.velocity),
                    alpha
                )
            )
            missile.correctionRemain = math.max(
                0.0,
                missile.correctionRemain - math.max(0.0, dt or 0.0)
            )
        end
        
        local cameraDistance = VecLength(VecSub(missile.position, cameraPos))
        local particleCount, particleInterval =
            _missileVisualResolveLod(cameraDistance, cfg)
        if particleCount > 0
            and currentTime - missile.lastCircleTime >= particleInterval then
            missile.lastCircleTime = currentTime
            local velocity = missile.velocity
            if VecLength(velocity) > 0.1 then
                _createCircleParticles(
                    missile.position,
                    velocity,
                    cfg,
                    particleCount
                )
            end
        end

        if cameraDistance < (cfg.farDistance or 600.0) then
            client.playMissileLoopSound(
                missile.position[1],
                missile.position[2],
                missile.position[3]
            )
        end

        if missile.lifeRemain <= 0.0 then
            visuals[missileId] = nil
        end
    end
end
