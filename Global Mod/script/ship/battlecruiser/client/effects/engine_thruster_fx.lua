-- Battlecruiser engine combustion and velocity-driven exhaust trails.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.engineThrusterFxConfig = client.engineThrusterFxConfig or {
    speedForFullTrail = 18.0,
    throttleResponse = 5.5,
    particleRate = 28.0,
    maxParticleBurstsPerFrame = 2,
}

client.engineThrusterFxState = client.engineThrusterFxState or {
    body = 0,
    nozzles = {},
    throttle = 0.0,
    particleAccumulator = 0.0,
    sprite = 0,
    age = 0.0,
}

local _engineThrusterProfiles = {
    thruster = {
        radius = 0.34,
        localOffset = Vec(0.2, 0.5, 0.2),
        sourceOffset = 0.42,
        idleLength = 0.70,
        trailLength = 5.8,
        particleRadius = 0.12,
    },
    smallThruster = {
        radius = 0.20,
        localOffset = Vec(0.0, 0.3, 0.2),
        sourceOffset = 0.24,
        idleLength = 0.38,
        trailLength = 3.0,
        particleRadius = 0.075,
    },
    engine = {
        radius = 0.11,
        burnAreaMin = Vec(0.0, 0.3, 0.0),
        burnAreaMax = Vec(0.2, 0.3, 1.4),
        burnColumns = 2,
        burnRows = 6,
        sourceOffset = 0.30,
        idleLength = 0.48,
        trailLength = 2.5,
        particleRadius = 0.065,
    },
}

local function _engineThrusterClamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function _engineThrusterDiscoverNozzles(body)
    local nozzles = {}
    for _, tag in ipairs({ "thruster", "smallThruster", "engine" }) do
        local shapes = FindShapes(tag, false) or {}
        for i = 1, #shapes do
            local shape = math.floor(shapes[i] or 0)
            if shape ~= 0 and IsHandleValid(shape) and GetShapeBody(shape) == body then
                nozzles[#nozzles + 1] = {
                    shape = shape,
                    tag = tag,
                    phase = (#nozzles + 1) * 1.73,
                }
            end
        end
    end
    return nozzles
end

local function _engineThrusterGetAxes(body)
    local bodyTransform = GetBodyTransform(body)
    local forward = TransformToParentVec(bodyTransform, Vec(0, 0, -1))
    local rear = TransformToParentVec(bodyTransform, Vec(0, 0, 1))
    local up = TransformToParentVec(bodyTransform, Vec(0, 1, 0))
    return bodyTransform, forward, rear, up
end

local function _engineThrusterGetAreaOffset(profile, u, v)
    if profile.burnAreaMin == nil or profile.burnAreaMax == nil then
        return profile.localOffset or Vec(0, 0, 0)
    end
    return Vec(
        profile.burnAreaMin[1]
            + (profile.burnAreaMax[1] - profile.burnAreaMin[1]) * u,
        profile.burnAreaMin[2]
            + (profile.burnAreaMax[2] - profile.burnAreaMin[2]) * v,
        profile.burnAreaMin[3]
            + (profile.burnAreaMax[3] - profile.burnAreaMin[3]) * v
    )
end

local function _engineThrusterGetSource(
    shapeTransform,
    rear,
    profile,
    rearScale,
    localOffset
)
    local offset = localOffset or profile.localOffset or Vec(0, 0, 0)
    return VecAdd(
        VecAdd(
            shapeTransform.pos,
            TransformToParentVec(shapeTransform, offset)
        ),
        VecScale(rear, profile.sourceOffset * (rearScale or 1.0))
    )
end

local function _engineThrusterSpawnBurnParticle(nozzle, rear, bodyVelocity, throttle, age)
    local profile = _engineThrusterProfiles[nozzle.tag] or _engineThrusterProfiles.engine
    local shapeTransform = GetShapeWorldTransform(nozzle.shape)
    local pulse = 0.90 + 0.10 * math.sin(age * 19.0 + nozzle.phase)
    local localOffset = _engineThrusterGetAreaOffset(
        profile,
        math.random(),
        math.random()
    )
    local source = _engineThrusterGetSource(
        shapeTransform,
        rear,
        profile,
        0.82 + 0.18 * pulse,
        localOffset
    )
    local scatter = Vec(
        (math.random() - 0.5) * profile.radius * 0.32,
        (math.random() - 0.5) * profile.radius * 0.32,
        0
    )
    source = VecAdd(source, TransformToParentVec(shapeTransform, scatter))
    local exhaustSpeed = 0.8 + throttle * 4.8 + math.random() * 0.7
    local velocity = VecAdd(bodyVelocity, VecScale(rear, exhaustSpeed))

    ParticleReset()
    ParticleColor(0.82, 0.94, 1.0, 0.08, 0.30, 1.0)
    ParticleRadius(
        profile.particleRadius * (0.78 + 0.28 * pulse),
        profile.particleRadius * 0.16,
        "easeout"
    )
    ParticleAlpha(0.92, 0.0)
    ParticleGravity(0.0)
    ParticleDrag(0.05)
    ParticleEmissive(18.0 + throttle * 22.0, 0.0)
    ParticleCollide(0.0)
    SpawnParticle(source, velocity, 0.16 + throttle * 0.18 + math.random() * 0.08)
end

local function _engineThrusterDrawFlameAtSource(
    sprite,
    nozzle,
    source,
    rear,
    up,
    throttle,
    age,
    profile
)
    local pulse = 0.97
        + 0.025 * math.sin(age * 18.0 + nozzle.phase)
        + 0.015 * math.sin(age * 37.0 + nozzle.phase * 1.9)
    local length = (profile.idleLength + profile.trailLength * throttle) * pulse
    local center = VecAdd(source, VecScale(rear, length * 0.5))
    local transform = Transform(center, QuatAlignXZ(rear, up))
    local outerWidth = profile.radius * (1.12 + throttle * 0.34)
    local coreLength = length * (0.62 + throttle * 0.10)
    local coreCenter = VecAdd(source, VecScale(rear, coreLength * 0.5))
    local coreTransform = Transform(coreCenter, QuatAlignXZ(rear, up))
    local alpha = 0.72 + throttle * 0.24

    DrawSprite(
        sprite,
        transform,
        length,
        outerWidth,
        0.10,
        0.42,
        1.35,
        alpha * 0.58,
        true,
        true,
        false
    )
    DrawSprite(
        sprite,
        coreTransform,
        coreLength,
        outerWidth * 0.34,
        2.4,
        2.7,
        3.0,
        alpha,
        true,
        true,
        false
    )

    if nozzle.tag == "thruster" then
        PointLight(source, 0.18, 0.48, 1.0, 0.32 + throttle * 0.42)
    end
end

local function _engineThrusterDrawFlame(sprite, nozzle, rear, up, throttle, age)
    local profile = _engineThrusterProfiles[nozzle.tag] or _engineThrusterProfiles.engine
    local shapeTransform = GetShapeWorldTransform(nozzle.shape)
    if profile.burnAreaMin ~= nil and profile.burnAreaMax ~= nil then
        local columns = math.max(1, math.floor(profile.burnColumns or 1))
        local rows = math.max(1, math.floor(profile.burnRows or 1))
        for row = 1, rows do
            local v = (row - 0.5) / rows
            for column = 1, columns do
                local u = (column - 0.5) / columns
                local source = _engineThrusterGetSource(
                    shapeTransform,
                    rear,
                    profile,
                    1.0,
                    _engineThrusterGetAreaOffset(profile, u, v)
                )
                _engineThrusterDrawFlameAtSource(
                    sprite,
                    nozzle,
                    source,
                    rear,
                    up,
                    throttle,
                    age + row * 0.07 + column * 0.11,
                    profile
                )
            end
        end
        return
    end

    local source = _engineThrusterGetSource(
        shapeTransform,
        rear,
        profile,
        1.0,
        profile.localOffset
    )
    _engineThrusterDrawFlameAtSource(
        sprite,
        nozzle,
        source,
        rear,
        up,
        throttle,
        age,
        profile
    )
end

function client.engineThrusterFxInit()
    local body = math.floor(client.shipBody or 0)
    client.engineThrusterFxState = {
        body = body,
        nozzles = body ~= 0 and _engineThrusterDiscoverNozzles(body) or {},
        throttle = 0.0,
        particleAccumulator = 0.0,
        sprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png"),
        age = 0.0,
    }
end

function client.engineThrusterFxTick(dt)
    local state = client.engineThrusterFxState
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    local body = math.floor(client.shipBody or state.body or 0)
    state.age = (state.age or 0.0) + frameDt

    if body == 0 or not IsHandleValid(body) then
        state.throttle = 0.0
        state.nozzles = {}
        return
    end
    if body ~= state.body or #(state.nozzles or {}) == 0 then
        state.body = body
        state.nozzles = _engineThrusterDiscoverNozzles(body)
    end

    local _, forward, rear = _engineThrusterGetAxes(body)
    local bodyVelocity = GetBodyVelocity(body)
    local forwardSpeed = math.max(0.0, VecDot(bodyVelocity, forward))
    local fullTrailSpeed = math.max(
        0.1,
        tonumber(client.engineThrusterFxConfig.speedForFullTrail) or 18.0
    )
    local targetThrottle = _engineThrusterClamp(forwardSpeed / fullTrailSpeed, 0.0, 1.0)
    local response = math.max(
        0.1,
        tonumber(client.engineThrusterFxConfig.throttleResponse) or 5.5
    )
    local blend = 1.0 - math.exp(-response * frameDt)
    state.throttle = (state.throttle or 0.0)
        + (targetThrottle - (state.throttle or 0.0)) * blend

    state.particleAccumulator = (state.particleAccumulator or 0.0)
        + frameDt * math.max(
            0.0,
            tonumber(client.engineThrusterFxConfig.particleRate) or 28.0
        )
    local burstCount = math.min(
        math.floor(state.particleAccumulator),
        math.max(
            1,
            math.floor(client.engineThrusterFxConfig.maxParticleBurstsPerFrame or 2)
        )
    )
    state.particleAccumulator = state.particleAccumulator - burstCount

    for _ = 1, burstCount do
        for i = 1, #(state.nozzles or {}) do
            local nozzle = state.nozzles[i]
            if IsHandleValid(nozzle.shape) and GetShapeBody(nozzle.shape) == body then
                _engineThrusterSpawnBurnParticle(
                    nozzle,
                    rear,
                    bodyVelocity,
                    state.throttle,
                    state.age
                )
            end
        end
    end
end

function client.engineThrusterFxRender()
    local state = client.engineThrusterFxState
    local body = math.floor(state.body or 0)
    local sprite = math.floor(state.sprite or 0)
    if body == 0 or sprite == 0 or not IsHandleValid(body) then return end

    local _, _, rear, up = _engineThrusterGetAxes(body)
    for i = 1, #(state.nozzles or {}) do
        local nozzle = state.nozzles[i]
        if IsHandleValid(nozzle.shape) and GetShapeBody(nozzle.shape) == body then
            _engineThrusterDrawFlame(
                sprite,
                nozzle,
                rear,
                up,
                state.throttle or 0.0,
                state.age or 0.0
            )
        end
    end
end
