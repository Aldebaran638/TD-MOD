---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.hSlotCraftFxState = client.hSlotCraftFxState or {
    crafts = {},
    sprite = 0,
    particleAccumulator = 0.0,
    age = 0.0,
}

local function _hSlotCraftFxNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, 1) end
    return VecScale(value, 1.0 / length)
end

function client.hSlotCraftFxInit()
    local state = client.hSlotCraftFxState
    state.crafts = {}
    state.sprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png")
    state.particleAccumulator = 0.0
    state.age = 0.0
end

function client.registerHSlotCraftFx(bodyId, engineLeft, engineRight)
    local body = math.floor(tonumber(bodyId) or 0)
    if body <= 0 then return end
    client.hSlotCraftFxState.crafts[body] = {
        bodyId = body,
        engines = {
            Vec(-0.70, -0.15, 2.58),
            Vec(0.70, -0.15, 2.58),
        },
    }
    local _ = engineLeft
    _ = engineRight
end

function client.unregisterHSlotCraftFx(bodyId)
    client.hSlotCraftFxState.crafts[math.floor(tonumber(bodyId) or 0)] = nil
end

local function _hSlotCraftFxSpawnParticle(transform)
    local rear = _hSlotCraftFxNormalize(
        TransformToParentVec(transform, Vec(0, 0, 1)),
        Vec(0, 0, 1)
    )
    ParticleReset()
    ParticleType("plain")
    ParticleColor(0.72, 1.00, 1.00, 0.02, 0.18, 0.92)
    ParticleRadius(0.095, 0.012, "easeout")
    ParticleAlpha(0.88, 0.0, "easeout")
    ParticleGravity(0.0)
    ParticleDrag(0.08)
    ParticleEmissive(24.0, 0.0)
    ParticleStretch(1.7, 0.2, "easeout")
    ParticleCollide(0.0)
    SpawnParticle(
        VecAdd(transform.pos, VecScale(rear, 0.06)),
        VecAdd(
            VecScale(rear, 5.6 + math.random() * 1.8),
            TransformToParentVec(
                transform,
                Vec(
                    (math.random() - 0.5) * 0.11,
                    (math.random() - 0.5) * 0.11,
                    0
                )
            )
        ),
        0.20 + math.random() * 0.08
    )
end

function client.hSlotCraftFxTick(dt)
    local state = client.hSlotCraftFxState
    local frameDt = math.max(0.0, tonumber(dt) or 0.0)
    state.age = state.age + frameDt
    state.particleAccumulator = state.particleAccumulator + frameDt
    local spawnParticles = state.particleAccumulator >= 0.04
    if spawnParticles then
        state.particleAccumulator = state.particleAccumulator % 0.04
    end

    for bodyId, craft in pairs(state.crafts) do
        if not IsHandleValid(bodyId) then
            state.crafts[bodyId] = nil
        elseif spawnParticles then
            local bodyTransform = GetBodyTransform(bodyId)
            for index = 1, #craft.engines do
                _hSlotCraftFxSpawnParticle(Transform(
                    TransformToParentPoint(
                        bodyTransform,
                        craft.engines[index]
                    ),
                    bodyTransform.rot
                ))
            end
        end
    end
end

function client.hSlotCraftFxRender()
    local state = client.hSlotCraftFxState
    if state.sprite == nil or state.sprite == 0 then return end
    local pulse = 0.98
        + 0.035 * math.sin(state.age * 19.0)
        + 0.020 * math.sin(state.age * 41.0)

    for _, craft in pairs(state.crafts) do
        if IsHandleValid(craft.bodyId) then
            local bodyTransform = GetBodyTransform(craft.bodyId)
            for index = 1, #craft.engines do
                local transform = Transform(
                    TransformToParentPoint(
                        bodyTransform,
                        craft.engines[index]
                    ),
                    bodyTransform.rot
                )
                local rear = _hSlotCraftFxNormalize(
                    TransformToParentVec(transform, Vec(0, 0, 1)),
                    Vec(0, 0, 1)
                )
                local up = _hSlotCraftFxNormalize(
                    TransformToParentVec(transform, Vec(0, 1, 0)),
                    Vec(0, 1, 0)
                )
                local outerLength = 1.20 * pulse
                local coreLength = 0.72 * pulse
                DrawSprite(
                    state.sprite,
                    Transform(
                        VecAdd(transform.pos, VecScale(rear, outerLength * 0.5)),
                        QuatAlignXZ(rear, up)
                    ),
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
                    Transform(
                        VecAdd(transform.pos, VecScale(rear, coreLength * 0.5)),
                        QuatAlignXZ(rear, up)
                    ),
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
                PointLight(transform.pos, 0.12, 0.52, 1.0, 0.7)
            end
        end
    end
end
