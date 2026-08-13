-- Synthetic/Preview adapter for Host contract tests and editor previews.
-- It never calls Teardown APIs and never owns movement, damage or weapon fire.

cm2SyntheticWorldAdapterV1 = cm2SyntheticWorldAdapterV1 or {}
local synthetic = cm2SyntheticWorldAdapterV1

synthetic.state = synthetic.state or {
    initialized = false,
    disposed = false,
    mode = "synthetic",
    identity = "",
    ownerId = "",
    generation = 0,
    tickCount = 0,
    heartbeat = 0,
    capabilities = {},
}

local function _nonEmpty(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback end
    return value
end

local function _capabilities(value)
    local result = {}
    if type(value) ~= "table" then return result end
    for key, enabled in pairs(value) do
        if type(key) == "number" then result[tostring(enabled)] = true else result[tostring(key)] = enabled and true or false end
    end
    return result
end

function synthetic.init(identity, ownerId, capabilities, mode)
    local state = synthetic.state
    state.initialized = true
    state.disposed = false
    state.mode = (mode == "preview") and "preview" or "synthetic"
    state.identity = _nonEmpty(identity, "synthetic-instance")
    state.ownerId = _nonEmpty(ownerId, state.identity)
    state.generation = 1
    state.tickCount = 0
    state.heartbeat = 0
    state.capabilities = _capabilities(capabilities)
    return synthetic.getReport()
end

function synthetic.tick(dt)
    if not synthetic.state.initialized or synthetic.state.disposed then return false end
    synthetic.state.tickCount = synthetic.state.tickCount + 1
    if tonumber(dt) ~= nil and tonumber(dt) > 0 then synthetic.state.heartbeat = synthetic.state.heartbeat + 1 end
    return true
end

function synthetic.dispose(_reason)
    if synthetic.state.disposed then return false end
    synthetic.state.disposed = true
    return true
end

function synthetic.snapshot()
    local state = synthetic.state
    return {
        protocolVersion = "cm2.world/1",
        identity = state.identity,
        ownerId = state.ownerId,
        mode = state.mode,
        generation = state.generation,
        tickCount = state.tickCount,
        heartbeat = state.heartbeat,
        disposed = state.disposed,
    }
end

function synthetic.getReport()
    local state = synthetic.state
    return {
        protocolVersion = "cm2.world/1",
        identity = state.identity,
        ownerId = state.ownerId,
        mode = state.mode,
        generation = state.generation,
        initialized = state.initialized,
        disposed = state.disposed,
        tickCount = state.tickCount,
        heartbeat = state.heartbeat,
        capabilities = state.capabilities,
    }
end
