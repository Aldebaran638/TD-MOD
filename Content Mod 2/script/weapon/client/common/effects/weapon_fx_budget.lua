---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.weaponFxBudgetState = client.weaponFxBudgetState or {
    particleTokens = 2400.0,
    particlesThisFrame = 0,
    pointLightsThisFrame = 0,
    spritesThisFrame = 0,
    linesThisFrame = 0,
    activeMuzzles = 0,
    activeImpacts = 0,
    activeBeams = 0,
}

client.weaponFxBudgetConfig = client.weaponFxBudgetConfig or {
    particleRefillPerSecond = 2400.0,
    particleCapacity = 2400.0,
    ambientReserve = 600.0,
    normalReserve = 240.0,
    criticalParticleOverdraft = 240.0,
    maxParticlesSpawnedPerFrame = 280,
    maxPointLightsPerFrame = 28,
    maxSpritesPerFrame = 512,
    criticalSpriteReserve = 24,
    criticalPointLightReserve = 2,
    maxLinesPerFrame = 384,
    maxActiveMuzzles = 128,
    maxActiveImpacts = 128,
    maxActiveBeams = 96,
}

function client.weaponFxBudgetBeginFrame(dt)
    local state = client.weaponFxBudgetState
    local cfg = client.weaponFxBudgetConfig
    state.particleTokens = math.min(
        cfg.particleCapacity,
        (tonumber(state.particleTokens) or cfg.particleCapacity)
            + math.max(0.0, tonumber(dt) or 0.0) * cfg.particleRefillPerSecond
    )
    state.pointLightsThisFrame = 0
    state.particlesThisFrame = 0
    state.spritesThisFrame = 0
    state.linesThisFrame = 0
end

function client.weaponFxTakeParticles(count, priority)
    local state = client.weaponFxBudgetState
    local cfg = client.weaponFxBudgetConfig
    count = math.max(0.0, tonumber(count) or 0.0)

    if state.particlesThisFrame + count > cfg.maxParticlesSpawnedPerFrame then
        return false
    end

    local minimumRemain = 0.0
    if priority == "ambient" then
        minimumRemain = cfg.ambientReserve
    elseif priority == "normal" then
        minimumRemain = cfg.normalReserve
    elseif priority == "critical" then
        minimumRemain = -cfg.criticalParticleOverdraft
    end

    if state.particleTokens - count < minimumRemain then
        return false
    end
    state.particleTokens = state.particleTokens - count
    state.particlesThisFrame = state.particlesThisFrame + count
    return true
end

function client.weaponFxTakeSprite(count, priority)
    local state = client.weaponFxBudgetState
    local cfg = client.weaponFxBudgetConfig
    count = math.max(1, math.floor(tonumber(count) or 1))
    local limit = cfg.maxSpritesPerFrame
    if priority ~= "critical" then
        limit = math.max(0, limit - math.max(0, cfg.criticalSpriteReserve or 0))
    end
    if state.spritesThisFrame + count > limit then return false end
    state.spritesThisFrame = state.spritesThisFrame + count
    return true
end

function client.weaponFxTakeLine(count)
    local state = client.weaponFxBudgetState
    local cfg = client.weaponFxBudgetConfig
    count = math.max(1, math.floor(tonumber(count) or 1))
    if state.linesThisFrame + count > cfg.maxLinesPerFrame then return false end
    state.linesThisFrame = state.linesThisFrame + count
    return true
end

function client.weaponFxPointLight(position, r, g, b, intensity, maxDistance, priority)
    local state = client.weaponFxBudgetState
    local cfg = client.weaponFxBudgetConfig
    local limit = cfg.maxPointLightsPerFrame
    if priority ~= "critical" then
        limit = math.max(0, limit - math.max(0, cfg.criticalPointLightReserve or 0))
    end
    if state.pointLightsThisFrame >= limit then return false end
    if maxDistance ~= nil and VecLength(VecSub(position, GetCameraTransform().pos)) > maxDistance then return false end
    state.pointLightsThisFrame = state.pointLightsThisFrame + 1
    PointLight(position, r, g, b, intensity)
    return true
end
