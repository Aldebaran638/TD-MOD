---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local _configs = {
    swarmerMissile = {
        circleRadius = 0.45, circleParticleCount = 32, circleInterval = 0.1,
        particleLife = 1.0, particleRadius = 0.10, emissive = 25.0,
        color = { 0.20, 0.50, 1.00 },
    },
    devastatorTorpedo = {
        circleRadius = 0.70, circleParticleCount = 24, circleInterval = 0.12,
        particleLife = 1.2, particleRadius = 0.18, emissive = 22.0,
        color = { 1.00, 0.40, 0.10 },
    },
}

local function _configFor(weaponType)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    return _configs[tostring(definition.projectileFxVariant or "")] or _configs.swarmerMissile
end

client.missileVisualState = client.missileVisualState or { byId = {} }

function client.missileVisualInit()
    client.missileVisualState.byId = {}
end

function client.spawnMissileVisual(missileId, weaponType, px, py, pz, vx, vy, vz, lifetime)
    client.missileVisualState.byId[missileId] = {
        id = missileId,
        weaponType = tostring(weaponType or ""),
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
    local missile = client.missileVisualState.byId[missileId]
    if missile == nil then return end
    local _ = serverTime
    missile.correctionTargetPos = Vec(px or 0, py or 0, pz or 0)
    missile.correctionTargetVel = Vec(vx or 0, vy or 0, vz or 0)
    missile.correctionRemain = missile.correctionDuration
end

function client.updateMissileVisual(missileId, px, py, pz, vx, vy, vz)
    client.correctMissileVisual(missileId, px, py, pz, vx, vy, vz, 0.0)
end

local function _createCircleParticles(pos, velocity, cfg)
    local normal = VecNormalize(velocity)
    local up = Vec(0, 1, 0)
    if math.abs(VecDot(normal, up)) > 0.9 then up = Vec(1, 0, 0) end
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

    local count = cfg.circleParticleCount
    local radius = cfg.circleRadius
    for i = 0, count - 1 do
        local angle = (i / count) * math.pi * 2
        local circlePos = VecAdd(pos, VecAdd(
            VecScale(tangent1, math.cos(angle) * radius),
            VecScale(tangent2, math.sin(angle) * radius)
        ))
        SpawnParticle(circlePos, VecScale(normal, 0.5), cfg.particleLife)
    end
end

function client.missileVisualTick(dt)
    local currentTime = GetTime()
    for missileId, missile in pairs(client.missileVisualState.byId) do
        local step = math.max(0.0, dt or 0.0)
        missile.lifeRemain = missile.lifeRemain - step
        missile.position = VecAdd(missile.position, VecScale(missile.velocity, step))
        if (missile.correctionRemain or 0.0) > 0.0 and missile.correctionTargetPos ~= nil then
            local alpha = math.min(1.0, step / math.max(0.0001, missile.correctionRemain))
            missile.position = VecLerp(missile.position, missile.correctionTargetPos, alpha)
            missile.velocity = VecLerp(missile.velocity, missile.correctionTargetVel, alpha)
            missile.correctionRemain = math.max(0.0, missile.correctionRemain - step)
        end
        local cfg = _configFor(missile.weaponType)
        if currentTime - (missile.lastCircleTime or 0) >= cfg.circleInterval
            and VecLength(missile.velocity) > 0.1 then
            missile.lastCircleTime = currentTime
            _createCircleParticles(missile.position, missile.velocity, cfg)
        end
        if VecLength(VecSub(missile.position, GetCameraTransform().pos)) < 600 then
            client.playMissileLoopSound(missile.position[1], missile.position[2], missile.position[3])
        end
        if missile.lifeRemain <= 0.0 then client.missileVisualState.byId[missileId] = nil end
    end
end

function client.missileVisualRender()
end
