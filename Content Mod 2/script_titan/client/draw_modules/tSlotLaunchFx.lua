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
    activeBeams = {},
    expandingExplosions = {},
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

local function _startShockwave(center, weaponSettings)
    local state = client.tSlotLaunchFxState
    local cfg = client.tSlotLaunchFxConfig
    
    local particleCount = tonumber(weaponSettings.shockwaveParticleCount) or cfg.shockwaveParticleCount or 48
    local lightIntensity = tonumber(weaponSettings.shockwaveLightIntensity) or cfg.shockwaveLightIntensity or 3.5
    local speedBase = tonumber(weaponSettings.shockwaveParticleSpeedBase) or cfg.shockwaveParticleSpeedBase or 15.0
    local speedDecay = tonumber(weaponSettings.shockwaveParticleSpeedDecay) or cfg.shockwaveParticleSpeedDecay or 8.75
    local speedRandom = tonumber(weaponSettings.shockwaveParticleSpeedRandom) or cfg.shockwaveParticleSpeedRandom or 6.25
    
    state.shockwaves[#state.shockwaves + 1] = {
        center = center,
        age = 0.0,
        life = cfg.shockwaveLife or 1.15,
        r0 = cfg.shockwaveR0 or 1.0,
        r1 = cfg.shockwaveR1 or 9.25,
        particleCount = particleCount,
        lightIntensity = lightIntensity,
        speedBase = speedBase,
        speedDecay = speedDecay,
        speedRandom = speedRandom,
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
            
            local lightIntensity = fx.lightIntensity or cfg.shockwaveLightIntensity or 3.5
            PointLight(fx.center, 1.0, 1.0, 1.0, lightIntensity * alpha)
            
            ParticleReset()
            ParticleColor(1.0, 1.0, 1.0, 0.86, 0.90, 1.0)
            ParticleRadius(0.36, 0.12, "easeout")
            ParticleAlpha(0.9 * alpha, 0.0)
            ParticleGravity(0.0)
            ParticleDrag(0.08)
            ParticleEmissive(30.0 * alpha, 0.0)
            ParticleCollide(0.0)
            
            local count = fx.particleCount or cfg.shockwaveParticleCount or 48
            local speedBase = fx.speedBase or cfg.shockwaveParticleSpeedBase or 6.0
            local speedDecay = fx.speedDecay or cfg.shockwaveParticleSpeedDecay or 3.5
            local speedRandom = fx.speedRandom or cfg.shockwaveParticleSpeedRandom or 2.5
            
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

local function _computeBeamOffsets(beamCount, spacing, right, up)
    local offsets = {}
    offsets[1] = Vec(0, 0, 0)
    
    for i = 0, 5 do
        local angle = i * math.pi / 3.0
        local offsetX = math.cos(angle) * spacing
        local offsetY = math.sin(angle) * spacing
        offsets[i + 2] = VecAdd(VecScale(right, offsetX), VecScale(up, offsetY))
    end
    
    return offsets
end

local function _spawnBeamWave(fire, hit, cfg, weaponSettings, beamOffset, right, up)
    local beamVec = VecSub(hit, fire)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then
        return
    end

    local beamDir = VecScale(beamVec, 1.0 / beamLen)
    
    local density = weaponSettings.beamParticlesPerUnit or cfg.particlesPerUnit or 12
    local count = math.max(10, math.floor(beamLen * density))
    local jitter = cfg.jitterRadius or 0.01

    local ca = weaponSettings.beamColorA or cfg.particleColorA or { 0.5, 0.4, 0.3 }
    local cb = weaponSettings.beamColorB or cfg.particleColorB or { 0.5, 0.4, 0.3 }

    local particleLife = weaponSettings.beamParticleLife or 0.5
    local particleRadiusMin = weaponSettings.beamParticleRadiusMin or 0.05
    local particleRadiusMax = weaponSettings.beamParticleRadiusMax or 0.15

    ParticleReset()
    ParticleColor(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3])
    ParticleRadius(particleRadiusMin, particleRadiusMax, "linear")
    ParticleAlpha(0.95, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.06)
    ParticleEmissive(cfg.particleEmissive or 26.0, 0.0)
    ParticleCollide(0.0)

    for i = 0, count - 1 do
        local t = i / math.max(1, count - 1)
        local basePos = VecAdd(fire, VecScale(beamVec, t))
        basePos = VecAdd(basePos, beamOffset)
        local a = math.random() * math.pi * 2.0
        local rr = jitter * math.random()
        local off = VecAdd(VecScale(right, math.cos(a) * rr), VecScale(up, math.sin(a) * rr))
        local pos = VecAdd(basePos, off)
        local vel = VecScale(beamDir, cfg.particleForwardSpeed or 2.0)
        local life = particleLife * (0.8 + 0.4 * math.random())
        SpawnParticle(pos, vel, life)
    end
    
    local fwdDensity = weaponSettings.beamForwardParticlesPerUnit or cfg.forwardParticlesPerUnit or 5
    local fwdRadius = weaponSettings.beamForwardParticleRadius or cfg.forwardParticleRadius or 0.07
    local fwdSpeed = weaponSettings.beamForwardParticleSpeed or cfg.forwardParticleSpeed or 40.0
    local fwdEmissive = weaponSettings.beamForwardParticleEmissive or cfg.forwardParticleEmissive or 30.0
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
    
    for i = 0, fwdCount - 1 do
        local t = i / math.max(1, fwdCount - 1)
        local basePos = VecAdd(fire, VecScale(beamVec, t))
        basePos = VecAdd(basePos, beamOffset)
        
        local angle = math.random() * math.pi * 2.0
        local r = cylinderR * (0.7 + 0.3 * math.random())
        local off = VecAdd(VecScale(right, math.cos(angle) * r), VecScale(up, math.sin(angle) * r))
        local pos = VecAdd(basePos, off)
        
        local vel = VecScale(beamDir, fwdSpeed)
        local life = 0.15 * (0.8 + 0.4 * math.random())
        SpawnParticle(pos, vel, life)
    end
    
    PointLight(fire,  0.5, 0.4, 0.3 , 3.0)
    PointLight(hit,  0.5, 0.4, 0.3 , 2.5)
end

local function _spawnExplosionParticles(pos, radius, intensity)
    local particleCount = math.floor(50 * intensity)
    
    ParticleReset()
    ParticleColor(1.0, 0.9, 0.7, 1.0, 0.5, 0.2)
    ParticleRadius(0.5, 1.5, "easeout")
    ParticleAlpha(1.0, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.1)
    ParticleEmissive(50.0, 0.0)
    ParticleCollide(0.0)
    
    for i = 1, particleCount do
        local angle = math.random() * math.pi * 2.0
        local r = radius * (0.5 + 0.5 * math.random())
        local offsetX = math.cos(angle) * r
        local offsetZ = math.sin(angle) * r
        local offsetY = (math.random() - 0.5) * radius * 0.5
        
        local particlePos = Vec(pos[1] + offsetX, pos[2] + offsetY, pos[3] + offsetZ)
        local vel = VecScale(Vec(math.cos(angle), 0.5, math.sin(angle)), 20.0 + 30.0 * math.random())
        local life = 0.5 + 0.5 * math.random()
        SpawnParticle(particlePos, vel, life)
    end
    
    PointLight(pos, 1.0, 0.8, 0.5, 10.0 * intensity)
end

local function _tickExpandingExplosions(dt)
    local explosions = client.tSlotLaunchFxState.expandingExplosions or {}
    local i = #explosions
    
    while i >= 1 do
        local explosion = explosions[i]
        explosion.age = explosion.age + dt
        
        local expectedWave = math.floor(explosion.age / explosion.waveInterval) + 1
        if expectedWave > explosion.waveCount then
            expectedWave = explosion.waveCount
        end
        
        while explosion.currentWave < expectedWave do
            explosion.currentWave = explosion.currentWave + 1
            
            local waveIndex = explosion.currentWave
            local waveRadius = explosion.waveRadiusIncrement * waveIndex
            local explosionCount = explosion.firstWaveCount + (explosion.waveCountIncrement * (waveIndex - 1))
            
            for layer = 0, explosion.heightLayers - 1 do
                local layerHeight = explosion.center[2] + (layer * explosion.heightSpacing)
                
                for j = 1, explosionCount do
                    local angle = (j / explosionCount) * math.pi * 2.0
                    local offsetX = math.cos(angle) * waveRadius
                    local offsetZ = math.sin(angle) * waveRadius
                    
                    local explosionPos = Vec(
                        explosion.center[1] + offsetX,
                        layerHeight,
                        explosion.center[3] + offsetZ
                    )
                    
                    _spawnExplosionParticles(explosionPos, explosion.explosionRadius, explosion.explosionStrength)
                end
            end
        end
        
        if explosion.currentWave >= explosion.waveCount then
            table.remove(explosions, i)
        end
        
        i = i - 1
    end
end

local function _startExpandingExplosion(center, weaponSettings)
    local state = client.tSlotLaunchFxState
    
    local explosion = {
        center = center,
        age = 0.0,
        currentWave = 0,
        waveCount = tonumber(weaponSettings.explosionWaves) or 10,
        waveInterval = tonumber(weaponSettings.explosionWaveInterval) or 0.1,
        explosionRadius = tonumber(weaponSettings.explosionRadius) or 4.0,
        explosionStrength = tonumber(weaponSettings.explosionStrength) or 1.0,
        firstWaveCount = tonumber(weaponSettings.explosionFirstWaveCount) or 6,
        waveRadiusIncrement = tonumber(weaponSettings.explosionWaveRadiusIncrement) or 2.0,
        waveCountIncrement = tonumber(weaponSettings.explosionWaveCountIncrement) or 3,
        heightLayers = tonumber(weaponSettings.explosionHeightLayers) or 5,
        heightSpacing = tonumber(weaponSettings.explosionHeightSpacing) or 20.0,
    }
    
    table.insert(state.expandingExplosions, explosion)
end

local function _tickActiveBeams(dt)
    local state = client.tSlotLaunchFxState
    local cfg = client.tSlotLaunchFxConfig
    local activeBeams = state.activeBeams or {}
    local i = #activeBeams
    
    while i >= 1 do
        local beam = activeBeams[i]
        beam.age = beam.age + dt
        
        local weaponSettings = beam.weaponSettings or {}
        local duration = weaponSettings.beamDuration or 1.5
        local waveCount = weaponSettings.beamWaveCount or 5
        local waveInterval = weaponSettings.beamWaveInterval or 0.25
        
        if beam.age >= duration then
            table.remove(activeBeams, i)
        else
            local expectedWave = math.floor(beam.age / waveInterval) + 1
            if expectedWave > waveCount then
                expectedWave = waveCount
            end
            
            while beam.currentWave < expectedWave do
                beam.currentWave = beam.currentWave + 1
                
                local beamVec = VecSub(beam.hit, beam.fire)
                local beamDir = _safeNormalize(beamVec, Vec(0, 0, -1))
                local right, up = _buildPerpBasis(beamDir)
                
                local beamCount = weaponSettings.beamCount or 7
                local spacing = weaponSettings.beamSpacing or 0.3
                local offsets = _computeBeamOffsets(beamCount, spacing, right, up)
                
                for beamIdx = 1, beamCount do
                    local beamOffset = offsets[beamIdx] or Vec(0, 0, 0)
                    local fireOffset = VecAdd(beam.fire, beamOffset)
                    local hitOffset = VecAdd(beam.hit, beamOffset)
                    
                    _spawnBeamWave(fireOffset, hitOffset, cfg, weaponSettings, beamOffset, right, up)
                    
                    if beam.currentWave == 1 then
                        _startShockwave(hitOffset, weaponSettings)
                    end
                end
            end
        end
        
        i = i - 1
    end
end

local function _startBeamEffect(fire, hit, weaponSettings)
    local state = client.tSlotLaunchFxState
    
    state.activeBeams[#state.activeBeams + 1] = {
        fire = fire,
        hit = hit,
        weaponSettings = weaponSettings,
        age = 0.0,
        currentWave = 0,
    }
    
    _startExpandingExplosion(hit, weaponSettings)
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
                        local weaponType = render.weaponType or "tachyonLance"
                        local weaponSettings = (weaponData and weaponData[weaponType]) or {}
                        
                        if weaponType == "perditionBeam" then
                            _startBeamEffect(_tableToVec(render.firePoint), _tableToVec(render.hitPoint), weaponSettings)
                        else
                            local beamVec = VecSub(_tableToVec(render.hitPoint), _tableToVec(render.firePoint))
                            local beamDir = _safeNormalize(beamVec, Vec(0, 0, -1))
                            local right, up = _buildPerpBasis(beamDir)
                            _spawnBeamWave(_tableToVec(render.firePoint), _tableToVec(render.hitPoint), cfg, weaponSettings, Vec(0, 0, 0), right, up)
                            _startShockwave(_tableToVec(render.hitPoint), weaponSettings)
                        end
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end
    
    _tickActiveBeams(frameDt)
    _tickExpandingExplosions(frameDt)
    _tickShockwaves(frameDt)
end
