-- Synthetic/Preview adapter for Host contract tests and editor previews.
-- It never calls Teardown APIs and never owns movement, damage or weapon fire.

cm2SyntheticWorldAdapterV1 = cm2SyntheticWorldAdapterV1 or {}
local synthetic = cm2SyntheticWorldAdapterV1

synthetic.version = "cm2.world/1"
synthetic.entity = synthetic.entity or {}

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
    instances = {},
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
    state.instances = {}
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

-- Preview/entity fixture boundary.  Keeping this on the versioned World
-- adapter means Preview Suite consumes the same dependency shape as Runtime
-- while remaining engine-free.  It owns only disposable preview DTOs; it does
-- not register ships, apply damage, or publish gameplay events.
function synthetic.entity.spawn(instanceId, generation, definition)
    local state = synthetic.state
    local id = _nonEmpty(instanceId, "")
    local requestedGeneration = math.max(1, math.floor(tonumber(generation) or 0))
    if not state.initialized or state.disposed then return nil, "synthetic world is not active" end
    if id == "" then return nil, "instance id is required" end
    if requestedGeneration ~= state.generation then return nil, "generation mismatch" end
    if type(definition) ~= "table" then return nil, "normalized definition is required" end
    if state.instances[id] ~= nil then return nil, "instance already exists" end
    local instance = {
        id = id,
        generation = requestedGeneration,
        definition = definition,
        disposed = false,
    }
    state.instances[id] = instance
    return instance
end

function synthetic.entity.dispose(instanceId, generation)
    local state = synthetic.state
    local id = _nonEmpty(instanceId, "")
    local requestedGeneration = math.max(1, math.floor(tonumber(generation) or 0))
    local instance = state.instances[id]
    if instance == nil or instance.disposed then return nil, "stale preview instance" end
    if instance.generation ~= requestedGeneration then return nil, "generation mismatch" end
    instance.disposed = true
    state.instances[id] = nil
    return true
end

function synthetic.entity.snapshot()
    local count = 0
    local ids = {}
    for id, _ in pairs(synthetic.state.instances) do
        count = count + 1
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return { protocolVersion = synthetic.version, count = count, ids = ids }
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
        previewInstances = synthetic.entity.snapshot(),
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
        previewInstances = synthetic.entity.snapshot(),
    }
end
