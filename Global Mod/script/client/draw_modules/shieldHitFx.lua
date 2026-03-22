---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local ShieldConfig = {
    maxRing = 4,
    guaranteeRing = 3,

    hexEdgeLength = 0.9,
    sphereRadius = 0.0,
    sphereRadiusScale = 1.35,
    sphereRadiusMin = 2.5,

    particleRadius = 0.055,
    particleColor = {0.2, 0.7, 1.0},
    particleIntensity = 8.0,

    hexLifetime = 0.5,
    spreadInterval = 0.05,

    minProbability = 0.20,
    noiseScale = 0.45,

    fadeInTime = 0.05,
    fadeOutTime = 0.3,
    particleJitter = 0.01,

    hitGlowLifetime = 0.3,
    hitGlowFadeOutTime = 0.2,
    hitGlowBaseRadius = 5.0,
    hitGlowPulseRadius = 6.0,
    hitGlowPulseSpeed = 24.0,

    maxParticlesPerFrame = 1800,
    minParticlesPerHex = 14,
    maxParticlesPerHex = 96,
}

client.shieldHitFxState = client.shieldHitFxState or {
    activeBursts = {},
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
}

local SQRT3 = math.sqrt(3.0)

local function _tableToVec(t)
    if t == nil then return Vec(0, 0, 0) end
    return Vec(t.x or 0, t.y or 0, t.z or 0)
end

local function _safeNormalize(v, fallback)
    local l = VecLength(v)
    if l < 0.0001 then return fallback end
    return VecScale(v, 1.0 / l)
end

local function _fract(x)
    return x - math.floor(x)
end

local function _noise2D(x, y, seed)
    local n = math.sin(x * 12.9898 + y * 78.233 + seed * 37.719) * 43758.5453
    return _fract(n)
end

local function _probabilityByRing(ring)
    if ring <= ShieldConfig.guaranteeRing then
        return 1.0
    end

    local den = math.max(1, ShieldConfig.maxRing - ShieldConfig.guaranteeRing)
    local t = (ring - ShieldConfig.guaranteeRing) / den
    return 1.0 - t * (1.0 - ShieldConfig.minProbability)
end

local function _ringCells(k)
    if k == 0 then
        return { { q = 0, r = 0 } }
    end

    local dirs = {
        { 1, 0 },
        { 1, -1 },
        { 0, -1 },
        { -1, 0 },
        { -1, 1 },
        { 0, 1 },
    }

    local out = {}
    local q = -k
    local r = k

    for side = 1, 6 do
        local d = dirs[side]
        for _ = 1, k do
            q = q + d[1]
            r = r + d[2]
            out[#out + 1] = { q = q, r = r }
        end
    end

    return out
end

local function _buildPerpBasis(n)
    local up = Vec(0, 1, 0)
    local t1 = VecCross(n, up)
    t1 = _safeNormalize(t1, Vec(1, 0, 0))
    local t2 = VecCross(n, t1)
    t2 = _safeNormalize(t2, Vec(0, 1, 0))
    return t1, t2
end

local function _buildBasisFromReference(n, ref)
    local refProj = VecSub(ref, VecScale(n, VecDot(ref, n)))
    local t1 = _safeNormalize(refProj, nil)
    if t1 == nil then
        local fb1, fb2 = _buildPerpBasis(n)
        return fb1, fb2
    end
    local t2 = _safeNormalize(VecCross(n, t1), Vec(0, 1, 0))
    return t1, t2
end

local function _lerpVec(a, b, t)
    return VecAdd(a, VecScale(VecSub(b, a), t))
end

local function _jitterVec(v, j)
    if j <= 0.0 then return v end
    local r = Vec((math.random() - 0.5) * 2.0, (math.random() - 0.5) * 2.0, (math.random() - 0.5) * 2.0)
    return VecAdd(v, VecScale(r, j))
end

local function _computeHexCenterWorld(hitPoint, shieldCenter, radius, t1, t2, q, r)
    local x = ShieldConfig.hexEdgeLength * (1.5 * q)
    local y = ShieldConfig.hexEdgeLength * ((SQRT3 * 0.5) * q + SQRT3 * r)
    local p = VecAdd(hitPoint, VecAdd(VecScale(t1, x), VecScale(t2, y)))

    local fallback = _safeNormalize(VecSub(hitPoint, shieldCenter), Vec(0, 1, 0))
    local dir = _safeNormalize(VecSub(p, shieldCenter), fallback)
    return VecAdd(shieldCenter, VecScale(dir, radius))
end

local function _computeHexVerticesWorld(hexCenter, shieldCenter, radius, refT1)
    local n = _safeNormalize(VecSub(hexCenter, shieldCenter), Vec(0, 1, 0))
    local t1, t2 = _buildBasisFromReference(n, refT1)

    local vertices = {}
    for i = 0, 5 do
        local theta = math.rad(i * 60.0)
        local planeOffset = VecAdd(
            VecScale(t1, math.cos(theta) * ShieldConfig.hexEdgeLength),
            VecScale(t2, math.sin(theta) * ShieldConfig.hexEdgeLength)
        )
        local p = VecAdd(hexCenter, planeOffset)
        local dir = _safeNormalize(VecSub(p, shieldCenter), n)
        vertices[#vertices + 1] = VecAdd(shieldCenter, VecScale(dir, radius))
    end

    return vertices
end

local function _hexIntensity(now, spawnTime)
    local life = ShieldConfig.hexLifetime
    local age = now - spawnTime
    if age < 0.0 or age >= life then
        return 0.0
    end

    local fadeIn = math.max(0.0001, ShieldConfig.fadeInTime)
    local fadeOut = math.max(0.0001, ShieldConfig.fadeOutTime)

    if age < fadeIn then
        return math.max(0.0, math.min(1.0, age / fadeIn))
    end

    local remain = life - age
    if remain < fadeOut then
        return math.max(0.0, math.min(1.0, remain / fadeOut))
    end

    return 1.0
end
local function _hitGlowIntensity(now, startTime, life, fadeOut)
    local age = now - startTime
    if age < 0.0 or age >= life then
        return 0.0
    end

    local outTime = math.max(0.0001, math.min(fadeOut, life))
    local remain = life - age
    if remain < outTime then
        return math.max(0.0, math.min(1.0, remain / outTime))
    end

    return 1.0
end

local function _emitHexEdgeParticles(vertices, shieldCenter, intensity, perHexBudget, budgetLeft)
    local budgetCap = math.min(perHexBudget, budgetLeft)
    if budgetCap <= 0 then return 0 end

    local edgeCounts = {}
    local totalIdeal = 0
    local diameter = math.max(0.002, ShieldConfig.particleRadius * 2.0)

    for i = 1, 6 do
        local a = vertices[i]
        local b = vertices[(i % 6) + 1]
        local edgeLen = VecLength(VecSub(b, a))
        local count = math.max(2, math.ceil(edgeLen / diameter))
        edgeCounts[i] = count
        totalIdeal = totalIdeal + count
    end

    local step = math.max(1, math.ceil(totalIdeal / math.max(1, budgetCap)))

    local color = ShieldConfig.particleColor
    local r = color[1] or 0.2
    local g = color[2] or 0.7
    local b = color[3] or 1.0

    ParticleReset()
    ParticleColor(r, g, b, r * 0.35, g * 0.45, b * 0.55)
    ParticleRadius(ShieldConfig.particleRadius, ShieldConfig.particleRadius * 0.65, "easeout")
    ParticleAlpha(0.95 * intensity, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.1)
    ParticleEmissive(ShieldConfig.particleIntensity * intensity, 0.0)
    ParticleCollide(0.0)

    local used = 0
    for i = 1, 6 do
        local a = vertices[i]
        local b = vertices[(i % 6) + 1]
        local count = edgeCounts[i]

        local j = 0
        while j <= (count - 1) do
            if used >= budgetCap then
                return used
            end

            local t = 0.0
            if count > 1 then
                t = j / (count - 1)
            end

            local p = _lerpVec(a, b, t)
            p = _jitterVec(p, ShieldConfig.particleJitter)

            local outward = _safeNormalize(VecSub(p, shieldCenter), Vec(0, 1, 0))
            local vel = VecScale(outward, 0.15 + 0.25 * math.random())

            SpawnParticle(p, vel, 0.10 + 0.08 * math.random())
            used = used + 1
            j = j + step
        end

        if ((count - 1) % step) ~= 0 and used < budgetCap then
            local p = _jitterVec(b, ShieldConfig.particleJitter)
            local outward = _safeNormalize(VecSub(p, shieldCenter), Vec(0, 1, 0))
            local vel = VecScale(outward, 0.15 + 0.25 * math.random())
            SpawnParticle(p, vel, 0.10 + 0.08 * math.random())
            used = used + 1
        end
    end

    return used
end

local function _startShieldBurst(shipBodyId, shipType, hitTargetBodyId, hitPointWorld, shotId)
    local _ = shipBodyId
    local _shipType = shipType

    if hitTargetBodyId == nil or hitTargetBodyId == 0 then
        return
    end
    if IsHandleValid ~= nil and (not IsHandleValid(hitTargetBodyId)) then
        return
    end

    local bodyT = GetBodyTransform(hitTargetBodyId)
    local centerLocal = GetBodyCenterOfMass(hitTargetBodyId)
    local centerWorld = TransformToParentPoint(bodyT, centerLocal)

    local hitNormalWorld = _safeNormalize(VecSub(hitPointWorld, centerWorld), Vec(0, 1, 0))
    local t1World, _t2World = _buildPerpBasis(hitNormalWorld)

    local hitPointLocal = TransformToLocalPoint(bodyT, hitPointWorld)
    local hitNormalLocal = TransformToLocalVec(bodyT, hitNormalWorld)
    local t1Local = TransformToLocalVec(bodyT, t1World)

    local now = GetTime()
    local seed = (tonumber(shotId) or 0) + hitTargetBodyId * 131

    local hexes = {}
    for ring = 0, ShieldConfig.maxRing do
        local pRing = _probabilityByRing(ring)
        local cells = _ringCells(ring)

        for i = 1, #cells do
            local q = cells[i].q
            local r = cells[i].r
            local n = _noise2D(q * ShieldConfig.noiseScale, r * ShieldConfig.noiseScale, seed)
            if n < pRing then
                local spawnTime = now + ring * ShieldConfig.spreadInterval
                hexes[#hexes + 1] = {
                    q = q,
                    r = r,
                    ring = ring,
                    spawnTime = spawnTime,
                    endTime = spawnTime + ShieldConfig.hexLifetime,
                }
            end
        end
    end

    local shieldEnd = now + ShieldConfig.maxRing * ShieldConfig.spreadInterval + ShieldConfig.hexLifetime
    local glowLife = ShieldConfig.hitGlowLifetime or 0.0
    local glowEnd = now + math.max(0.0, glowLife)

    table.insert(client.shieldHitFxState.activeBursts, {
        hitTargetBodyId = hitTargetBodyId,
        hitPointLocal = hitPointLocal,
        hitNormalLocal = hitNormalLocal,
        t1Local = t1Local,
        centerLocal = centerLocal,
        startTime = now,
        endTime = math.max(shieldEnd, glowEnd),
        hexes = hexes,
    })
end

function client.shieldHitFxTick(dt)
    local state = client.shieldHitFxState
    local _ = dt

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
                    if render.eventType == "launch_start" and render.didHit == 1 and render.didHitShield == 1 then
                        _startShieldBurst(
                            shipBodyId,
                            snapshot.shipType,
                            render.hitTargetBodyId or 0,
                            _tableToVec(render.hitPoint),
                            shotId
                        )
                    end

                    state.lastRenderSeqByShip[shipBodyId] = seq
                    state.lastShotIdByShip[shipBodyId] = shotId
                end
            end
        end
    end

    local now = GetTime()
    local bursts = state.activeBursts
    local frameBudgetLeft = ShieldConfig.maxParticlesPerFrame

    local i = #bursts
    while i >= 1 do
        local burst = bursts[i]
        local target = burst.hitTargetBodyId or 0

        if target == 0 or (IsHandleValid ~= nil and (not IsHandleValid(target))) or now >= burst.endTime then
            table.remove(bursts, i)
        else
            local bodyT = GetBodyTransform(target)
            local center = TransformToParentPoint(bodyT, burst.centerLocal)
            local hitPoint = TransformToParentPoint(bodyT, burst.hitPointLocal)

            local nWorld = _safeNormalize(
                TransformToParentVec(bodyT, burst.hitNormalLocal),
                _safeNormalize(VecSub(hitPoint, center), Vec(0, 1, 0))
            )
            local t1Ref = _safeNormalize(TransformToParentVec(bodyT, burst.t1Local), Vec(1, 0, 0))
            local t1, t2 = _buildBasisFromReference(nWorld, t1Ref)

            local dynamicRadius = VecLength(VecSub(hitPoint, center))
            if dynamicRadius < 0.001 then
                dynamicRadius = ShieldConfig.sphereRadiusMin
            end

            local radius = ShieldConfig.sphereRadius
            if radius <= 0.0 then
                local scale = ShieldConfig.sphereRadiusScale or 1.0
                radius = dynamicRadius * scale
            end
            radius = math.max(ShieldConfig.sphereRadiusMin or 0.2, radius)

            local activeHexes = {}
            for h = 1, #burst.hexes do
                local hex = burst.hexes[h]
                local intensity = _hexIntensity(now, hex.spawnTime)
                if intensity > 0.001 and now < hex.endTime then
                    activeHexes[#activeHexes + 1] = {
                        q = hex.q,
                        r = hex.r,
                        intensity = intensity,
                    }
                end
            end

            local glowLife = math.max(0.0, ShieldConfig.hitGlowLifetime or 0.0)
            local glowFadeOut = ShieldConfig.hitGlowFadeOutTime or 0.2
            local glowIntensity = _hitGlowIntensity(now, burst.startTime or now, glowLife, glowFadeOut)
            if glowIntensity > 0.001 then
                local pulseSpeed = ShieldConfig.hitGlowPulseSpeed or 24.0
                local pulse = 0.65 + 0.35 * math.sin(now * pulseSpeed)
                local ccol = ShieldConfig.particleColor
                local baseR = ShieldConfig.hitGlowBaseRadius or 5.0
                local pulseR = ShieldConfig.hitGlowPulseRadius or 6.0
                PointLight(hitPoint, ccol[1], ccol[2], ccol[3], (baseR + pulseR * pulse) * glowIntensity)
            end

            if #activeHexes > 0 and frameBudgetLeft > 0 then
                local perHexBudget = math.floor(frameBudgetLeft / #activeHexes)
                perHexBudget = math.max(ShieldConfig.minParticlesPerHex, perHexBudget)
                perHexBudget = math.min(ShieldConfig.maxParticlesPerHex, perHexBudget)

                local budgetLeft = frameBudgetLeft
                for h = 1, #activeHexes do
                    if budgetLeft <= 0 then break end

                    local hex = activeHexes[h]
                    local hexCenter = _computeHexCenterWorld(hitPoint, center, radius, t1, t2, hex.q, hex.r)
                    local vertices = _computeHexVerticesWorld(hexCenter, center, radius, t1)
                    local used = _emitHexEdgeParticles(vertices, center, hex.intensity, perHexBudget, budgetLeft)
                    budgetLeft = budgetLeft - used
                end

                frameBudgetLeft = budgetLeft
            end
        end

        i = i - 1
    end
end
