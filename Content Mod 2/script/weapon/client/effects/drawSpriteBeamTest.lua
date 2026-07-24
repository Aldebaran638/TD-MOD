---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

-- 独立的固定前向 DrawSprite 光柱测试系统。
-- 仅复用快子光矛的 launch_start 触发事件，不读取正式系统的发射点、命中点或光束几何。
-- 后续统一到正式渲染时，可直接关闭 enabled 并移除本模块的 include/tick/render 调用。
-- 颜色分量可以大于 1.0，用作亮度倍增。
client.drawSpriteBeamTestConfig = client.drawSpriteBeamTestConfig or {
    enabled = true,
    spritePath = "MOD/gfx/weapon/effects/tachyon_beam_soft.png",
    localStartOffset = { x = 0.0, y = 0.0, z = -4.0 },
    localDirection = { x = 0.0, y = 0.0, z = -1.0 },
    length = 250.0,
    -- PNG 上下留有大面积黑边；additive 模式下黑色不可见，实际光束明显细于此高度。
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
    idleIntensity = 0.0,
    launchPeakIntensity = 8.0,
    launchAttackDuration = 0.0312,
    launchDecayDuration = 0.96,

    depthTest = true,
    additive = true,
    fogAffected = false,
}

client.drawSpriteBeamTestState = client.drawSpriteBeamTestState or {
    sprite = 0,
    lastRenderSeq = -1,
    launchPulseAge = -1.0,
}

local function _drawSpriteBeamTestSafeNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then
        return fallback or Vec(0.0, 0.0, -1.0)
    end
    return VecScale(value, 1.0 / length)
end

local function _drawSpriteBeamTestTableToVec(value, fallback)
    local source = value or {}
    local default = fallback or Vec(0.0, 0.0, 0.0)
    return Vec(
        tonumber(source.x) or default[1] or 0.0,
        tonumber(source.y) or default[2] or 0.0,
        tonumber(source.z) or default[3] or 0.0
    )
end

local function _drawSpriteBeamTestCameraFacingAxis(beamAxis, beamCenter)
    local cameraPos = GetCameraTransform().pos
    local toCamera = VecSub(cameraPos, beamCenter)
    local projected = VecSub(toCamera, VecScale(beamAxis, VecDot(toCamera, beamAxis)))

    if VecLength(projected) < 0.0001 then
        local fallback = Vec(0.0, 1.0, 0.0)
        projected = VecSub(fallback, VecScale(beamAxis, VecDot(fallback, beamAxis)))
    end
    if VecLength(projected) < 0.0001 then
        local fallback = Vec(1.0, 0.0, 0.0)
        projected = VecSub(fallback, VecScale(beamAxis, VecDot(fallback, beamAxis)))
    end

    return _drawSpriteBeamTestSafeNormalize(projected, Vec(0.0, 0.0, 1.0))
end

function client.drawSpriteBeamTestInit()
    local config = client.drawSpriteBeamTestConfig
    local state = client.drawSpriteBeamTestState
    state.sprite = LoadSprite(config.spritePath or "gfx/laser.png")
    state.lastRenderSeq = -1
    state.launchPulseAge = -1.0
end

function client.drawSpriteBeamTestTick(dt)
    local config = client.drawSpriteBeamTestConfig
    local state = client.drawSpriteBeamTestState
    if config.enabled ~= true then return end

    local shipBody = math.floor(client.shipBody or 0)
    if shipBody ~= 0 and IsHandleValid(shipBody) then
        local render = client.xSlotRenderGetEvent(shipBody)
        if render ~= nil then
            local seq = math.floor(render.seq or -1)
            if seq ~= state.lastRenderSeq then
                state.lastRenderSeq = seq
                if render.eventType == "launch_start"
                    and tostring(render.weaponType or "tachyonLance") == "tachyonLance" then
                    state.launchPulseAge = 0.0
                end
            end
        end
    end

    if state.launchPulseAge >= 0.0 then
        state.launchPulseAge = state.launchPulseAge + math.max(0.0, tonumber(dt) or 0.0)
        local totalDuration = math.max(0.0, tonumber(config.launchAttackDuration) or 0.0312)
            + math.max(0.0, tonumber(config.launchDecayDuration) or 0.96)
        if state.launchPulseAge >= totalDuration then
            state.launchPulseAge = -1.0
        end
    end
end

local function _drawSpriteBeamTestSmoothStep(t)
    local clamped = math.max(0.0, math.min(1.0, t))
    return clamped * clamped * (3.0 - 2.0 * clamped)
end

local function _drawSpriteBeamTestGetIntensity(config, state)
    local idle = math.max(0.0, tonumber(config.idleIntensity) or 1.0)
    local peak = math.max(idle, tonumber(config.launchPeakIntensity) or 8.0)
    local age = tonumber(state.launchPulseAge) or -1.0
    if age < 0.0 then return idle end

    local attack = math.max(0.001, tonumber(config.launchAttackDuration) or 0.0312)
    if age < attack then
        -- 三次 ease-out：几乎立刻冲亮，但不会在单帧内生硬跳变。
        local t = math.max(0.0, math.min(1.0, age / attack))
        local fastRise = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
        return idle + (peak - idle) * fastRise
    end

    local decay = math.max(0.001, tonumber(config.launchDecayDuration) or 0.96)
    local fade = _drawSpriteBeamTestSmoothStep((age - attack) / decay)
    return peak + (idle - peak) * fade
end

function client.drawSpriteBeamTestRender()
    local config = client.drawSpriteBeamTestConfig
    if config.enabled ~= true then return end

    local state = client.drawSpriteBeamTestState or {}
    local sprite = math.floor(state.sprite or 0)
    local shipBody = math.floor(client.shipBody or 0)
    if sprite == 0 or shipBody == 0 or not IsHandleValid(shipBody) then return end

    local shipTransform = GetBodyTransform(shipBody)
    local localStart = _drawSpriteBeamTestTableToVec(config.localStartOffset, Vec(0.0, 0.0, -6.0))
    local localDirection = _drawSpriteBeamTestTableToVec(config.localDirection, Vec(0.0, 0.0, -1.0))
    local beamStart = TransformToParentPoint(shipTransform, localStart)
    local beamDirection = _drawSpriteBeamTestSafeNormalize(
        TransformToParentVec(shipTransform, localDirection),
        TransformToParentVec(shipTransform, Vec(0.0, 0.0, -1.0))
    )
    local beamLength = math.max(0.01, tonumber(config.length) or 250.0)
    local beamEnd = VecAdd(beamStart, VecScale(beamDirection, beamLength))
    local beamCenter = VecLerp(beamStart, beamEnd, 0.5)
    local cameraFacingAxis = _drawSpriteBeamTestCameraFacingAxis(beamDirection, beamCenter)
    local beamTransform = Transform(beamCenter, QuatAlignXZ(beamDirection, cameraFacingAxis))
    local color = config.color or { 4.0, 8.0, 12.0 }
    local intensity = _drawSpriteBeamTestGetIntensity(config, state)

    if sprite ~= 0 and intensity > 0.0001 then
        local glowLayers = config.glowLayers or {}
        for i = 1, #glowLayers do
            local layer = glowLayers[i] or {}
            local layerColor = layer.color or { 0.2, 0.7, 1.0 }
            DrawSprite(
                sprite,
                beamTransform,
                beamLength,
                math.max(0.01, tonumber(layer.thickness) or 20.0),
                (tonumber(layerColor[1]) or 0.2) * intensity * (tonumber(layer.intensityScale) or 0.25),
                (tonumber(layerColor[2]) or 0.7) * intensity * (tonumber(layer.intensityScale) or 0.25),
                (tonumber(layerColor[3]) or 1.0) * intensity * (tonumber(layer.intensityScale) or 0.25),
                tonumber(layer.alpha) or 0.6,
                config.depthTest ~= false,
                config.additive ~= false,
                config.fogAffected == true
            )
        end

        DrawSprite(
            sprite,
            beamTransform,
            beamLength,
            math.max(0.01, tonumber(config.thickness) or 3.0),
            (tonumber(color[1]) or 4.0) * intensity,
            (tonumber(color[2]) or 8.0) * intensity,
            (tonumber(color[3]) or 12.0) * intensity,
            tonumber(config.alpha) or 1.0,
            config.depthTest ~= false,
            config.additive ~= false,
            config.fogAffected == true
        )
    end
end
