---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.escortSSlotLaunchFxConfig = client.escortSSlotLaunchFxConfig or {
    helixRadius = 0.12,
    helixPitch = 18.0,
    helixParticlesPerTurn = 96,
    helixParticleColorA = { 0.80, 0.40, 0.00 },
    helixParticleColorB = { 0.60, 0.20, 0.00 },
    helixParticleRadiusStart = 0.05,
    helixParticleRadiusEnd = 0.015,
    helixParticleEmissive = 20.0,
    helixParticleLifeMin = 0.16,
    helixParticleLifeMax = 0.28,
    helixParticleTangentialSpeed = 1.4,
    helixParticleForwardSpeed = 1.2,
    coreLineParticlesPerTurn = 128,
    coreLineParticleColorA = { 0.90, 0.50, 0.00 },
    coreLineParticleColorB = { 0.70, 0.30, 0.00 },
    coreLineParticleRadiusStart = 0.05,
    coreLineParticleRadiusEnd = 0.012,
    coreLineParticleEmissive = 22.0,
    coreLineParticleLifeMin = 0.14,
    coreLineParticleLifeMax = 0.24,
    coreLineParticleForwardSpeed = 1.8,
    coreLineJitterRadius = 0.008,
}

client.escortSSlotLaunchFxState = client.escortSSlotLaunchFxState or {
    lastRenderSeqByShip = {},
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

local function _spawnCoreLineParticlesOnce(fire, hit, cfg)
    local beamVec = VecSub(hit, fire)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then
        return
    end

    local beamDir = VecScale(beamVec, 1.0 / beamLen)
    local right, up = _buildPerpBasis(beamDir)
    local pitch = math.max(0.1, cfg.helixPitch or 18.0)
    local turns = beamLen / pitch
    local densityPerTurn = cfg.coreLineParticlesPerTurn or 96
    local count = math.max(8, math.floor(turns * densityPerTurn))
    local jitter = cfg.coreLineJitterRadius or 0.01
    local ca = cfg.coreLineParticleColorA
    local cb = cfg.coreLineParticleColorB

    ParticleReset()
    ParticleColor(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
    ParticleRadius(cfg.coreLineParticleRadiusStart, cfg.coreLineParticleRadiusEnd, "easeout")
    ParticleAlpha(0.92, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.06)
    ParticleEmissive(cfg.coreLineParticleEmissive, 0.0)
    ParticleCollide(0.0)

    for i = 0, count - 1 do
        local t = i / math.max(1, count - 1)
        local basePos = VecAdd(fire, VecScale(beamVec, t))
        local a = math.random() * math.pi * 2.0
        local rr = jitter * math.random()
        local off = VecAdd(VecScale(right, math.cos(a) * rr), VecScale(up, math.sin(a) * rr))
        local pos = VecAdd(basePos, off)
        local vel = VecScale(beamDir, cfg.coreLineParticleForwardSpeed)
        local life = cfg.coreLineParticleLifeMin + (cfg.coreLineParticleLifeMax - cfg.coreLineParticleLifeMin) * math.random()
        SpawnParticle(pos, vel, life)
    end
end

local function _spawnHelixParticlesOnce(fire, hit, seed, cfg)
    local beamVec = VecSub(hit, fire)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then
        return
    end

    local beamDir = VecScale(beamVec, 1.0 / beamLen)
    local right, up = _buildPerpBasis(beamDir)
    local radius = cfg.helixRadius
    local pitch = math.max(0.1, cfg.helixPitch)
    local turns = beamLen / pitch
    local count = math.max(8, math.floor(turns * cfg.helixParticlesPerTurn))
    local ca = cfg.helixParticleColorA
    local cb = cfg.helixParticleColorB

    ParticleReset()
    ParticleColor(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
    ParticleRadius(cfg.helixParticleRadiusStart, cfg.helixParticleRadiusEnd, "easeout")
    ParticleAlpha(0.88, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.08)
    ParticleEmissive(cfg.helixParticleEmissive, 0.0)
    ParticleCollide(0.0)

    for i = 0, count - 1 do
        local t = i / math.max(1, count - 1)
        local ang = t * turns * math.pi * 2.0 + seed
        local center = VecAdd(fire, VecScale(beamVec, t))
        local off = VecAdd(VecScale(right, math.cos(ang) * radius), VecScale(up, math.sin(ang) * radius))
        local pos = VecAdd(center, off)
        local tangent = VecAdd(VecScale(right, -math.sin(ang)), VecScale(up, math.cos(ang)))
        tangent = _safeNormalize(tangent, right)
        local vel = VecAdd(VecScale(tangent, cfg.helixParticleTangentialSpeed), VecScale(beamDir, cfg.helixParticleForwardSpeed))
        local life = cfg.helixParticleLifeMin + (cfg.helixParticleLifeMax - cfg.helixParticleLifeMin) * math.random()
        SpawnParticle(pos, vel, life)
    end
end

function client.escortSSlotLaunchFxTick(dt)
    local _ = dt
    local state = client.escortSSlotLaunchFxState
    local cfg = client.escortSSlotLaunchFxConfig

    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local render = client.escortSSlotRenderGetEvent(shipBodyId)
            if render ~= nil then
                local seq = render.seq or -1
                local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1
                if seq ~= lastSeq and render.eventType == "launch_start" then
                    local fire = _tableToVec(render.firePoint)
                    local hit = _tableToVec(render.hitPoint)
                    _spawnCoreLineParticlesOnce(fire, hit, cfg)
                    _spawnHelixParticlesOnce(fire, hit, math.random() * 1000.0, cfg)
                end
                state.lastRenderSeqByShip[shipBodyId] = seq
            end
        end
    end
end
