-- Battlecruiser engine combustion and velocity-driven exhaust trails.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.engineThrusterFxState = client.engineThrusterFxState or {
    body = 0,
    nozzles = {},
    throttle = 0.0,
    particleAccumulator = 0.0,
    sprite = 0,
    age = 0.0,
    cameraDistance = 0.0,
}

local function _engineThrusterConfig()
    return client.shipContextGetDefinition().engineFx or {}
end

local function _engineThrusterProfile(tag)
    local profiles = _engineThrusterConfig().profiles or {}
    return profiles[tag] or profiles.engine or {}
end

local function _engineThrusterClamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function _engineThrusterDiscoverNozzles(body)
    local nozzles = {}
    local tags = {}
    for tag, _ in pairs(_engineThrusterConfig().profiles or {}) do
        tags[#tags + 1] = tostring(tag)
    end
    table.sort(tags)
    for _, tag in ipairs(tags) do
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
    local profile = _engineThrusterProfile(nozzle.tag)
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
    local profile = _engineThrusterProfile(nozzle.tag)
    local shapeTransform = GetShapeWorldTransform(nozzle.shape)
    if profile.burnAreaMin ~= nil and profile.burnAreaMax ~= nil then
        local columns = math.max(1, math.floor(profile.burnColumns or 1))
        local rows = math.max(1, math.floor(profile.burnRows or 1))
        if (client.engineThrusterFxState.cameraDistance or 0.0)
            > (_engineThrusterConfig().particleCutoffDistance or 600.0) then
            columns = 1
            rows = math.min(rows, 2)
        end
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
    local body = client.shipContextGetBody()
    client.engineThrusterFxState = {
        body = body,
        nozzles = body ~= 0 and _engineThrusterDiscoverNozzles(body) or {},
        throttle = 0.0,
        particleAccumulator = 0.0,
        sprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png"),
        age = 0.0,
        cameraDistance = 0.0,
    }
end

function client.engineThrusterFxTick(dt)
    local state = client.engineThrusterFxState
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    local body = client.shipContextGetBody()
    if body == 0 then body = math.floor(state.body or 0) end
    state.age = (state.age or 0.0) + frameDt

    if body == 0 or not IsHandleValid(body) then
        state.throttle = 0.0
        state.nozzles = {}
        return
    end

    -- 优化：检测是否有任何玩家在驾驶这艘飞船
    local hasDriver = false
    for _, playerId in ipairs(GetAllPlayers() or {}) do
        local vehicle = GetPlayerVehicle(playerId)
        if vehicle ~= nil and vehicle ~= 0 then
            local vehicleBody = GetVehicleBody(vehicle)
            if vehicleBody == body then
                hasDriver = true
                break
            end
        end
    end

    if not hasDriver then
        -- 无人驾驶：平滑关闭尾焰
        local response = 12.0
        local blend = 1.0 - math.exp(-response * frameDt)
        state.throttle = (state.throttle or 0.0) * (1.0 - blend)
        if state.throttle < 0.01 then
            state.throttle = 0.0
            state.particleAccumulator = 0.0
            return
        end
        state.particleAccumulator = 0.0
        return
    end
    if body ~= state.body or #(state.nozzles or {}) == 0 then
        state.body = body
        state.nozzles = _engineThrusterDiscoverNozzles(body)
    end

    local _, forward, rear = _engineThrusterGetAxes(body)
    state.cameraDistance = VecLength(VecSub(
        GetBodyTransform(body).pos,
        GetCameraTransform().pos
    ))
    local bodyVelocity = GetBodyVelocity(body)
    local forwardSpeed = math.max(0.0, VecDot(bodyVelocity, forward))
    local fullTrailSpeed = math.max(
        0.1,
        tonumber(_engineThrusterConfig().speedForFullTrail) or 18.0
    )
    local targetThrottle = _engineThrusterClamp(forwardSpeed / fullTrailSpeed, 0.0, 1.0)
    local response = math.max(
        0.1,
        tonumber(_engineThrusterConfig().throttleResponse) or 5.5
    )
    local blend = 1.0 - math.exp(-response * frameDt)
    state.throttle = (state.throttle or 0.0)
        + (targetThrottle - (state.throttle or 0.0)) * blend

    local cfg = _engineThrusterConfig()
    local distanceScale = 1.0
    if state.cameraDistance >= (cfg.particleCutoffDistance or 600.0) then
        distanceScale = 0.0
    elseif state.cameraDistance >= (cfg.particleNearDistance or 250.0) then
        distanceScale = cfg.farParticleRateScale or 0.35
    end
    local idleScale = cfg.idleParticleRateScale or 0.20
    local throttleScale = idleScale
        + (1.0 - idleScale) * (state.throttle or 0.0)
    local effectiveRate = math.max(
        0.0,
        tonumber(cfg.particleRate) or 28.0
    ) * distanceScale * throttleScale
    if effectiveRate <= 0.0 then
        state.particleAccumulator = 0.0
    else
        state.particleAccumulator = (state.particleAccumulator or 0.0)
            + frameDt * effectiveRate
    end
    local burstCount = math.min(
        math.floor(state.particleAccumulator),
        math.max(
            1,
            math.floor(cfg.maxParticleBurstsPerFrame or 2)
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

    -- 优化：无人驾驶时不渲染尾焰
    local hasDriver = false
    local playerId = GetLocalPlayer()
    if playerId ~= nil and playerId > 0 then
        local vehicle = GetPlayerVehicle(playerId)
        if vehicle ~= nil and vehicle ~= 0 then
            local vehicleBody = GetVehicleBody(vehicle)
            hasDriver = (vehicleBody == body)
        end
    end
    if not hasDriver then return end

    if (state.cameraDistance or 0.0)
        > (_engineThrusterConfig().renderCutoffDistance or 1200.0) then
        return
    end

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
