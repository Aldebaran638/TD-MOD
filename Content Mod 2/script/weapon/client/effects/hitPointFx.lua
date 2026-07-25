-- Weapon impact effects.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.hitPointFxState = client.hitPointFxState or {
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
    activeTachyonImpacts = {},
}

client.hitPointFxConfig = client.hitPointFxConfig or {
    maxActiveTachyonImpacts = 8,
    impactDuration = 0.72,
    lightDuration = 0.38,
    lightPeak = 120.0,
    secondaryWaveDelay = 0.10,
    plumeDuration = 0.46,
    plumeInterval = 0.035,
    ringParticleCount = 28,
    backscatterParticleCount = 20,
    residueParticleCount = 10,
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
    local length = VecLength(v)
    if length < 0.0001 then return fallback end
    return VecScale(v, 1.0 / length)
end

local function _resolveSurfaceBasis(normal)
    local reference = Vec(0, 1, 0)
    if math.abs(VecDot(normal, reference)) > 0.92 then
        reference = Vec(1, 0, 0)
    end
    local tangent = _safeNormalize(VecCross(normal, reference), Vec(1, 0, 0))
    local bitangent = _safeNormalize(VecCross(normal, tangent), Vec(0, 0, 1))
    return tangent, bitangent
end

local function _spawnSecondaryWave(impact)
    local origin = impact.pos
    local normal = impact.normal
    local tangent = impact.tangent
    local bitangent = impact.bitangent
    local primary = impact.color or { 0.78, 0.88, 1.0 }
    local secondary = impact.secondaryColor or { 0.35, 0.48, 0.85 }

    -- A delayed flash makes the impact feel like the surface is collapsing twice.
    ParticleReset()
    ParticleColor(1.0, 1.0, 1.0, primary[1], primary[2], primary[3])
    ParticleRadius(9.0, 0.0, "easeout")
    ParticleAlpha(0.90, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.0)
    ParticleEmissive(90.0, 0.0)
    ParticleCollide(0.0)
    SpawnParticle(origin, Vec(0, 0, 0), 0.18)

    -- The second ring is larger, faster and slightly lifted from the surface.
    ParticleReset()
    ParticleColor(primary[1], primary[2], primary[3], secondary[1], secondary[2], secondary[3])
    ParticleRadius(0.78, 0.10, "easeout")
    ParticleAlpha(0.90, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.18)
    ParticleEmissive(50.0, 0.0)
    ParticleCollide(0.0)
    local count = 36
    local phase = math.random() * math.pi * 2.0
    for i = 1, count do
        local angle = phase + (i - 1) * math.pi * 2.0 / count
        local radial = VecAdd(
            VecScale(tangent, math.cos(angle)),
            VecScale(bitangent, math.sin(angle))
        )
        local spawnPos = VecAdd(origin, VecScale(radial, 4.0 + 1.5 * math.random()))
        local velocity = VecAdd(
            VecScale(radial, 48.0 + 20.0 * math.random()),
            VecScale(normal, 2.0 + 3.0 * math.random())
        )
        SpawnParticle(spawnPos, velocity, 0.38 + 0.14 * math.random())
    end
end

local function _spawnImpactPlumeBurst(impact)
    local primary = impact.color or { 0.78, 0.88, 1.0 }
    local secondary = impact.secondaryColor or { 0.35, 0.48, 0.85 }

    ParticleReset()
    ParticleColor(1.0, 1.0, 1.0, secondary[1], secondary[2], secondary[3])
    ParticleRadius(0.52, 0.04, "easeout")
    ParticleAlpha(0.95, 0.0)
    ParticleGravity(-1.0)
    ParticleDrag(0.22)
    ParticleEmissive(55.0, 0.0)
    ParticleCollide(0.0)
    for _ = 1, 4 do
        local spread = VecAdd(
            VecScale(impact.tangent, (math.random() - 0.5) * 0.65),
            VecScale(impact.bitangent, (math.random() - 0.5) * 0.65)
        )
        local direction = _safeNormalize(VecAdd(impact.back, spread), impact.back)
        local startOffset = VecAdd(
            VecScale(impact.tangent, (math.random() - 0.5) * 2.5),
            VecScale(impact.bitangent, (math.random() - 0.5) * 2.5)
        )
        SpawnParticle(
            VecAdd(impact.pos, startOffset),
            VecScale(direction, 38.0 + 32.0 * math.random()),
            0.28 + 0.20 * math.random()
        )
    end

    -- A compact colored pulse keeps the contact point alive between bursts.
    ParticleReset()
    ParticleColor(primary[1], primary[2], primary[3], secondary[1], secondary[2], secondary[3])
    ParticleRadius(2.8, 0.0, "easeout")
    ParticleAlpha(0.55, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.0)
    ParticleEmissive(35.0, 0.0)
    ParticleCollide(0.0)
    SpawnParticle(impact.pos, Vec(0, 0, 0), 0.11)
end

-- Keep the original spherical effect for missiles.
local function _spawnMissileShockwave(pos, impactLayer)
    local r1, g1, b1, r2, g2, b2 = _resolveLayerColors(impactLayer)

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
        local direction = _randomUnitVec()
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
        local direction = _randomUnitVec()
        local spawnPos = VecAdd(pos, VecScale(direction, 0.8 + 0.3 * math.random()))
        local velocity = VecScale(direction, 6.0 + 4.0 * math.random())
        SpawnParticle(spawnPos, velocity, 1.0 + 0.3 * math.random())
    end
end

local function _spawnTachyonImpact(pos, normal, backDirection, impactLayer)
    local config = client.hitPointFxConfig
    local r1, g1, b1, r2, g2, b2 = _resolveLayerColors(impactLayer)
    local back = _safeNormalize(backDirection, Vec(0, 1, 0))
    local surfaceNormal = _safeNormalize(normal, back)
    if VecDot(surfaceNormal, back) < 0.0 then
        surfaceNormal = VecScale(surfaceNormal, -1.0)
    end

    local tangent, bitangent = _resolveSurfaceBasis(surfaceNormal)
    local origin = VecAdd(pos, VecScale(surfaceNormal, 0.25))
    PointLight(origin, r1, g1, b1, tonumber(config.lightPeak) or 60.0)

    -- White-hot contact core.
    ParticleReset()
    ParticleColor(1.0, 1.0, 1.0, r1, g1, b1)
    ParticleRadius(9.5, 0.0, "easeout")
    ParticleAlpha(1.0, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.0)
    ParticleEmissive(70.0, 0.0)
    ParticleCollide(0.0)
    for _ = 1, 3 do
        local jitter = VecAdd(
            VecScale(tangent, (math.random() - 0.5) * 0.80),
            VecScale(bitangent, (math.random() - 0.5) * 0.80)
        )
        SpawnParticle(VecAdd(origin, jitter), Vec(0, 0, 0), 0.16 + 0.06 * math.random())
    end

    -- Thin ring expanding across the impacted surface.
    ParticleReset()
    ParticleColor(r1, g1, b1, r2, g2, b2)
    ParticleRadius(0.55, 0.08, "easeout")
    ParticleAlpha(0.95, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.35)
    ParticleEmissive(38.0, 0.0)
    ParticleCollide(0.0)
    local ringCount = math.max(8, math.floor(config.ringParticleCount or 28))
    local phase = math.random() * math.pi * 2.0
    for i = 1, ringCount do
        local angle = phase + (i - 1) * math.pi * 2.0 / ringCount
        local radial = VecAdd(
            VecScale(tangent, math.cos(angle)),
            VecScale(bitangent, math.sin(angle))
        )
        local spawnPos = VecAdd(origin, VecScale(radial, 1.8 + 1.2 * math.random()))
        local velocity = VecAdd(
            VecScale(radial, 32.0 + 18.0 * math.random()),
            VecScale(surfaceNormal, 1.0 + 2.0 * math.random())
        )
        SpawnParticle(spawnPos, velocity, 0.32 + 0.12 * math.random())
    end

    -- Energy and sparks recoil toward the firing ship.
    ParticleReset()
    ParticleColor(1.0, 1.0, 1.0, r2, g2, b2)
    ParticleRadius(0.32, 0.04, "easeout")
    ParticleAlpha(1.0, 0.0)
    ParticleGravity(-2.0)
    ParticleDrag(0.20)
    ParticleEmissive(45.0, 0.0)
    ParticleCollide(0.0)
    local backscatterCount = math.max(6, math.floor(config.backscatterParticleCount or 20))
    for _ = 1, backscatterCount do
        local spread = VecAdd(
            VecScale(tangent, (math.random() - 0.5) * 0.75),
            VecScale(bitangent, (math.random() - 0.5) * 0.75)
        )
        local direction = _safeNormalize(VecAdd(back, spread), back)
        SpawnParticle(origin, VecScale(direction, 25.0 + 25.0 * math.random()), 0.28 + 0.22 * math.random())
    end

    -- Slow afterglow clinging to the contact surface.
    ParticleReset()
    ParticleColor(r1, g1, b1, r2, g2, b2)
    ParticleRadius(0.48, 0.0, "easeout")
    ParticleAlpha(0.70, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(4.0)
    ParticleEmissive(18.0, 0.0)
    ParticleCollide(0.0)
    local residueCount = math.max(3, math.floor(config.residueParticleCount or 10))
    for _ = 1, residueCount do
        local offset = VecAdd(
            VecScale(tangent, (math.random() - 0.5) * 8.0),
            VecScale(bitangent, (math.random() - 0.5) * 8.0)
        )
        local drift = VecAdd(
            VecScale(offset, 0.7 + math.random()),
            VecScale(surfaceNormal, 0.2 + 0.5 * math.random())
        )
        SpawnParticle(VecAdd(origin, offset), drift, 0.60 + 0.35 * math.random())
    end

    local impacts = client.hitPointFxState.activeTachyonImpacts or {}
    client.hitPointFxState.activeTachyonImpacts = impacts
    impacts[#impacts + 1] = {
        pos = VecAdd(origin, VecScale(surfaceNormal, 0.50)),
        age = 0.0,
        color = { r1, g1, b1 },
        secondaryColor = { r2, g2, b2 },
        normal = surfaceNormal,
        back = back,
        tangent = tangent,
        bitangent = bitangent,
        secondaryWaveSpawned = false,
        plumeAccumulator = 0.0,
    }
    while #impacts > math.max(1, math.floor(config.maxActiveTachyonImpacts or 12)) do
        table.remove(impacts, 1)
    end
end

function client.playMissileImpactFx(hitX, hitY, hitZ, impactLayer)
    _spawnMissileShockwave(
        Vec(hitX or 0, hitY or 0, hitZ or 0),
        tostring(impactLayer or "body")
    )
end

function client.hitPointFxTick(dt)
    local state = client.hitPointFxState
    local config = client.hitPointFxConfig
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)

    local impacts = state.activeTachyonImpacts or {}
    state.activeTachyonImpacts = impacts
    local impactDuration = math.max(0.01, tonumber(config.impactDuration) or 0.72)
    local lightDuration = math.max(0.01, tonumber(config.lightDuration) or 0.38)
    local secondaryWaveDelay = math.max(0.0, tonumber(config.secondaryWaveDelay) or 0.10)
    local plumeDuration = math.max(0.0, tonumber(config.plumeDuration) or 0.46)
    local plumeInterval = math.max(0.01, tonumber(config.plumeInterval) or 0.035)
    for i = #impacts, 1, -1 do
        local impact = impacts[i]
        impact.age = (impact.age or 0.0) + frameDt
        if impact.age >= impactDuration then
            table.remove(impacts, i)
        else
            if impact.age < lightDuration then
                local t = impact.age / lightDuration
                local intensity = (tonumber(config.lightPeak) or 120.0) * (1.0 - t) * (1.0 - t)
                local color = impact.color or { 0.3, 0.9, 1.0 }
                PointLight(impact.pos, color[1], color[2], color[3], intensity)
            end

            if (not impact.secondaryWaveSpawned) and impact.age >= secondaryWaveDelay then
                impact.secondaryWaveSpawned = true
                _spawnSecondaryWave(impact)
            end

            if impact.age < plumeDuration then
                impact.plumeAccumulator = (impact.plumeAccumulator or 0.0) + frameDt
                while impact.plumeAccumulator >= plumeInterval do
                    impact.plumeAccumulator = impact.plumeAccumulator - plumeInterval
                    _spawnImpactPlumeBurst(impact)
                end
            end

        end
    end

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
                        local firePoint = _tableToVec(render.firePoint)
                        _spawnTachyonImpact(
                            pos,
                            _tableToVec(render.normal),
                            _safeNormalize(VecSub(firePoint, pos), Vec(0, 1, 0)),
                            render.impactLayer
                        )
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end
end
