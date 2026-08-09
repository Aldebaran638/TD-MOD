---@diagnostic disable: undefined-global

-- Server world effects are deliberately rate-limited independently of weapon
-- cooldowns, so multiple Titans cannot turn a stalled frame into a destruction burst.
server = server or {}
server.weaponEffectBudgetState = server.weaponEffectBudgetState or { tokens = 8.0, lastTime = 0.0 }

function server.weaponEffectBudgetTakeWorld(cost)
    local state = server.weaponEffectBudgetState
    local now = GetTime ~= nil and GetTime() or 0.0
    local elapsed = math.max(0.0, now - (tonumber(state.lastTime) or now))
    state.lastTime = now
    state.tokens = math.min(8.0, (tonumber(state.tokens) or 8.0) + elapsed * 2.0)
    local requested = math.max(0.0, tonumber(cost) or 1.0)
    if state.tokens < requested then return false end
    state.tokens = state.tokens - requested
    return true
end
