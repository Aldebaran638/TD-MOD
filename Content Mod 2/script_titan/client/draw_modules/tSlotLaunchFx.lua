-- t-slot launch fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.tSlotLaunchFxConfig = client.tSlotLaunchFxConfig or {
    particlesPerUnit = 12,
    particleColorA = { 0.5, 0.4, 0.3 },
    particleColorB = { 0.5, 0.4, 0.3 },
    particleRadiusStart = 0.05,
    particleRadiusEnd = 0.1,
    particleEmissive = 26.0,
    particleLifeMin = 0.7,
    particleLifeMax = 1.0,
    particleForwardSpeed = 2.0,
    jitterRadius = 0.01,
    lineCount = 1,
    lineSpacing = 0.08,
    
    forwardParticlesPerUnit = 5,
    forwardParticleRounds = 1,
    forwardParticleRadius = 0.07,
    forwardParticleLife = 2,
    forwardParticleSpeed = 40.0,
    forwardParticleEmissive = 30.0,
    forwardParticleColorA = { 0.5, 0.4, 0.3 },
    forwardParticleColorB = { 0.5, 0.4, 0.3  },
    cylinderRadius = 0.5,
    
    shockwaveLife = 1.15,
    shockwaveR0 = 1.0,
    shockwaveR1 = 9.25,
    shockwaveParticleCount = 48,
    shockwaveLightIntensity = 3.5,
    shockwaveParticleSpeedBase = 15.0,
    shockwaveParticleSpeedDecay = 8.75,
    shockwaveParticleSpeedRandom = 6.25,
}

client.tSlotLaunchFxState = client.tSlotLaunchFxState or {
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
    shockwaves = {},
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

local function _startShockwave(center)
    local state = client.tSlotLaunchFxState
    local cfg = client.tSlotLaunchFxConfig
    
    state.shockwaves[#state.shockwaves + 1] = {
        center = center,
        age = 0.0,
        life = cfg.shockwaveLife or 1.15,
        r0 = cfg.shockwaveR0 or 1.0,
        r1 = cfg.shockwaveR1 or 9.25,
    }
end

local function _tickShockwaves(dt)
    local list = client.tSlotLaunchFxState.shockwaves
    local cfg = client.tSlotLaunchFxConfig
    local i = #list
    
    while i >= 1 do
        local fx = list[i]
        fx.age = fx.age + dt
        if fx.age >= fx.life then
            table.remove(list, i)
        else
            local t = fx.age / fx.life
            local r = fx.r0 + (fx.r1 - fx.r0) * t
            local alpha = math.pow(1.0 - t, 0.62)
            
            local lightIntensity = cfg.shockwaveLightIntensity or 3.5
            PointLight(fx.center, 1.0, 1.0, 1.0, lightIntensity * alpha)
            
            ParticleReset()
            ParticleColor(1.0, 1.0, 1.0, 0.86, 0.90, 1.0)
            ParticleRadius(0.36, 0.12, "easeout")
            ParticleAlpha(0.9 * alpha, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.08)
            ParticleEmissive(30.0 * alpha, 0.0)
            ParticleCollide(0.0)
            
            local count = cfg.shockwaveParticleCount or 48
            local speedBase = cfg.shockwaveParticleSpeedBase or 6.0
            local speedDecay = cfg.shockwaveParticleSpeedDecay or 3.5
            local speedRandom = cfg.shockwaveParticleSpeedRandom or 2.5
            
            for k = 1, count do
                local a = (k / count) * math.pi * 2.0 + math.random() * 0.08
                local cs = math.cos(a)
                local sn = math.sin(a)
                local pos = Vec(
                    fx.center[1] + cs * r,
                    fx.center[2] + (math.random() - 0.5) * 0.18,
                    fx.center[3] + sn * r
                )
                local dir = Vec(cs, 0, sn)
                local vel = VecScale(dir, speedBase + speedDecay * (1.0 - t) + speedRandom * math.random())
                SpawnParticle(pos, vel, 0.125 + 0.0875 * math.random())
            end
        end
        i = i - 1
    end
end

local function _spawnBeamLine(fire, hit, cfg)
    local beamVec = VecSub(hit, fire)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then
        return
    end

    local beamDir = VecScale(beamVec, 1.0 / beamLen)
    local right, up = _buildPerpBasis(beamDir)
    local density = cfg.particlesPerUnit or 12
    local count = math.max(10, math.floor(beamLen * density))
    local jitter = cfg.jitterRadius or 0.01
    local lineCount = cfg.lineCount or 4
    local lineSpacing = cfg.lineSpacing or 0.08

    local ca = cfg.particleColorA or { 0.5, 0.4, 0.3 }
    local cb = cfg.particleColorB or { 0.5, 0.4, 0.3 }

    local lineOffsets = {
        VecScale(right, -lineSpacing * 0.5),
        VecScale(right, lineSpacing * 0.5),
        VecScale(up, -lineSpacing * 0.5),
        VecScale(up, lineSpacing * 0.5),
    }

    ParticleReset()
    ParticleColor(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
    ParticleRadius(cfg.particleRadiusStart or 0.08, cfg.particleRadiusEnd or 0.015, "easeout")
    ParticleAlpha(0.95, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.06)
    ParticleEmissive(cfg.particleEmissive or 26.0, 0.0)
    ParticleCollide(0.0)

    for lineIdx = 1, math.min(lineCount, #lineOffsets) do
        local lineOffset = lineOffsets[lineIdx]
        
        for i = 0, count - 1 do
            local t = i / math.max(1, count - 1)
            local basePos = VecAdd(fire, VecScale(beamVec, t))
            basePos = VecAdd(basePos, lineOffset)
            local a = math.random() * math.pi * 2.0
            local rr = jitter * math.random()
            local off = VecAdd(VecScale(right, math.cos(a) * rr), VecScale(up, math.sin(a) * rr))
            local pos = VecAdd(basePos, off)
            local vel = VecScale(beamDir, cfg.particleForwardSpeed or 2.0)
            local life = (cfg.particleLifeMin or 0.20) + ((cfg.particleLifeMax or 0.40) - (cfg.particleLifeMin or 0.20)) * math.random()
            SpawnParticle(pos, vel, life)
        end
    end
    
    local fwdDensity = cfg.forwardParticlesPerUnit or 8
    local fwdRounds = cfg.forwardParticleRounds or 3
    local fwdRadius = cfg.forwardParticleRadius or 0.06
    local fwdLife = cfg.forwardParticleLife or 0.15
    local fwdSpeed = cfg.forwardParticleSpeed or 15.0
    local fwdEmissive = cfg.forwardParticleEmissive or 30.0
    local fwdColorA = cfg.forwardParticleColorA or { 1.00, 0.95, 0.85 }
    local fwdColorB = cfg.forwardParticleColorB or { 1.00, 0.80, 0.50 }
    local cylinderR = cfg.cylinderRadius or 0.12
    
    local fwdCount = math.max(5, math.floor(beamLen * fwdDensity))
    
    ParticleReset()
    ParticleColor(fwdColorA[1], fwdColorA[2], fwdColorA[3], fwdColorB[1], fwdColorB[2], fwdColorB[3])
    ParticleRadius(fwdRadius, fwdRadius * 0.3, "easeout")
    ParticleAlpha(0.9, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.0)
    ParticleEmissive(fwdEmissive, 0.0)
    ParticleCollide(0.0)
    
    for roundIdx = 1, fwdRounds do
        for i = 0, fwdCount - 1 do
            local t = i / math.max(1, fwdCount - 1)
            local basePos = VecAdd(fire, VecScale(beamVec, t))
            
            local angle = math.random() * math.pi * 2.0
            local r = cylinderR * (0.7 + 0.3 * math.random())
            local off = VecAdd(VecScale(right, math.cos(angle) * r), VecScale(up, math.sin(angle) * r))
            local pos = VecAdd(basePos, off)
            
            local vel = VecScale(beamDir, fwdSpeed)
            local life = fwdLife * (0.8 + 0.4 * math.random())
            SpawnParticle(pos, vel, life)
        end
    end
    
    PointLight(fire,  0.5, 0.4, 0.3 , 3.0)
    PointLight(hit,  0.5, 0.4, 0.3 , 2.5)
    
    _startShockwave(hit)
end

function client.tSlotLaunchFxTick(dt)
    local state = client.tSlotLaunchFxState
    local cfg = client.tSlotLaunchFxConfig
    local frameDt = dt or 0.016

    local shipIds = client.registryShipGetRegisteredBodyIds()
    for i = 1, #shipIds do
        local shipBodyId = shipIds[i]
        if client.registryShipExists(shipBodyId) then
            local render = client.tSlotRenderGetEvent(shipBodyId)
            if render ~= nil then
                local seq = render.seq or -1
                local shotId = render.shotId or -1
                local lastSeq = state.lastRenderSeqByShip[shipBodyId] or -1

                if seq ~= lastSeq then
                    if render.eventType == "launch_start" then
                        _spawnBeamLine(_tableToVec(render.firePoint), _tableToVec(render.hitPoint), cfg)
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end
    
    _tickShockwaves(frameDt)
end
