-- x-slot launch fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotLaunchFxConfig = client.xSlotLaunchFxConfig or {
    -- 青色螺旋光粒
    helixRadius = 0.22,
    helixPitch = 26.0,
    helixParticlesPerTurn = 96,
    helixParticleColorA = { 0.00, 1.00, 1.00 },
    helixParticleColorB = { 0.00, 0.84, 0.96 },
    helixParticleRadiusStart = 0.09,
    helixParticleRadiusEnd = 0.02,
    helixParticleEmissive = 24.0,
    helixParticleLifeMin = 0.22,
    helixParticleLifeMax = 0.42,
    helixParticleTangentialSpeed = 2.5,
    helixParticleForwardSpeed = 1.6,

    -- 白色中心直线光粒
    coreLineParticlesPerTurn = 96,
    coreLineParticleColorA = { 1.00, 1.00, 1.00 },
    coreLineParticleColorB = { 0.94, 0.98, 1.00 },
    coreLineParticleRadiusStart = 0.08,
    coreLineParticleRadiusEnd = 0.0150,
    coreLineParticleEmissive = 26.0,
    coreLineParticleLifeMin = 0.20,
    coreLineParticleLifeMax = 0.40,
    coreLineParticleForwardSpeed = 2.0,
    coreLineJitterRadius = 0.01,
}

client.xSlotLaunchFxState = client.xSlotLaunchFxState or {
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _safeNormalize(v, fallback)
    local l = VecLength(v)
    if l < 0.0001 then
        return fallback or Vec(0, 0, -1)
    end
    return VecScale(v, 1.0 / l)
end

local function _buildPerpBasis(forward)
    local upWorld = Vec(0, 1, 0)
    local right = VecCross(upWorld, forward)
    right = _safeNormalize(right, Vec(1, 0, 0))
    local up = VecCross(forward, right)
    up = _safeNormalize(up, Vec(0, 1, 0))
    return right, up
end

-- 一次性生成中心白色粒子线（后续靠粒子寿命自然消失）
local function _spawnCoreLineParticlesOnce(fire, hit, cfg)
    local beamVec = VecSub(hit, fire)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then
        return
    end

    local beamDir = VecScale(beamVec, 1.0 / beamLen)
    local right, up = _buildPerpBasis(beamDir)
    local pitch = math.max(0.1, cfg.helixPitch or 26.0)
    local turns = beamLen / pitch
    local densityPerTurn = cfg.coreLineParticlesPerTurn or cfg.helixParticlesPerTurn or 96
    local count = math.max(10, math.floor(turns * densityPerTurn))
    local jitter = cfg.coreLineJitterRadius or 0.01

    local ca = cfg.coreLineParticleColorA or { 1.00, 1.00, 1.00 }
    local cb = cfg.coreLineParticleColorB or { 0.94, 0.98, 1.00 }

    ParticleReset()
    ParticleColor(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
    ParticleRadius(cfg.coreLineParticleRadiusStart or 0.04, cfg.coreLineParticleRadiusEnd or 0.0075, "easeout")
    ParticleAlpha(0.95, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.06)
    ParticleEmissive(cfg.coreLineParticleEmissive or 26.0, 0.0)
    ParticleCollide(0.0)

    for i = 0, count - 1 do
        local t = i / math.max(1, count - 1)
        local basePos = VecAdd(fire, VecScale(beamVec, t))
        local a = math.random() * math.pi * 2.0
        local rr = jitter * math.random()
        local off = VecAdd(VecScale(right, math.cos(a) * rr), VecScale(up, math.sin(a) * rr))
        local pos = VecAdd(basePos, off)
        local vel = VecScale(beamDir, cfg.coreLineParticleForwardSpeed or 2.0)
        local life = (cfg.coreLineParticleLifeMin or 0.20) + ((cfg.coreLineParticleLifeMax or 0.40) - (cfg.coreLineParticleLifeMin or 0.20)) * math.random()
        SpawnParticle(pos, vel, life)
    end
end

-- 一次性生成青色螺旋粒子（后续靠粒子寿命自然消失）
local function _spawnHelixParticlesOnce(fire, hit, seed, cfg)
    local beamVec = VecSub(hit, fire)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then
        return
    end

    local beamDir = VecScale(beamVec, 1.0 / beamLen)
    local right, up = _buildPerpBasis(beamDir)
    local radius = cfg.helixRadius or 0.22
    local pitch = math.max(0.1, cfg.helixPitch or 26.0)
    local turns = beamLen / pitch
    local count = math.max(10, math.floor(turns * (cfg.helixParticlesPerTurn or 96)))

    local ca = cfg.helixParticleColorA or { 0.00, 1.00, 1.00 }
    local cb = cfg.helixParticleColorB or { 0.00, 0.84, 0.96 }

    ParticleReset()
    ParticleColor(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
    ParticleRadius(cfg.helixParticleRadiusStart or 0.045, cfg.helixParticleRadiusEnd or 0.01, "easeout")
    ParticleAlpha(0.92, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.08)
    ParticleEmissive(cfg.helixParticleEmissive or 24.0, 0.0)
    ParticleCollide(0.0)

    for i = 0, count - 1 do
        local t = i / math.max(1, count - 1)
        local ang = t * turns * math.pi * 2.0 + seed
        local center = VecAdd(fire, VecScale(beamVec, t))
        local off = VecAdd(VecScale(right, math.cos(ang) * radius), VecScale(up, math.sin(ang) * radius))
        local pos = VecAdd(center, off)

        local tangent = VecAdd(VecScale(right, -math.sin(ang)), VecScale(up, math.cos(ang)))
        tangent = _safeNormalize(tangent, right)
        local vel = VecAdd(
            VecScale(tangent, cfg.helixParticleTangentialSpeed or 2.5),
            VecScale(beamDir, cfg.helixParticleForwardSpeed or 1.6)
        )

        local life = (cfg.helixParticleLifeMin or 0.22) + ((cfg.helixParticleLifeMax or 0.42) - (cfg.helixParticleLifeMin or 0.22)) * math.random()
        SpawnParticle(pos, vel, life)
    end
end

local function _xSlotLaunchFxStart(firePointWorld, hitPointWorld, cfg)
    local beamVec = VecSub(hitPointWorld, firePointWorld)
    if VecLength(beamVec) < 0.001 then
        return
    end

    local seed = math.random() * 1000.0
    _spawnCoreLineParticlesOnce(firePointWorld, hitPointWorld, cfg)
    _spawnHelixParticlesOnce(firePointWorld, hitPointWorld, seed, cfg)
end

function client.xSlotLaunchFxTick(dt)
    local _ = dt
    local state = client.xSlotLaunchFxState
    local cfg = client.xSlotLaunchFxConfig

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
                        _xSlotLaunchFxStart(_tableToVec(render.firePoint), _tableToVec(render.hitPoint), cfg)
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end
end
