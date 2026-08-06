-- Production tachyon lance beam renderer.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.tachyonBeamFxConfig = client.tachyonBeamFxConfig or {
    enabled = true,
    weaponType = "tachyonLance",
    spritePath = "MOD/gfx/weapons/tachyon_lance/beam_soft.png",
    fallbackLength = 500.0,
    thickness = 12.0,
    color = { 2.5, 2.5, 2.5 },
    glowLayers = {
        {
            thickness = 72.0,
            color = { 0.08, 0.35, 1.00 },
            intensityScale = 0.70,
            alpha = 0.75,
        },
        {
            thickness = 42.0,
            color = { 0.10, 0.65, 1.40 },
            intensityScale = 0.80,
            alpha = 0.85,
        },
        {
            thickness = 24.0,
            color = { 0.30, 1.10, 1.80 },
            intensityScale = 0.85,
            alpha = 0.92,
        },
    },
    alpha = 1.0,
    launchPeakIntensity = 8.0,
    launchAttackDuration = 0.0312,
    launchDecayDuration = 0.96,
    depthTest = true,
    additive = true,
    fogAffected = false,
}

client.tachyonBeamFxState = client.tachyonBeamFxState or {
    sprite = 0,
    lastRenderSeq = -1,
    launchAge = -1.0,
    beamStart = nil,
    beamEnd = nil,
    weaponType = "tachyonLance",
}

local function _tachyonBeamSafeNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then
        return fallback or Vec(0.0, 0.0, -1.0)
    end
    return VecScale(value, 1.0 / length)
end

local function _tachyonBeamDefinition(weaponType)
    return (weaponData or {})[tostring(weaponType or "tachyonLance")] or {}
end

local function _tachyonBeamPalette(weaponType)
    local definition = _tachyonBeamDefinition(weaponType)
    if definition.fxPalette == "particleLance" then
        return {
            { thickness = 72.0, color = { 0.95, 0.03, 0.01 }, intensityScale = 0.70, alpha = 0.75 },
            { thickness = 42.0, color = { 1.40, 0.10, 0.03 }, intensityScale = 0.80, alpha = 0.85 },
            { thickness = 24.0, color = { 1.80, 0.42, 0.12 }, intensityScale = 0.85, alpha = 0.92 },
        }, { 2.5, 0.62, 0.42 }
    end
    return nil, nil
end

local function _tachyonBeamResolveEndpoints(render, shipBody, config)
    local beamStart = client.chargedRayTableToVec(render.firePoint)
    local beamEnd = client.chargedRayTableToVec(render.hitPoint)
    if VecLength(VecSub(beamEnd, beamStart)) >= 0.001 then
        return beamStart, beamEnd
    end

    local shipTransform = GetBodyTransform(shipBody)
    beamStart = TransformToParentPoint(shipTransform, Vec(0.0, 0.0, -4.0))
    local direction = _tachyonBeamSafeNormalize(
        TransformToParentVec(shipTransform, Vec(0.0, 0.0, -1.0)),
        Vec(0.0, 0.0, -1.0)
    )
    beamEnd = VecAdd(beamStart, VecScale(direction, math.max(0.01, tonumber(config.fallbackLength) or 500.0)))
    return beamStart, beamEnd
end

local function _tachyonBeamSmoothStep(value)
    local t = math.max(0.0, math.min(1.0, value))
    return t * t * (3.0 - 2.0 * t)
end

local function _tachyonBeamIntensity(config, age)
    if age < 0.0 then return 0.0 end

    local peak = math.max(0.0, tonumber(config.launchPeakIntensity) or 8.0)
    local attack = math.max(0.001, tonumber(config.launchAttackDuration) or 0.0312)
    if age < attack then
        local t = math.max(0.0, math.min(1.0, age / attack))
        return peak * (1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t))
    end

    local decay = math.max(0.001, tonumber(config.launchDecayDuration) or 0.96)
    return peak * (1.0 - _tachyonBeamSmoothStep((age - attack) / decay))
end

function client.tachyonBeamFxInit()
    local config = client.tachyonBeamFxConfig
    local state = client.tachyonBeamFxState
    state.sprite = LoadSprite(config.spritePath or "gfx/laser.png")
    state.lastRenderSeq = -1
    state.launchAge = -1.0
    state.beamStart = nil
    state.beamEnd = nil
    state.weaponType = "tachyonLance"
end

function client.tachyonBeamFxTick(dt)
    local config = client.tachyonBeamFxConfig
    local state = client.tachyonBeamFxState
    if config.enabled ~= true then return end

    local shipBody = client.shipContextGetBody()
    if shipBody ~= 0 and IsHandleValid(shipBody) then
        local render = client.xSlotRenderGetEvent(shipBody)
        if render ~= nil then
            local seq = math.floor(render.seq or -1)
            if seq ~= state.lastRenderSeq then
                state.lastRenderSeq = seq
                local definition = _tachyonBeamDefinition(render.weaponType)
                if render.eventType == "launch_start"
                    and tostring(definition.fxProfile or "") == "tachyonLance" then
                    state.beamStart, state.beamEnd = _tachyonBeamResolveEndpoints(render, shipBody, config)
                    state.launchAge = 0.0
                    state.weaponType = tostring(render.weaponType or "tachyonLance")
                end
            end
        end
    end

    if state.launchAge >= 0.0 then
        state.launchAge = state.launchAge + math.max(0.0, tonumber(dt) or 0.0)
        local totalDuration = math.max(0.0, tonumber(config.launchAttackDuration) or 0.0312)
            + math.max(0.0, tonumber(config.launchDecayDuration) or 0.96)
        if state.launchAge >= totalDuration then
            state.launchAge = -1.0
            state.beamStart = nil
            state.beamEnd = nil
        end
    end
end

function client.tachyonBeamFxRender()
    local config = client.tachyonBeamFxConfig
    local state = client.tachyonBeamFxState
    local sprite = math.floor(state.sprite or 0)
    if config.enabled ~= true or sprite == 0 or state.beamStart == nil or state.beamEnd == nil then return end

    local beamVector = VecSub(state.beamEnd, state.beamStart)
    local beamLength = VecLength(beamVector)
    if beamLength < 0.001 then return end

    local beamDirection = VecScale(beamVector, 1.0 / beamLength)
    local beamCenter = VecLerp(state.beamStart, state.beamEnd, 0.5)
    local cameraFacingAxis = client.chargedRayCameraFacingAxis(beamDirection, beamCenter)
    local beamTransform = Transform(beamCenter, QuatAlignXZ(beamDirection, cameraFacingAxis))
    local intensity = _tachyonBeamIntensity(config, tonumber(state.launchAge) or -1.0)
    if intensity <= 0.0001 then return end

    local palette, paletteCore = _tachyonBeamPalette(state.weaponType)
    local glowLayers = palette or config.glowLayers or {}
    for i = 1, #glowLayers do
        local layer = glowLayers[i] or {}
        local color = layer.color or { 0.2, 0.7, 1.0 }
        DrawSprite(
            sprite,
            beamTransform,
            beamLength,
            math.max(0.01, tonumber(layer.thickness) or 20.0),
            (tonumber(color[1]) or 0.2) * intensity * (tonumber(layer.intensityScale) or 0.25),
            (tonumber(color[2]) or 0.7) * intensity * (tonumber(layer.intensityScale) or 0.25),
            (tonumber(color[3]) or 1.0) * intensity * (tonumber(layer.intensityScale) or 0.25),
            tonumber(layer.alpha) or 0.6,
            config.depthTest ~= false,
            config.additive ~= false,
            config.fogAffected == true
        )
    end

    local coreColor = paletteCore or config.color or { 2.5, 2.5, 2.5 }
    DrawSprite(
        sprite,
        beamTransform,
        beamLength,
        math.max(0.01, tonumber(config.thickness) or 12.0),
        (tonumber(coreColor[1]) or 2.5) * intensity,
        (tonumber(coreColor[2]) or 2.5) * intensity,
        (tonumber(coreColor[3]) or 2.5) * intensity,
        tonumber(config.alpha) or 1.0,
        config.depthTest ~= false,
        config.additive ~= false,
        config.fogAffected == true
    )
end
