-- x-slot launch fx module
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.xSlotLaunchFxConfig = client.xSlotLaunchFxConfig or {
    helixRadius = 0.22,
    helixPitch = 26.0,
    helixParticlesPerTurn = 192,
    helixParticleColorA = { 0.00, 1.00, 1.00 },
    helixParticleColorB = { 0.00, 0.84, 0.96 },
    helixParticleRadiusStart = 0.09,
    helixParticleRadiusEnd = 0.02,
    helixParticleEmissive = 24.0,
    helixParticleLifeMin = 0.22,
    helixParticleLifeMax = 0.42,
    helixParticleTangentialSpeed = 2.5,
    helixParticleForwardSpeed = 1.6,

    coreLineParticlesPerTurn = 192,
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
    activeBeamsByShip = {},
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
}

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
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

local function _resolveWeaponSettings(weaponType)
    local defs = weaponData or {}
    return defs[weaponType or ""] or defs.infernalRay or defs.tachyonLance or {}
end

local function _smoothstep01(t)
    local x = _clamp(t or 0.0, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)
end

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

local function _spawnLegacyLaunchFx(firePointWorld, hitPointWorld, cfg)
    local beamVec = VecSub(hitPointWorld, firePointWorld)
    if VecLength(beamVec) < 0.001 then
        return
    end

    local seed = math.random() * 1000.0
    _spawnCoreLineParticlesOnce(firePointWorld, hitPointWorld, cfg)
    _spawnHelixParticlesOnce(firePointWorld, hitPointWorld, seed, cfg)
end

local function _beginInfernalBeam(shipBodyId, render)
    local weaponSettings = _resolveWeaponSettings(render.weaponType)
    local launchDuration = tonumber(weaponSettings.launchFxVisualDuration) or ((tonumber(weaponSettings.launchDuration) or 0.5) + 0.22)
    client.xSlotLaunchFxState.activeBeamsByShip[shipBodyId] = {
        shipBodyId = shipBodyId,
        weaponType = tostring(render.weaponType or ""),
        slotIndex = math.floor(render.slotIndex or 1),
        firePoint = _tableToVec(render.firePoint),
        hitPoint = _tableToVec(render.hitPoint),
        startTime = (GetTime ~= nil) and GetTime() or 0.0,
        duration = math.max(0.08, launchDuration),
        coreRadius = tonumber(weaponSettings.launchFxCoreRadius) or 0.42,
        coreRadiusPeak = tonumber(weaponSettings.launchFxCoreRadiusPeak) or 0.82,
        shellRadius = tonumber(weaponSettings.launchFxShellRadius) or 0.88,
        shellRadiusPeak = tonumber(weaponSettings.launchFxShellRadiusPeak) or 1.65,
        muzzleFlashRadius = tonumber(weaponSettings.launchFxMuzzleFlashRadius) or 1.4,
    }
end

local function _beamIntensity(normalizedTime)
    local rise = _smoothstep01(_clamp((normalizedTime or 0.0) / 0.24, 0.0, 1.0))
    local fall = 1.0 - _smoothstep01(_clamp(((normalizedTime or 0.0) - 0.72) / 0.28, 0.0, 1.0))
    local envelope = _clamp(math.min(rise, fall), 0.0, 1.0)
    return 0.18 + 0.82 * envelope
end

local function _spawnInfernalMuzzleFlash(firePoint, beamDir, intensity, flashRadius)
    PointLight(firePoint, 1.0, 0.82, 0.22, 3.5 + 6.0 * intensity)

    for _ = 1, math.max(3, math.floor(4 + intensity * 5)) do
        local jitter = Vec((math.random() - 0.5) * flashRadius, (math.random() - 0.5) * flashRadius, (math.random() - 0.5) * flashRadius * 0.4)
        local pos = VecAdd(firePoint, jitter)
        ParticleReset()
        ParticleColor(1.0, 0.98, 0.92, 1.0, 0.56, 0.08)
        ParticleRadius(0.45 + flashRadius * 0.18, 0.0, "easeout")
        ParticleAlpha(0.28 + 0.22 * intensity, 0.0)
        ParticleGravity(0.0)
        ParticleDrag(0.01)
        ParticleEmissive(26.0 + 30.0 * intensity, 0.0)
        ParticleCollide(0.0)
        SpawnParticle(pos, VecScale(beamDir, 0.6 + 2.4 * intensity), 0.06 + 0.05 * math.random())
    end
end

local function _spawnInfernalHitFlare(hitPoint, intensity)
    PointLight(hitPoint, 1.0, 0.32 + 0.18 * intensity, 0.08, 2.8 + 4.2 * intensity)

    for _ = 1, math.max(2, math.floor(3 + intensity * 4)) do
        local dir = Vec(
            (math.random() - 0.5) * 2.0,
            (math.random() - 0.5) * 2.0,
            (math.random() - 0.5) * 2.0
        )
        dir = _safeNormalize(dir, Vec(0, 1, 0))
        ParticleReset()
        ParticleColor(1.0, 0.88, 0.30, 0.92, 0.18, 0.03)
        ParticleRadius(0.22 + 0.18 * intensity, 0.0, "easeout")
        ParticleAlpha(0.22 + 0.16 * intensity, 0.0)
        ParticleGravity(0.0)
        ParticleDrag(0.03)
        ParticleEmissive(18.0 + 18.0 * intensity, 0.0)
        ParticleCollide(0.0)
        SpawnParticle(hitPoint, VecScale(dir, 1.0 + 3.2 * intensity), 0.08 + 0.06 * math.random())
    end
end

local function _spawnInfernalBeamParticles(beam, intensity, frameDt)
    local fire = beam.firePoint
    local hit = beam.hitPoint
    local beamVec = VecSub(hit, fire)
    local beamLen = VecLength(beamVec)
    if beamLen < 0.001 then
        return
    end

    local beamDir = VecScale(beamVec, 1.0 / beamLen)
    local right, up = _buildPerpBasis(beamDir)
    local weaponSettings = _resolveWeaponSettings(beam.weaponType)
    local coreRadius = (beam.coreRadius or 0.42) + ((beam.coreRadiusPeak or 0.82) - (beam.coreRadius or 0.42)) * intensity
    local shellRadius = (beam.shellRadius or 0.88) + ((beam.shellRadiusPeak or 1.65) - (beam.shellRadius or 0.88)) * intensity
    local tickScale = math.max(0.45, (frameDt or 0.016) * 60.0)
    local coreStep = math.max(0.25, tonumber(weaponSettings.launchFxCoreStep) or 2.0)
    local shellStep = math.max(0.25, tonumber(weaponSettings.launchFxShellStep) or 1.5)
    local coreBurstPerStep = math.max(1, math.floor(tonumber(weaponSettings.launchFxCoreBurstPerStep) or 2))
    local shellBurstPerStep = math.max(1, math.floor(tonumber(weaponSettings.launchFxShellBurstPerStep) or 3))
    local coreSamples = math.max(1, math.floor(beamLen / coreStep + 0.5))
    local shellSamples = math.max(1, math.floor(beamLen / shellStep + 0.5))
    local coreEmitters = math.max(1, math.floor(coreSamples * tickScale))
    local shellEmitters = math.max(1, math.floor(shellSamples * tickScale))

    _spawnInfernalMuzzleFlash(fire, beamDir, intensity, beam.muzzleFlashRadius or 1.4)
    _spawnInfernalHitFlare(hit, intensity)

    ParticleReset()
    ParticleColor(1.0, 0.98, 0.92, 1.0, 0.86, 0.34)
    ParticleRadius(0.14 + 0.28 * intensity, 0.02, "easeout")
    ParticleAlpha(0.78 + 0.18 * intensity, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.02)
    ParticleEmissive(28.0 + 34.0 * intensity, 0.0)
    ParticleCollide(0.0)
    for _ = 1, coreEmitters do
        local baseIndex = math.random(0, coreSamples)
        local baseT = _clamp((baseIndex * coreStep) / math.max(beamLen, 0.0001), 0.0, 1.0)
        for _ = 1, coreBurstPerStep do
            local t = _clamp(baseT + ((math.random() - 0.5) * coreStep * 0.45 / math.max(beamLen, 0.0001)), 0.0, 1.0)
            local base = VecAdd(fire, VecScale(beamVec, t))
            local a = math.random() * math.pi * 2.0
            local rr = math.random() * coreRadius * (0.18 + 0.35 * (1.0 - math.abs(0.5 - t) * 1.2))
            local off = VecAdd(VecScale(right, math.cos(a) * rr), VecScale(up, math.sin(a) * rr))
            local pos = VecAdd(base, off)
            local vel = VecScale(beamDir, 2.0 + 4.0 * intensity)
            SpawnParticle(pos, vel, 0.08 + 0.05 * math.random())
        end
    end

    ParticleReset()
    ParticleColor(1.0, 0.84, 0.18, 0.95, 0.16, 0.03)
    ParticleRadius(0.18 + 0.36 * intensity, 0.02, "easeout")
    ParticleAlpha(0.54 + 0.18 * intensity, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.04)
    ParticleEmissive(18.0 + 28.0 * intensity, 0.0)
    ParticleCollide(0.0)
    for _ = 1, shellEmitters do
        local baseIndex = math.random(0, shellSamples)
        local baseT = _clamp((baseIndex * shellStep) / math.max(beamLen, 0.0001), 0.0, 1.0)
        for _ = 1, shellBurstPerStep do
            local t = _clamp(baseT + ((math.random() - 0.5) * shellStep * 0.55 / math.max(beamLen, 0.0001)), 0.0, 1.0)
            local base = VecAdd(fire, VecScale(beamVec, t))
            local coneFactor = 0.55 + 0.55 * math.pow(1.0 - t, 0.35)
            local radius = shellRadius * coneFactor
            local a = math.random() * math.pi * 2.0
            local rr = radius * (0.55 + 0.45 * math.random())
            local off = VecAdd(VecScale(right, math.cos(a) * rr), VecScale(up, math.sin(a) * rr))
            local pos = VecAdd(base, off)
            local tangent = VecAdd(VecScale(right, -math.sin(a)), VecScale(up, math.cos(a)))
            tangent = _safeNormalize(tangent, right)
            local vel = VecAdd(
                VecScale(beamDir, 1.4 + 2.2 * intensity),
                VecScale(tangent, 0.5 + 1.0 * intensity)
            )
            SpawnParticle(pos, vel, 0.09 + 0.07 * math.random())
        end
    end

    local midPoint = VecAdd(fire, VecScale(beamVec, 0.45))
    PointLight(midPoint, 1.0, 0.62, 0.12, 2.2 + 3.6 * intensity)
end

function client.xSlotLaunchFxTick(dt)
    local state = client.xSlotLaunchFxState
    local cfg = client.xSlotLaunchFxConfig
    local frameDt = dt or 0.0
    local nowTime = (GetTime ~= nil) and GetTime() or 0.0

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
                    if render.eventType == "launch_start" then
                        if render.weaponType == "infernalRay" then
                            _beginInfernalBeam(shipBodyId, render)
                        else
                            _spawnLegacyLaunchFx(_tableToVec(render.firePoint), _tableToVec(render.hitPoint), cfg)
                        end
                    end
                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        else
            state.activeBeamsByShip[shipBodyId] = nil
        end
    end

    for shipBodyId, beam in pairs(state.activeBeamsByShip) do
        local elapsed = nowTime - (beam.startTime or nowTime)
        local duration = math.max(0.08, beam.duration or 0.72)
        if elapsed >= duration then
            state.activeBeamsByShip[shipBodyId] = nil
        else
            local normalized = _clamp(elapsed / duration, 0.0, 1.0)
            local intensity = _beamIntensity(normalized)
            _spawnInfernalBeamParticles(beam, intensity, frameDt)
        end
    end
end
