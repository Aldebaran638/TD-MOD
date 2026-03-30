---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.projectileVisualConfig = client.projectileVisualConfig or {
    particleRadius = 0.18,
    emissive = 18.0,
    colorA = { 0.42, 1.0, 0.55 },
    colorB = { 0.08, 0.88, 0.22 },
    trailLife = 0.65,
    impactLife = 0.55,
    impactCount = 36,
    trailSpacing = 8.0,
    maxTrailParticlesPerTick = 12,
    pointLightRadius = 5.0,
    tailDrag = 0.24,
    tailVelocityFactor = 0.01,
    impactSphereShellCount = 84,
    impactSphereCoreCount = 42,
    impactSphereRadius = 0.85,
    impactSphereLifeMin = 0.55,
    impactSphereLifeMax = 0.95,
}

client.projectileVisualState = client.projectileVisualState or {
    byId = {},
}

local function _projectileColor(cfg)
    local ca = cfg.colorA or { 1.0, 0.85, 0.45 }
    local cb = cfg.colorB or { 1.0, 0.45, 0.12 }
    return ca, cb
end

function client.spawnProjectileVisual(projectileId, weaponType, px, py, pz, vx, vy, vz, lifeRemain)
    local _ = weaponType
    client.projectileVisualState.byId[projectileId] = {
        id = projectileId,
        position = Vec(px or 0, py or 0, pz or 0),
        lastPosition = Vec(px or 0, py or 0, pz or 0),
        velocity = Vec(vx or 0, vy or 0, vz or 0),
        lifeRemain = tonumber(lifeRemain) or 0.0,
    }
end

local function _spawnProjectileImpact(pos)
    local cfg = client.projectileVisualConfig
    local ca, cb = _projectileColor(cfg)

    PointLight(pos, ca[1], ca[2], ca[3], (cfg.pointLightRadius or 7.0) * 1.35)
    PointLight(pos, cb[1], cb[2], cb[3], (cfg.pointLightRadius or 7.0) * 0.95)

    ParticleReset()
    ParticleColor(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
    ParticleRadius(cfg.particleRadius * 1.10, 0.08, "easeout")
    ParticleAlpha(0.98, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.10)
    ParticleEmissive((cfg.emissive or 18.0) * 1.1, 0.0)
    ParticleCollide(0.0)

    local shellCount = cfg.impactSphereShellCount or cfg.impactCount or 36
    local shellRadius = cfg.impactSphereRadius or 0.85
    for _ = 1, shellCount do
        local dir = VecNormalize(Vec(
            math.random() - 0.5,
            math.random() - 0.5,
            math.random() - 0.5
        ))
        local spawnPos = VecAdd(pos, VecScale(dir, shellRadius * (0.35 + 0.65 * math.random())))
        local vel = VecScale(dir, 2.5 + math.random() * 3.5)
        local life = (cfg.impactSphereLifeMin or 0.42) + ((cfg.impactSphereLifeMax or 0.72) - (cfg.impactSphereLifeMin or 0.42)) * math.random()
        SpawnParticle(spawnPos, vel, life)
    end

    ParticleReset()
    ParticleColor(1.0, 0.98, 0.92, cb[1], cb[2], cb[3])
    ParticleRadius(cfg.particleRadius * 0.75, 0.03, "easeout")
    ParticleAlpha(0.82, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.18)
    ParticleEmissive((cfg.emissive or 18.0) * 0.85, 0.0)
    ParticleCollide(0.0)

    for _ = 1, cfg.impactSphereCoreCount or 24 do
        local dir = VecNormalize(Vec(
            math.random() - 0.5,
            math.random() - 0.5,
            math.random() - 0.5
        ))
        local spawnPos = VecAdd(pos, VecScale(dir, shellRadius * 0.25 * math.random()))
        local vel = VecScale(dir, 1.0 + math.random() * 2.0)
        local life = 0.26 + math.random() * 0.18
        SpawnParticle(spawnPos, vel, life)
    end
end

function client.finishProjectileVisual(projectileId, mode, hitX, hitY, hitZ)
    local visuals = client.projectileVisualState.byId
    visuals[projectileId] = nil

    if mode == "impact" then
        _spawnProjectileImpact(Vec(hitX or 0, hitY or 0, hitZ or 0))
    end
end

function client.projectileVisualTick(dt)
    local visuals = client.projectileVisualState.byId
    local cfg = client.projectileVisualConfig
    local ca, cb = _projectileColor(cfg)

    for projectileId, projectile in pairs(visuals) do
        local stepDt = math.min(math.max(projectile.lifeRemain or 0.0, 0.0), math.max(dt or 0.0, 0.0))
        if stepDt <= 0.0 then
            visuals[projectileId] = nil
        else
            projectile.lastPosition = Vec(projectile.position[1], projectile.position[2], projectile.position[3])
            projectile.position = VecAdd(projectile.position, VecScale(projectile.velocity, stepDt))
            projectile.lifeRemain = (projectile.lifeRemain or 0.0) - dt

            local dir = VecNormalize(projectile.velocity)
            local speed = VecLength(projectile.velocity)
            local particleVel = VecScale(dir, math.max(0.0, speed * (cfg.tailVelocityFactor or 0.01)))
            local moveVec = VecSub(projectile.position, projectile.lastPosition)
            local moveLen = VecLength(moveVec)
            local spacing = math.max(1.0, cfg.trailSpacing or 12.0)
            local particleCount = math.max(1, math.ceil(moveLen / spacing))
            particleCount = math.min(particleCount, cfg.maxTrailParticlesPerTick or 8)

            ParticleReset()
            ParticleColor(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
            ParticleRadius(cfg.particleRadius or 0.18, 0.02, "easeout")
            ParticleAlpha(0.96, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(cfg.tailDrag or 0.24)
            ParticleEmissive(cfg.emissive or 18.0, 0.0)
            ParticleCollide(0.0)

            for i = 0, particleCount - 1 do
                local t = 1.0
                if particleCount > 1 then
                    t = i / (particleCount - 1)
                end
                local pos = VecAdd(projectile.lastPosition, VecScale(moveVec, t))
                SpawnParticle(pos, particleVel, cfg.trailLife or 0.28)
            end

            PointLight(projectile.position, cb[1], cb[2], cb[3], cfg.pointLightRadius or 6.0)

            if projectile.lifeRemain <= 0.0 then
                visuals[projectileId] = nil
            end
        end
    end
end
