---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local ShieldConfig = {
    maxRing = 4,
    maxImpactRing = 7,
    hexEdgeLength = 0.92,
    sphereRadius = 0.0,
    sphereRadiusScale = 1.0,
    sphereRadiusMin = 2.5,
    surfaceOffset = 0.04,

    ringSpreadInterval = 0.055,
    hexLifetime = 0.62,
    hexRiseTime = 0.08,
    hexHoldTime = 0.24,
    hexStartScale = 0.85,
    hexColor = { 0.16, 0.82, 1.45 },
    hexAlpha = 0.88,

    flashLifetime = 0.14,
    flashSize = 1.9,
    lightLifetime = 0.17,
    lightIntensity = 14.0,
    lightMaxDistance = 520.0,

    sparkCount = 6,
    maxActiveBursts = 3,
}

client.shieldHitFxState = client.shieldHitFxState or {
    activeBursts = {},
    lastRenderSeqByShip = {},
    lastShotIdByShip = {},
    assets = { hex = 0, glow = 0 },
}

local SQRT3 = math.sqrt(3.0)

local function _clamp01(value)
    return math.max(0.0, math.min(1.0, value or 0.0))
end

local function _tableToVec(value)
    if value == nil then return Vec(0, 0, 0) end
    return Vec(value.x or 0, value.y or 0, value.z or 0)
end

local function _safeNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback end
    return VecScale(value, 1.0 / length)
end

local function _buildPerpBasis(normal)
    local reference = math.abs(normal[2]) < 0.90 and Vec(0, 1, 0) or Vec(1, 0, 0)
    local right = _safeNormalize(VecCross(normal, reference), Vec(1, 0, 0))
    local up = _safeNormalize(VecCross(right, normal), Vec(0, 1, 0))
    return right, up
end

local function _buildBasisFromReference(normal, reference)
    local projected = VecSub(reference, VecScale(normal, VecDot(reference, normal)))
    local right = _safeNormalize(projected, nil)
    if right == nil then return _buildPerpBasis(normal) end
    local up = _safeNormalize(VecCross(right, normal), Vec(0, 1, 0))
    return right, up
end

local function _ringCells(ring)
    if ring == 0 then return { { q = 0, r = 0, ring = 0 } } end

    local directions = {
        { 1, 0 }, { 1, -1 }, { 0, -1 },
        { -1, 0 }, { -1, 1 }, { 0, 1 },
    }
    local cells = {}
    local q, r = -ring, ring
    for side = 1, 6 do
        local direction = directions[side]
        for _ = 1, ring do
            q = q + direction[1]
            r = r + direction[2]
            cells[#cells + 1] = { q = q, r = r, ring = ring, side = side }
        end
    end
    return cells
end

local function _weaponTypeSeed(weaponType)
    local value = tostring(weaponType or "")
    local seed = 0
    for index = 1, #value do
        seed = (seed * 31 + string.byte(value, index)) % 104729
    end
    return seed
end

local function _resolveImpactRingCount(weaponType)
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    local strength = tonumber(definition.shieldImpactStrength)
    if strength == nil then strength = ShieldConfig.maxRing end
    return math.max(
        1,
        math.min(ShieldConfig.maxImpactRing, math.floor(strength))
    )
end

local function _buildDirectionalRingCaps(maxRing, seed)
    local deficits = { 0, 1, 2, 1, 0, 2 }
    local caps = {}
    local rotation = math.floor(math.abs(seed or 0)) % 6
    local reverse = math.floor(math.abs(seed or 0) / 6) % 2 == 1
    for side = 1, 6 do
        local source = reverse and (7 - side) or side
        local patternIndex = ((source + rotation - 2) % 6) + 1
        caps[side] = math.max(0, maxRing - deficits[patternIndex])
    end
    return caps
end

local function _buildHexCells(startTime, maxRing, directionalCaps)
    local cells = {}
    for ring = 0, ShieldConfig.maxRing + math.max(0, maxRing - ShieldConfig.maxRing) do
        local ringCells = _ringCells(ring)
        local spawnTime = startTime + ring * ShieldConfig.ringSpreadInterval
        for index = 1, #ringCells do
            local cell = ringCells[index]
            if ring == 0 or ring <= (directionalCaps[cell.side] or 0) then
                cells[#cells + 1] = {
                    q = cell.q,
                    r = cell.r,
                    ring = ring,
                    spawnTime = spawnTime,
                    endTime = spawnTime + ShieldConfig.hexLifetime,
                }
            end
        end
    end
    return cells
end

local function _hexEnvelope(now, cell)
    local age = now - cell.spawnTime
    if age < 0.0 or now >= cell.endTime then return nil end

    local rise = _clamp01(age / ShieldConfig.hexRiseTime)
    local easedRise = 1.0 - (1.0 - rise) * (1.0 - rise)
    local scale = ShieldConfig.hexStartScale + (1.0 - ShieldConfig.hexStartScale) * easedRise
    local alpha = ShieldConfig.hexAlpha * (0.50 + 0.50 * easedRise)
    if age > ShieldConfig.hexHoldTime then
        local fadeDuration = math.max(0.001, ShieldConfig.hexLifetime - ShieldConfig.hexHoldTime)
        local fade = _clamp01((age - ShieldConfig.hexHoldTime) / fadeDuration)
        alpha = alpha * (1.0 - fade) * (1.0 - fade)
    end
    return scale, alpha
end

local function _resolveShieldFrame(burst)
    local target = burst.hitTargetBodyId or 0
    if target == 0 or (IsHandleValid ~= nil and not IsHandleValid(target)) then return nil end

    local bodyTransform = GetBodyTransform(target)
    local center = TransformToParentPoint(bodyTransform, burst.centerLocal)
    local hitPoint = TransformToParentPoint(bodyTransform, burst.hitPointLocal)
    local normal = _safeNormalize(
        TransformToParentVec(bodyTransform, burst.hitNormalLocal),
        _safeNormalize(VecSub(hitPoint, center), Vec(0, 1, 0))
    )
    local reference = _safeNormalize(TransformToParentVec(bodyTransform, burst.t1Local), Vec(1, 0, 0))
    local right, up = _buildBasisFromReference(normal, reference)
    local dynamicRadius = math.max(ShieldConfig.sphereRadiusMin, VecLength(VecSub(hitPoint, center)))
    local radius = ShieldConfig.sphereRadius
    if radius <= 0.0 then radius = dynamicRadius * ShieldConfig.sphereRadiusScale end
    return center, hitPoint, normal, right, up, math.max(ShieldConfig.sphereRadiusMin, radius)
end

local function _projectCellToShield(center, hitPoint, hitNormal, right, up, radius, cell)
    local edge = ShieldConfig.hexEdgeLength
    local planeX = SQRT3 * edge * (cell.q + cell.r * 0.5)
    local planeY = 1.5 * edge * cell.r
    local planePoint = VecAdd(hitPoint, VecAdd(VecScale(right, planeX), VecScale(up, planeY)))
    local cellNormal = _safeNormalize(VecSub(planePoint, center), hitNormal)
    local position = VecAdd(center, VecScale(cellNormal, radius + ShieldConfig.surfaceOffset))
    local cellRight = _safeNormalize(
        VecSub(right, VecScale(cellNormal, VecDot(right, cellNormal))),
        right
    )
    return position, cellNormal, cellRight
end

local function _spawnImpactSparks(position, normal)
    local count = ShieldConfig.sparkCount
    if not client.weaponFxTakeParticles(count, "critical") then return end

    local right, up = _buildPerpBasis(normal)
    ParticleReset()
    ParticleType("plain")
    ParticleColor(0.80, 0.96, 1.0, 0.04, 0.32, 0.72)
    ParticleRadius(0.095, 0.015, "easeout")
    ParticleAlpha(1.0, 0.0, "easeout")
    ParticleGravity(0.0)
    ParticleDrag(0.14)
    ParticleEmissive(15.0, 0.0)
    ParticleStretch(2.0, 0.25, "easeout")
    ParticleCollide(0.0)
    for index = 1, count do
        local angle = 2.0 * math.pi * (index - 1) / count
        local tangent = VecAdd(VecScale(right, math.cos(angle)), VecScale(up, math.sin(angle)))
        local velocity = VecAdd(VecScale(normal, 2.5 + math.random() * 2.0), VecScale(tangent, 4.0 + math.random() * 4.0))
        SpawnParticle(position, velocity, 0.16 + math.random() * 0.10)
    end
end

local function _trimBurstLimit()
    local bursts = client.shieldHitFxState.activeBursts
    while #bursts >= ShieldConfig.maxActiveBursts do table.remove(bursts, 1) end
end

local function _startShieldBurst(shipBodyId, hitTargetBodyId, hitPointWorld, shotId, weaponType, explicitStrength)
    local _ = shipBodyId
    if hitTargetBodyId == nil or hitTargetBodyId == 0 then return end
    if IsHandleValid ~= nil and not IsHandleValid(hitTargetBodyId) then return end

    local bodyTransform = GetBodyTransform(hitTargetBodyId)
    local centerLocal = GetBodyCenterOfMass(hitTargetBodyId)
    local centerWorld = TransformToParentPoint(bodyTransform, centerLocal)
    local hitNormalWorld = _safeNormalize(VecSub(hitPointWorld, centerWorld), Vec(0, 1, 0))
    local rightWorld = _buildPerpBasis(hitNormalWorld)
    local now = GetTime()
    local maxRing = tonumber(explicitStrength)
        or _resolveImpactRingCount(weaponType)
    maxRing = math.max(
        1,
        math.min(ShieldConfig.maxImpactRing, math.floor(maxRing))
    )
    local localHit = TransformToLocalPoint(bodyTransform, hitPointWorld)
    local seed = _weaponTypeSeed(weaponType)
        + (tonumber(shotId) or 0) * 97
        + (tonumber(hitTargetBodyId) or 0) * 13
        + math.floor((localHit[1] or 0.0) * 17.0)
        + math.floor((localHit[2] or 0.0) * 31.0)
        + math.floor((localHit[3] or 0.0) * 47.0)
    local directionalCaps = _buildDirectionalRingCaps(maxRing, seed)

    _trimBurstLimit()
    _spawnImpactSparks(hitPointWorld, hitNormalWorld)
    table.insert(client.shieldHitFxState.activeBursts, {
        hitTargetBodyId = hitTargetBodyId,
        hitPointLocal = TransformToLocalPoint(bodyTransform, hitPointWorld),
        hitNormalLocal = TransformToLocalVec(bodyTransform, hitNormalWorld),
        t1Local = TransformToLocalVec(bodyTransform, rightWorld),
        centerLocal = centerLocal,
        startTime = now,
        endTime = now + maxRing * ShieldConfig.ringSpreadInterval + ShieldConfig.hexLifetime,
        shotId = tonumber(shotId) or 0,
        weaponType = tostring(weaponType or ""),
        maxRing = maxRing,
        directionalCaps = directionalCaps,
        hexes = _buildHexCells(now, maxRing, directionalCaps),
    })
end

local function _drawShieldBurst(burst, now)
    local center, hitPoint, hitNormal, right, up, radius = _resolveShieldFrame(burst)
    if center == nil then return false end
    hitPoint = hitPoint or center
    hitNormal = hitNormal or Vec(0, 1, 0)
    right = right or Vec(1, 0, 0)
    up = up or Vec(0, 0, 1)
    radius = radius or ShieldConfig.sphereRadiusMin

    local assets = client.shieldHitFxState.assets
    for index = #burst.hexes, 1, -1 do
        local cell = burst.hexes[index]
        local scale, alpha = _hexEnvelope(now, cell)
        if scale ~= nil and client.weaponFxTakeSprite(1) then
            local position, cellNormal, cellRight = _projectCellToShield(center, hitPoint, hitNormal, right, up, radius, cell)
            local edge = ShieldConfig.hexEdgeLength * scale
            DrawSprite(
                assets.hex,
                Transform(position, QuatAlignXZ(cellRight, cellNormal)),
                SQRT3 * edge,
                2.0 * edge,
                ShieldConfig.hexColor[1],
                ShieldConfig.hexColor[2],
                ShieldConfig.hexColor[3],
                alpha,
                true,
                true,
                false
            )
        end
    end

    local flashAge = now - burst.startTime
    if flashAge >= 0.0 and flashAge < ShieldConfig.flashLifetime then
        local flashAlpha = (1.0 - flashAge / ShieldConfig.flashLifetime) ^ 2
        if client.weaponFxTakeSprite(1) then
            DrawSprite(
                assets.glow,
                Transform(hitPoint, QuatLookAt(hitPoint, GetCameraTransform().pos)),
                ShieldConfig.flashSize * (0.72 + 0.50 * flashAge / ShieldConfig.flashLifetime),
                ShieldConfig.flashSize * (0.72 + 0.50 * flashAge / ShieldConfig.flashLifetime),
                0.72,
                0.94,
                1.45,
                flashAlpha,
                true,
                true,
                false
            )
        end
    end

    if flashAge >= 0.0 and flashAge < ShieldConfig.lightLifetime then
        local lightAlpha = (1.0 - flashAge / ShieldConfig.lightLifetime) ^ 2
        client.weaponFxPointLight(
            hitPoint,
            0.18,
            0.72,
            1.0,
            ShieldConfig.lightIntensity * lightAlpha,
            ShieldConfig.lightMaxDistance
        )
    end
    return true
end

function client.shieldHitFxInit()
    local state = client.shieldHitFxState
    state.activeBursts = {}
    state.lastRenderSeqByShip = {}
    state.lastShotIdByShip = {}
    state.assets = state.assets or {}
    state.assets.hex = LoadSprite("MOD/gfx/weapons/common/hex_soft.png")
    state.assets.glow = LoadSprite("MOD/gfx/weapons/projectiles/impact_glow.png")
end

function client.playProjectileShieldImpactFx(hitTargetBodyId, hitX, hitY, hitZ, weaponType)
    _startShieldBurst(
        0,
        hitTargetBodyId,
        Vec(hitX or 0, hitY or 0, hitZ or 0),
        0,
        weaponType
    )
end

function client.playExternalShieldImpactFx(hitTargetBodyId, hitX, hitY, hitZ, impactStrength)
    _startShieldBurst(
        0,
        hitTargetBodyId,
        Vec(hitX or 0, hitY or 0, hitZ or 0),
        0,
        "",
        impactStrength
    )
end

function client.shieldHitFxTick(dt)
    local _ = dt
    local state = client.shieldHitFxState
    local shipIds = client.registryShipGetRegisteredBodyIds()
    for index = 1, #shipIds do
        local shipBodyId = shipIds[index]
        if client.registryShipExists(shipBodyId) then
            local render = client.xSlotRenderGetEvent(shipBodyId)
            if render ~= nil then
                local seq = render.seq or -1
                local shotId = render.shotId or -1
                if seq ~= (state.lastRenderSeqByShip[shipBodyId] or -1) then
                    if render.eventType == "launch_start" and render.didHit == 1 and render.didHitShield == 1 then
                        _startShieldBurst(
                            shipBodyId,
                            render.hitTargetBodyId or 0,
                            _tableToVec(render.hitPoint),
                            shotId,
                            render.weaponType
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
    for index = #bursts, 1, -1 do
        local burst = bursts[index]
        if now >= burst.endTime or not _drawShieldBurst(burst, now) then
            table.remove(bursts, index)
        end
    end
end
