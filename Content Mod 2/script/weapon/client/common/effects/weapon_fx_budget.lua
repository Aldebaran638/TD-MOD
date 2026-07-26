---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

client.weaponFxBudgetState = client.weaponFxBudgetState or {
    particleTokens = 720.0,
    pointLightsThisFrame = 0,
    spritesThisFrame = 0,
    linesThisFrame = 0,
    activeMuzzles = 0,
    activeImpacts = 0,
    activeBeams = 0,
}

client.weaponFxBudgetConfig = client.weaponFxBudgetConfig or {
    particleRefillPerSecond = 4800.0,
    particleCapacity = 720.0,
    criticalParticleOverdraft = 192.0,
    maxPointLightsPerFrame = 12,
    maxSpritesPerFrame = 192,
    maxLinesPerFrame = 192,
    maxActiveMuzzles = 48,
    maxActiveImpacts = 64,
    maxActiveBeams = 64,
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
    state.spritesThisFrame = 0
    state.linesThisFrame = 0
end

function client.weaponFxTakeParticles(count, priority)
    local state = client.weaponFxBudgetState
    local cfg = client.weaponFxBudgetConfig
    count = math.max(0.0, tonumber(count) or 0.0)

    local minimumRemain = 0.0
    if priority == "ambient" then
        minimumRemain = 48.0
    elseif priority == "critical" then
        minimumRemain = -cfg.criticalParticleOverdraft
    end

    if state.particleTokens - count < minimumRemain then
        return false
    end
    state.particleTokens = state.particleTokens - count
    return true
end

function client.weaponFxTakeSprite(count)
    local state = client.weaponFxBudgetState
    local cfg = client.weaponFxBudgetConfig
    count = math.max(1, math.floor(tonumber(count) or 1))
    if state.spritesThisFrame + count > cfg.maxSpritesPerFrame then return false end
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

function client.weaponFxPointLight(position, r, g, b, intensity, maxDistance)
    local state = client.weaponFxBudgetState
    local cfg = client.weaponFxBudgetConfig
    if state.pointLightsThisFrame >= cfg.maxPointLightsPerFrame then return false end
    if maxDistance ~= nil and VecLength(VecSub(position, GetCameraTransform().pos)) > maxDistance then return false end
    state.pointLightsThisFrame = state.pointLightsThisFrame + 1
    PointLight(position, r, g, b, intensity)
    return true
end
