-- hit point impact fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.hitPointFxState = client.hitPointFxState or {
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _resolveLayerColors(impactLayer)
    if impactLayer == "shield" then
        return 0.25, 0.90, 1.00, 0.08, 0.32, 1.00
    elseif impactLayer == "armor" then
        return 0.95, 0.72, 0.22, 1.00, 0.42, 0.08
    elseif impactLayer == "body" then
        return 0.95, 0.38, 0.18, 0.85, 0.22, 0.06
    else
        return 0.78, 0.88, 1.00, 0.35, 0.48, 0.85
    end
end

local function _randomUnitVec()
    local z = 2.0 * math.random() - 1.0
    local a = math.random() * math.pi * 2.0
    local r = math.sqrt(math.max(0.0, 1.0 - z * z))
    return Vec(r * math.cos(a), z, r * math.sin(a))
end

local function _safeNormalize(v, fallback)
    local l = VecLength(v)
    if l < 0.0001 then return fallback end
    return VecScale(v, 1.0 / l)
end

local function _randomTangent(dir)
    local cand = _randomUnitVec()
    local t = VecSub(cand, VecScale(dir, VecDot(cand, dir)))
    if VecLength(t) < 0.001 then
        t = VecCross(dir, Vec(0, 1, 0))
    end
    if VecLength(t) < 0.001 then
        t = VecCross(dir, Vec(1, 0, 0))
    end
    return _safeNormalize(t, Vec(1, 0, 0))
end

local function _spawnSphericalShockwave(pos, impactLayer, didHitShield)
    local r1, g1, b1, r2, g2, b2 = _resolveLayerColors(impactLayer)

    PointLight(pos, r1, g1, b1, 6.0)

    -- 内部核心：创建一个实心的球体效果
    ParticleReset()
    ParticleColor(r1, g1, b1, r2, g2, b2)
    ParticleRadius(0.35, 0.0, "easeout")
    ParticleAlpha(0.94, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.02)
    ParticleEmissive(25.0, 0.0)
    ParticleCollide(0.0)
    for _ = 1, 40 do
        local dir = _randomUnitVec()
        local startRadius = 0.0 + 0.5 * math.random()
        local spawnPos = VecAdd(pos, VecScale(dir, startRadius))
        local radialSpeed = 8.0 + 6.0 * math.random()
        local vel = VecScale(dir, radialSpeed)
        local life = 0.8 + 0.2 * math.random()
        SpawnParticle(spawnPos, vel, life)
    end

    -- 外部球体：创建一个明显的球形边界
    ParticleReset()
    ParticleColor(r1, g1, b1, r2, g2, b2)
    ParticleRadius(0.5, 0.0, "easeout")
    ParticleAlpha(0.8, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.01)
    ParticleEmissive(20.0, 0.0)
    ParticleCollide(0.0)
    for _ = 1, 30 do
        local dir = _randomUnitVec()
        local startRadius = 0.8 + 0.3 * math.random()
        local spawnPos = VecAdd(pos, VecScale(dir, startRadius))
        local radialSpeed = 6.0 + 4.0 * math.random()
        local vel = VecScale(dir, radialSpeed)
        local life = 1.0 + 0.3 * math.random()
        SpawnParticle(spawnPos, vel, life)
    end

    if didHitShield then
        PointLight(pos, 0.22, 0.88, 1.0, 6.5)
    end
end

function client.playMissileImpactFx(hitX, hitY, hitZ, impactLayer)
    _spawnSphericalShockwave(
        Vec(hitX or 0, hitY or 0, hitZ or 0),
        tostring(impactLayer or "body"),
        false
    )
end

function client.hitPointFxTick(dt)
    local state = client.hitPointFxState

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
                    if render.eventType == "launch_start" and render.didHit == 1 then
                        local pos = _tableToVec(render.hitPoint)
                        _spawnSphericalShockwave(pos, render.impactLayer, render.didHitShield == 1)
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end
end
