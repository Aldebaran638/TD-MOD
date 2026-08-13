---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Reusable bounded buffers and integer counters for server hot paths.
-- This is an allocation policy, not a feature switch: callers keep their
-- existing behavior while replacing per-tick scratch tables with stable pools.

cm2HotpathBudgetV1 = cm2HotpathBudgetV1 or {}
local hotpath = cm2HotpathBudgetV1

hotpath.protocolVersion = "cm2.hotpath-budget/1"
hotpath.defaultMaxBuffers = 256
hotpath.defaultMaxCounterKeys = 128

local function _newState()
    return {
        initialized = false,
        generation = 0,
        maxBuffers = hotpath.defaultMaxBuffers,
        maxCounterKeys = hotpath.defaultMaxCounterKeys,
        buffers = {},
        counters = {},
        batches = {},
        metrics = {
            bufferAcquires = 0,
            bufferCreates = 0,
            bufferReuses = 0,
            bufferReleases = 0,
            bufferClears = 0,
            bufferRejects = 0,
            counterWrites = 0,
            counterKeyRejects = 0,
            batchBegins = 0,
            batchEnds = 0,
            batchOperations = 0,
        },
    }
end

hotpath.state = hotpath.state or _newState()

local function _safeString(value)
    if type(value) ~= "string" or value == "" then return "" end
    return value
end

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _clearArray(buffer)
    for index = #buffer, 1, -1 do buffer[index] = nil end
    hotpath.state.metrics.bufferClears = hotpath.state.metrics.bufferClears + 1
end

function hotpath.serverInit(generation, options)
    local state = hotpath.state
    if state.initialized then return hotpath.getDiagnostics() end
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.maxBuffers = math.max(1, math.floor(_safeNumber(resolved.maxBuffers, hotpath.defaultMaxBuffers)))
    state.maxCounterKeys = math.max(1, math.floor(_safeNumber(resolved.maxCounterKeys, hotpath.defaultMaxCounterKeys)))
    state.buffers = {}
    state.counters = {}
    state.batches = {}
    state.metrics = {
        bufferAcquires = 0, bufferCreates = 0, bufferReuses = 0,
        bufferReleases = 0, bufferClears = 0, bufferRejects = 0,
        counterWrites = 0, counterKeyRejects = 0, batchBegins = 0,
        batchEnds = 0, batchOperations = 0,
    }
    return hotpath.getDiagnostics()
end

function hotpath.acquireBuffer(key, capacity)
    local state = hotpath.state
    if not state.initialized then return {} end
    local id = _safeString(key)
    if id == "" then state.metrics.bufferRejects = state.metrics.bufferRejects + 1; return {} end
    local buffer = state.buffers[id]
    if buffer == nil then
        local count = 0
        for _ in pairs(state.buffers) do count = count + 1 end
        if count >= state.maxBuffers then state.metrics.bufferRejects = state.metrics.bufferRejects + 1; return {} end
        buffer = {}
        state.buffers[id] = buffer
        state.metrics.bufferCreates = state.metrics.bufferCreates + 1
    else
        state.metrics.bufferReuses = state.metrics.bufferReuses + 1
    end
    _clearArray(buffer)
    local requested = math.max(0, math.floor(_safeNumber(capacity, 0)))
    buffer.capacity = requested
    state.metrics.bufferAcquires = state.metrics.bufferAcquires + 1
    return buffer
end

function hotpath.releaseBuffer(key)
    local id = _safeString(key)
    local buffer = hotpath.state.buffers[id]
    if buffer == nil then return false end
    _clearArray(buffer)
    hotpath.state.metrics.bufferReleases = hotpath.state.metrics.bufferReleases + 1
    return true
end

function hotpath.record(key, amount)
    local state = hotpath.state
    local id = _safeString(key)
    if id == "" then return false end
    if state.counters[id] == nil then
        local count = 0
        for _ in pairs(state.counters) do count = count + 1 end
        if count >= state.maxCounterKeys then state.metrics.counterKeyRejects = state.metrics.counterKeyRejects + 1; return false end
        state.counters[id] = 0
    end
    state.counters[id] = math.floor(_safeNumber(state.counters[id], 0) + _safeNumber(amount, 1))
    state.metrics.counterWrites = state.metrics.counterWrites + 1
    return true
end

function hotpath.beginBatch(key)
    local id = _safeString(key)
    if id == "" then return false end
    hotpath.state.batches[id] = { operations = 0 }
    hotpath.state.metrics.batchBegins = hotpath.state.metrics.batchBegins + 1
    return true
end

function hotpath.batchOperation(key, count)
    local batch = hotpath.state.batches[_safeString(key)]
    if batch == nil then return false end
    batch.operations = batch.operations + math.max(0, math.floor(_safeNumber(count, 1)))
    hotpath.state.metrics.batchOperations = hotpath.state.metrics.batchOperations + 1
    return true
end

function hotpath.endBatch(key)
    local id = _safeString(key)
    local batch = hotpath.state.batches[id]
    if batch == nil then return nil end
    hotpath.state.batches[id] = nil
    hotpath.state.metrics.batchEnds = hotpath.state.metrics.batchEnds + 1
    return batch.operations
end

function hotpath.getDiagnostics()
    local state = hotpath.state
    local bufferCount = 0
    for _ in pairs(state.buffers) do bufferCount = bufferCount + 1 end
    local counterCount = 0
    for _ in pairs(state.counters) do counterCount = counterCount + 1 end
    local counters = {}
    for key, value in pairs(state.counters) do counters[key] = value end
    return {
        protocolVersion = hotpath.protocolVersion,
        initialized = state.initialized,
        generation = state.generation,
        bufferCount = bufferCount,
        counterCount = counterCount,
        counters = counters,
        bufferAcquires = state.metrics.bufferAcquires,
        bufferCreates = state.metrics.bufferCreates,
        bufferReuses = state.metrics.bufferReuses,
        bufferReleases = state.metrics.bufferReleases,
        bufferClears = state.metrics.bufferClears,
        bufferRejects = state.metrics.bufferRejects,
        counterWrites = state.metrics.counterWrites,
        counterKeyRejects = state.metrics.counterKeyRejects,
        batchBegins = state.metrics.batchBegins,
        batchEnds = state.metrics.batchEnds,
        batchOperations = state.metrics.batchOperations,
    }
end
