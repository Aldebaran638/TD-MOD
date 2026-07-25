-- Guided missile impact effect.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local function _resolveMissileImpactColors(impactLayer)
    if impactLayer == "shield" then
        return 0.25, 0.90, 1.00, 0.08, 0.32, 1.00
    elseif impactLayer == "armor" then
        return 0.95, 0.72, 0.22, 1.00, 0.42, 0.08
    elseif impactLayer == "body" then
        return 0.95, 0.38, 0.18, 0.85, 0.22, 0.06
    end
    return 0.78, 0.88, 1.00, 0.35, 0.48, 0.85
end

local function _randomMissileImpactDirection()
    local z = 2.0 * math.random() - 1.0
    local angle = math.random() * math.pi * 2.0
    local radius = math.sqrt(math.max(0.0, 1.0 - z * z))
    return Vec(radius * math.cos(angle), z, radius * math.sin(angle))
end

function client.playMissileImpactFx(hitX, hitY, hitZ, impactLayer)
    local pos = Vec(hitX or 0, hitY or 0, hitZ or 0)
    local r1, g1, b1, r2, g2, b2 = _resolveMissileImpactColors(tostring(impactLayer or "body"))

    PointLight(pos, r1, g1, b1, 6.0)

    ParticleReset()
    ParticleColor(r1, g1, b1, r2, g2, b2)
    ParticleRadius(0.35, 0.0, "easeout")
    ParticleAlpha(0.94, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.02)
    ParticleEmissive(25.0, 0.0)
    ParticleCollide(0.0)
    for _ = 1, 40 do
        local direction = _randomMissileImpactDirection()
        local spawnPos = VecAdd(pos, VecScale(direction, 0.5 * math.random()))
        local velocity = VecScale(direction, 8.0 + 6.0 * math.random())
        SpawnParticle(spawnPos, velocity, 0.8 + 0.2 * math.random())
    end

    ParticleReset()
    ParticleColor(r1, g1, b1, r2, g2, b2)
    ParticleRadius(0.5, 0.0, "easeout")
    ParticleAlpha(0.8, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.01)
    ParticleEmissive(20.0, 0.0)
    ParticleCollide(0.0)
    for _ = 1, 30 do
        local direction = _randomMissileImpactDirection()
        local spawnPos = VecAdd(pos, VecScale(direction, 0.8 + 0.3 * math.random()))
        local velocity = VecScale(direction, 6.0 + 4.0 * math.random())
        SpawnParticle(spawnPos, velocity, 1.0 + 0.3 * math.random())
    end
end
