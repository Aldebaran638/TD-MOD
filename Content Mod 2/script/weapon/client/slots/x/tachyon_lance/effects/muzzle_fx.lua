-- Tachyon lance muzzle glare sprite.
---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.tachyonMuzzleFxConfig = client.tachyonMuzzleFxConfig or {
    enabled = true,
    weaponType = "tachyonLance",

    glareSpritePath = "gfx/glare.png",
    localMuzzleOffset = { x = 0.0, y = 0.0, z = -4.0 },

    attackDuration = 0.0312,
    decayDuration = 0.96,
    totalDuration = 0.9912,

    glareColor = { 0.55, 0.88, 1.20 },
    glareSizeMin = 2.2,
    glareSizeMax = 5.8,
    glareAlpha = 0.95,
}

client.tachyonMuzzleFxState = client.tachyonMuzzleFxState or {
    glareSprite = 0,
    lastRenderSeq = -1,
    age = -1.0,
    intensity = 0.0,
}

local function _tachyonMuzzleSmoothStep(value)
    local t = math.max(0.0, math.min(1.0, value))
    return t * t * (3.0 - 2.0 * t)
end

local function _tachyonMuzzleTableToVec(value)
    local source = value or {}
    return Vec(
        tonumber(source.x) or 0.0,
        tonumber(source.y) or 0.0,
        tonumber(source.z) or 0.0
    )
end

local function _tachyonMuzzleEnvelope(config, age)
    if age < 0.0 then return 0.0 end

    local attack = math.max(0.001, tonumber(config.attackDuration) or 0.0312)

    if age < attack then
        local t = math.max(0.0, math.min(1.0, age / attack))
        return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
    end

    local decay = math.max(0.001, tonumber(config.decayDuration) or 0.96)
    return 1.0 - _tachyonMuzzleSmoothStep((age - attack) / decay)
end

function client.tachyonMuzzleFxInit()
    local config = client.tachyonMuzzleFxConfig
    local state = client.tachyonMuzzleFxState

    state.glareSprite = LoadSprite(config.glareSpritePath or "gfx/glare.png")
    state.lastRenderSeq = -1
    state.age = -1.0
    state.intensity = 0.0

end

function client.tachyonMuzzleFxTick(dt)
    local config = client.tachyonMuzzleFxConfig
    local state = client.tachyonMuzzleFxState
    if config.enabled ~= true then
        state.age = -1.0
        state.intensity = 0.0
        return
    end

    local shipBody = client.shipContextGetBody()
    if shipBody ~= 0 and IsHandleValid(shipBody) then
        local render = client.xSlotRenderGetEvent(shipBody)
        if render ~= nil then
            local seq = math.floor(render.seq or -1)
            if seq ~= state.lastRenderSeq then
                state.lastRenderSeq = seq
                if render.eventType == "launch_start"
                    and tostring(render.weaponType or "") == tostring(config.weaponType or "tachyonLance") then
                    state.age = 0.0
                end
            end
        end
    end

    if state.age >= 0.0 then
        state.age = state.age + math.max(0.0, tonumber(dt) or 0.0)
        if state.age >= math.max(0.0, tonumber(config.totalDuration) or 0.9912) then
            state.age = -1.0
        end
    end

    state.intensity = _tachyonMuzzleEnvelope(config, state.age)
end

function client.tachyonMuzzleFxRender()
    local config = client.tachyonMuzzleFxConfig
    local state = client.tachyonMuzzleFxState
    local intensity = math.max(0.0, tonumber(state.intensity) or 0.0)
    local sprite = math.floor(state.glareSprite or 0)
    local shipBody = client.shipContextGetBody()
    if config.enabled ~= true or intensity <= 0.0001 or sprite == 0 then return end
    if shipBody == 0 or not IsHandleValid(shipBody) then return end

    local shipTransform = GetBodyTransform(shipBody)
    local muzzlePos = TransformToParentPoint(shipTransform, _tachyonMuzzleTableToVec(config.localMuzzleOffset))
    local cameraPos = GetCameraTransform().pos
    local spriteTransform = Transform(muzzlePos, QuatLookAt(muzzlePos, cameraPos))
    local minSize = math.max(0.01, tonumber(config.glareSizeMin) or 2.2)
    local maxSize = math.max(minSize, tonumber(config.glareSizeMax) or 5.8)
    local size = minSize + (maxSize - minSize) * intensity
    local color = config.glareColor or { 0.55, 0.88, 1.20 }

    DrawSprite(
        sprite,
        spriteTransform,
        size,
        size,
        (tonumber(color[1]) or 0.55) * intensity,
        (tonumber(color[2]) or 0.88) * intensity,
        (tonumber(color[3]) or 1.20) * intensity,
        tonumber(config.glareAlpha) or 0.95,
        true,
        true,
        false
    )
end
