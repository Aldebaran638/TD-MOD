#version 2
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.displayCraftEngineFx = client.displayCraftEngineFx or {
    shape = 0,
    engines = {},
    sprite = 0,
    beams = {},
    fireAccumulator = 0.0,
    carrierBody = 0,
    targetBody = 0,
    targetScanRemain = 0.0,
    age = 0.0,
    particleAccumulator = 0.0,
}

server = server or {}

server.vehicleStrikeCraftTest = server.vehicleStrikeCraftTest or {
    craftBody = 0,
    craftShape = 0,
    carrierBody = 0,
    targetBody = 0,
    targetScanRemain = 0.0,
    fireAccumulator = 0.0,
}

local function _displayCraftBodyCenter(body)
    if body == nil or body == 0 or not IsHandleValid(body) then return nil end
    return TransformToParentPoint(GetBodyTransform(body), GetBodyCenterOfMass(body))
end

local function _displayCraftResolveCarrierBody(currentCarrier)
    if currentCarrier ~= nil and currentCarrier ~= 0 and IsHandleValid(currentCarrier) then
        return currentCarrier
    end
    local hull = FindShape("hull", true)
    return hull ~= nil and hull ~= 0 and GetShapeBody(hull) or 0
end

local function _displayCraftFindNearestVehicle(craftBody, carrierBody)
    local craftCenter = _displayCraftBodyCenter(craftBody)
    if craftCenter == nil then return 0, nil end

    local closestBody, closestCenter, closestDistanceSq = 0, nil, math.huge
    local vehicles = FindVehicles("", true) or {}
    for index = 1, #vehicles do
        local body = GetVehicleBody(vehicles[index])
        if body ~= nil and body ~= 0 and body ~= craftBody and body ~= carrierBody
            and IsHandleValid(body) then
            local center = _displayCraftBodyCenter(body)
            if center ~= nil then
                local delta = VecSub(center, craftCenter)
                local distanceSq = VecDot(delta, delta)
                if distanceSq < closestDistanceSq then
                    closestBody, closestCenter, closestDistanceSq = body, center, distanceSq
                end
            end
        end
    end
    return closestBody, closestCenter
end

local function _displayCraftResolveServerEntities()
    local state = server.vehicleStrikeCraftTest
    if state.craftBody == nil or state.craftBody == 0
        or not IsHandleValid(state.craftBody) then
        state.craftBody = FindBody("strikeCraftModelTest", true)
    end
    if state.craftShape == nil or state.craftShape == 0
        or not IsHandleValid(state.craftShape) then
        state.craftShape = FindShape("strikeCraftModelTest", true)
    end
    state.carrierBody = _displayCraftResolveCarrierBody(state.carrierBody)
end

local function _displayCraftResolveMuzzle(shape)
    if shape == nil or shape == 0 or not IsHandleValid(shape) then
        return nil
    end
    local boundsMin, boundsMax = GetShapeBounds(shape)
    return Vec(
        (boundsMin[1] + boundsMax[1]) * 0.5,
        (boundsMin[2] + boundsMax[2]) * 0.5,
        boundsMin[3] - 0.06
    )
end

function server.init()
    _displayCraftResolveServerEntities()
end

function server.tick(dt)
    local state = server.vehicleStrikeCraftTest
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    _displayCraftResolveServerEntities()
    if state.craftBody == nil or state.craftBody == 0
        or state.craftShape == nil or state.craftShape == 0 then return end

    state.targetScanRemain = (state.targetScanRemain or 0.0) - frameDt
    local targetCenter = _displayCraftBodyCenter(state.targetBody)
    if state.targetScanRemain <= 0.0 or targetCenter == nil then
        state.targetBody, targetCenter = _displayCraftFindNearestVehicle(state.craftBody, state.carrierBody)
        state.targetScanRemain = 0.25
    end
    if targetCenter == nil then
        state.fireAccumulator = math.min(state.fireAccumulator or 0.0, 0.16)
        return
    end

    state.fireAccumulator = (state.fireAccumulator or 0.0) + frameDt
    while state.fireAccumulator >= 0.16 and targetCenter ~= nil do
        state.fireAccumulator = state.fireAccumulator - 0.16
        local muzzle = _displayCraftResolveMuzzle(state.craftShape)
        if muzzle ~= nil then
            local aim = VecSub(targetCenter, muzzle)
            local length = VecLength(aim)
            if length > 0.001 then
                QueryRequire("physical")
                QueryRejectBody(state.craftBody)
                if state.carrierBody ~= nil and state.carrierBody ~= 0 then
                    QueryRejectBody(state.carrierBody)
                end
                local hit, distance, _, hitShape = QueryRaycast(muzzle, VecScale(aim, 1.0 / length), length + 2.0, 0.05)
                local hitBody = hit and hitShape ~= nil and hitShape ~= 0 and GetShapeBody(hitShape) or 0
                if hitBody == state.craftBody or hitBody == state.carrierBody then
                    hit, hitBody, distance = false, 0, length
                end
                SetBool("level.stellarisships.test.strikecraft.selfhit", false)
                SetInt("level.stellarisships.test.strikecraft.targetbody", state.targetBody)
                SetFloat("level.stellarisships.test.strikecraft.distance", hit and distance or length)
            end
        end
    end
end

local function _displayCraftResolveEngines()
    local state = client.displayCraftEngineFx
    if state.shape == nil or state.shape == 0 then return {} end

    local boundsMin, boundsMax = GetShapeBounds(state.shape)
    local boundsSize = VecSub(boundsMax, boundsMin)
    local engineHeight = boundsMin[2] + boundsSize[2] * (4.5 / 12.0)
    local exhaustZ = boundsMax[3] + 0.03
    return {
        Transform(Vec(
            boundsMin[1] + boundsSize[1] * (15.5 / 45.0),
            engineHeight,
            exhaustZ
        )),
        Transform(Vec(
            boundsMin[1] + boundsSize[1] * (29.5 / 45.0),
            engineHeight,
            exhaustZ
        )),
    }
end

local function _displayCraftNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, 1) end
    return VecScale(value, 1.0 / length)
end

local function _displayCraftSpawnExhaust(transform, pulse)
    local rear = _displayCraftNormalize(
        TransformToParentVec(transform, Vec(0, 0, 1)),
        Vec(0, 0, 1)
    )
    local source = VecAdd(transform.pos, VecScale(rear, 0.06))
    local scatter = TransformToParentVec(
        transform,
        Vec(
            (math.random() - 0.5) * 0.11,
            (math.random() - 0.5) * 0.11,
            0
        )
    )

    ParticleReset()
    ParticleType("plain")
    ParticleColor(0.72, 1.00, 1.00, 0.02, 0.18, 0.92)
    ParticleRadius(0.095 * pulse, 0.012, "easeout")
    ParticleAlpha(0.88, 0.0, "easeout")
    ParticleGravity(0.0)
    ParticleDrag(0.08)
    ParticleEmissive(24.0, 0.0)
    ParticleStretch(1.7, 0.2, "easeout")
    ParticleCollide(0.0)
    SpawnParticle(
        source,
        VecAdd(VecScale(rear, 4.8 + math.random() * 1.8), scatter),
        0.20 + math.random() * 0.08
    )
end

function client.init()
    local state = client.displayCraftEngineFx
    state.shape = FindShape("strikeCraftModelTest", true)
    state.engines = _displayCraftResolveEngines()
    state.sprite = LoadSprite(
        "MOD/gfx/weapons/tachyon_lance/beam_soft.png"
    )
    state.beams = {}
    state.fireAccumulator = 0.0
    state.carrierBody = _displayCraftResolveCarrierBody(0)
    state.targetBody = 0
    state.targetScanRemain = 0.0
    state.age = 0.0
    state.particleAccumulator = 0.0
end

local function _displayCraftSpawnVehicleBeam()
    local state = client.displayCraftEngineFx
    if state.shape == nil or state.shape == 0 then return end
    local craftBody = GetShapeBody(state.shape)
    state.carrierBody = _displayCraftResolveCarrierBody(state.carrierBody)
    local targetCenter = _displayCraftBodyCenter(state.targetBody)
    if state.targetScanRemain <= 0.0 or targetCenter == nil then
        state.targetBody, targetCenter = _displayCraftFindNearestVehicle(craftBody, state.carrierBody)
        state.targetScanRemain = 0.25
    end
    if state.targetBody == nil or state.targetBody == 0 or targetCenter == nil then return end

    local muzzle = _displayCraftResolveMuzzle(state.shape)
    if muzzle == nil then return end
    local aim = VecSub(targetCenter, muzzle)
    local length = VecLength(aim)
    if length < 0.001 then return end
    local direction = VecScale(aim, 1.0 / length)

    QueryRequire("physical")
    QueryRejectBody(craftBody)
    if state.carrierBody ~= nil and state.carrierBody ~= 0 then
        QueryRejectBody(state.carrierBody)
    end
    local hit, distance, _, hitShape = QueryRaycast(muzzle, direction, length + 2.0, 0.05)
    local hitBody = hit and hitShape ~= nil and hitShape ~= 0 and GetShapeBody(hitShape) or 0
    if hitBody == craftBody or hitBody == state.carrierBody then
        hit, hitBody, distance = false, 0, length
    end
    local endpoint = VecAdd(muzzle, VecScale(direction, hit and distance or length))

    if #state.beams >= 20 then table.remove(state.beams, 1) end
    table.insert(state.beams, {
        startPos = muzzle,
        endPos = endpoint,
        hitTarget = hitBody == state.targetBody,
        life = 0.28,
        maxLife = 0.28,
    })
end

function client.tick(dt)
    local state = client.displayCraftEngineFx
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    state.age = state.age + frameDt
    state.particleAccumulator = state.particleAccumulator + frameDt
    while state.particleAccumulator >= 0.04 do
        state.particleAccumulator = state.particleAccumulator - 0.04
        local pulse = 0.94 + 0.06 * math.sin(state.age * 24.0)
        for index = 1, #state.engines do
            _displayCraftSpawnExhaust(
                state.engines[index],
                pulse
            )
        end
    end
    state.targetScanRemain = state.targetScanRemain - frameDt
    state.fireAccumulator = state.fireAccumulator + frameDt
    while state.fireAccumulator >= 0.16 do
        state.fireAccumulator = state.fireAccumulator - 0.16
        _displayCraftSpawnVehicleBeam()
    end
    for index = #state.beams, 1, -1 do
        local beam = state.beams[index]
        beam.life = beam.life - frameDt
        if beam.life <= 0.0 then table.remove(state.beams, index) end
    end
end

function client.render()
    local state = client.displayCraftEngineFx
    if state.sprite == nil or state.sprite == 0 then return end

    local pulse = 0.98
        + 0.035 * math.sin(state.age * 19.0)
        + 0.020 * math.sin(state.age * 41.0)
    for index = 1, #state.engines do
        local engineTransform = state.engines[index]
        local rear = _displayCraftNormalize(
            TransformToParentVec(engineTransform, Vec(0, 0, 1)),
            Vec(0, 0, 1)
        )
        local up = _displayCraftNormalize(
            TransformToParentVec(engineTransform, Vec(0, 1, 0)),
            Vec(0, 1, 0)
        )
        local outerLength = 1.20 * pulse
        local coreLength = 0.72 * pulse
        local outerCenter = VecAdd(
            engineTransform.pos,
            VecScale(rear, outerLength * 0.5)
        )
        local coreCenter = VecAdd(
            engineTransform.pos,
            VecScale(rear, coreLength * 0.5)
        )

        DrawSprite(
            state.sprite,
            Transform(outerCenter, QuatAlignXZ(rear, up)),
            outerLength,
            0.26,
            0.05,
            0.42,
            1.45,
            0.62,
            true,
            true,
            false
        )
        DrawSprite(
            state.sprite,
            Transform(coreCenter, QuatAlignXZ(rear, up)),
            coreLength,
            0.085,
            2.4,
            2.8,
            3.0,
            0.94,
            true,
            true,
            false
        )
        PointLight(engineTransform.pos, 0.12, 0.52, 1.0, 0.7)
    end

    for index = 1, #state.beams do
        local beam = state.beams[index]
        local vector = VecSub(beam.endPos, beam.startPos)
        local length = VecLength(vector)
        if length > 0.001 then
            local direction = _displayCraftNormalize(vector, Vec(0, 0, -1))
            local center = VecAdd(beam.startPos, VecScale(vector, 0.5))
            local cameraDirection = _displayCraftNormalize(
                VecSub(GetCameraTransform().pos, center),
                Vec(0, 1, 0)
            )
            local alpha = math.max(0.0, beam.life / beam.maxLife)
            local beamTransform = Transform(center, QuatAlignXZ(direction, cameraDirection))
            local outerR, outerG, outerB = beam.hitTarget and 1.0 or 0.08, beam.hitTarget and 0.36 or 0.52, beam.hitTarget and 0.02 or 1.0
            local coreR, coreG, coreB = beam.hitTarget and 3.0 or 0.72, beam.hitTarget and 1.6 or 2.4, beam.hitTarget and 0.30 or 3.0
            DrawSprite(state.sprite, beamTransform, length, 0.24, outerR, outerG, outerB, alpha * 0.72, true, true, false)
            DrawSprite(state.sprite, beamTransform, length, 0.070, coreR, coreG, coreB, alpha, true, true, false)
            if beam.hitTarget then
                local impactTransform = Transform(beam.endPos, QuatLookAt(beam.endPos, GetCameraTransform().pos))
                DrawSprite(state.sprite, impactTransform, 0.66, 0.66, 3.0, 0.68, 0.12, alpha, true, true, false)
                PointLight(beam.endPos, 1.0, 0.36, 0.05, 2.4 * alpha)
            end
        end
    end
end
