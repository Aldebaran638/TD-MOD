-- Fixed-capacity dense stores for high-churn world entities.
-- Registry remains an observation/snapshot boundary; hot updates use O(1)
-- active/free-list operations and generation-bearing handles.

cm2DenseEntityStoreV1 = cm2DenseEntityStoreV1 or {}
local dense = cm2DenseEntityStoreV1

dense.protocolVersion = "cm2.world.dense-store/1"
dense.defaultCapacities = {
    projectile = 96,
    craft = 24,
    effect = 128,
    joint = 64,
}

local function _newStore(kind, capacity)
    local store = {
        kind = kind,
        capacity = math.max(1, math.floor(tonumber(capacity) or 1)),
        slots = {},
        generations = {},
        free = {},
        activeIndices = {},
        activePosition = {},
        byEntityId = {},
        byBodyId = {},
        metrics = {
            registers = 0,
            removes = 0,
            reuses = 0,
            staleRejected = 0,
            duplicateRejected = 0,
            capacityRejected = 0,
            denseIterations = 0,
            legacyTableIterations = 0,
            memorySamples = 0,
            gcSamples = 0,
            maxActive = 0,
        },
    }
    for index = store.capacity, 1, -1 do
        store.generations[index] = 1
        store.free[#store.free + 1] = index
    end
    return store
end

local function _newState()
    return {
        initialized = false,
        generation = 0,
        stores = {},
        metrics = {
            staleHandleRejected = 0,
            totalRegisters = 0,
            totalRemoves = 0,
            totalReuses = 0,
            totalDenseIterations = 0,
            totalLegacyTableIterations = 0,
            memorySamples = 0,
            gcSamples = 0,
        },
    }
end

dense.state = dense.state or _newState()

local function _safeString(value)
    if type(value) ~= "string" or value == "" then return "" end
    return value
end

local function _clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] ~= nil then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do copy[key] = _clone(child, seen) end
    return copy
end

local function _store(kind)
    return dense.state.stores[_safeString(kind)]
end

local function _validHandle(store, handle)
    if type(handle) ~= "table" then return false end
    local index = math.floor(tonumber(handle.index) or 0)
    local generation = math.floor(tonumber(handle.generation) or 0)
    if index < 1 or index > store.capacity then return false end
    if store.generations[index] ~= generation then return false end
    if store.slots[index] == nil then return false end
    return true
end

function dense.serverInit(generation, capacities)
    local state = dense.state
    if state.initialized then return dense.getDiagnostics() end
    state.initialized = true
    state.generation = math.max(1, math.floor(tonumber(generation) or 1))
    state.stores = {}
    state.metrics = {
        staleHandleRejected = 0,
        totalRegisters = 0,
        totalRemoves = 0,
        totalReuses = 0,
        totalDenseIterations = 0,
        totalLegacyTableIterations = 0,
        memorySamples = 0,
        gcSamples = 0,
    }
    for kind, defaultCapacity in pairs(dense.defaultCapacities) do
        local capacity = defaultCapacity
        if type(capacities) == "table" and capacities[kind] ~= nil then capacity = capacities[kind] end
        state.stores[kind] = _newStore(kind, capacity)
    end
    return dense.getDiagnostics()
end

function dense.register(kind, entityId, bodyId, payload)
    local state = dense.state
    local store = _store(kind)
    local id = _safeString(entityId)
    local body = _safeString(bodyId)
    if not state.initialized or store == nil then return nil, "dense store is not initialized" end
    if id == "" then return nil, "entityId is required" end
    if store.byEntityId[id] ~= nil then store.metrics.duplicateRejected = store.metrics.duplicateRejected + 1; return nil, "duplicate entityId" end
    if body ~= "" and store.byBodyId[body] ~= nil then store.metrics.duplicateRejected = store.metrics.duplicateRejected + 1; return nil, "duplicate bodyId" end
    if #store.free == 0 then store.metrics.capacityRejected = store.metrics.capacityRejected + 1; return nil, "dense store capacity exhausted" end
    local index = table.remove(store.free)
    local generation = store.generations[index]
    local slot = {
        kind = store.kind,
        entityId = id,
        bodyId = body,
        index = index,
        generation = generation,
        payload = _clone(payload or {}),
    }
    store.slots[index] = slot
    store.byEntityId[id] = index
    if body ~= "" then store.byBodyId[body] = index end
    store.activeIndices[#store.activeIndices + 1] = index
    store.activePosition[index] = #store.activeIndices
    store.metrics.registers = store.metrics.registers + 1
    if generation > 1 then store.metrics.reuses = store.metrics.reuses + 1; state.metrics.totalReuses = state.metrics.totalReuses + 1 end
    state.metrics.totalRegisters = state.metrics.totalRegisters + 1
    if #store.activeIndices > store.metrics.maxActive then store.metrics.maxActive = #store.activeIndices end
    return { kind = store.kind, index = index, generation = generation, entityId = id }
end

function dense.get(kind, handle)
    local state = dense.state
    local store = _store(kind)
    if not state.initialized or store == nil then return nil, "dense store is not initialized" end
    if not _validHandle(store, handle) then store.metrics.staleRejected = store.metrics.staleRejected + 1; state.metrics.staleHandleRejected = state.metrics.staleHandleRejected + 1; return nil, "stale dense handle" end
    return _clone(store.slots[math.floor(tonumber(handle.index) or 0)])
end

function dense.remove(kind, handle)
    local state = dense.state
    local store = _store(kind)
    if not state.initialized or store == nil then return false, "dense store is not initialized" end
    if not _validHandle(store, handle) then store.metrics.staleRejected = store.metrics.staleRejected + 1; state.metrics.staleHandleRejected = state.metrics.staleHandleRejected + 1; return false, "stale dense handle" end
    local index = math.floor(tonumber(handle.index) or 0)
    local slot = store.slots[index]
    local position = store.activePosition[index]
    local lastPosition = #store.activeIndices
    local lastIndex = store.activeIndices[lastPosition]
    if position ~= lastPosition then
        store.activeIndices[position] = lastIndex
        store.activePosition[lastIndex] = position
    end
    store.activeIndices[lastPosition] = nil
    store.activePosition[index] = nil
    store.slots[index] = nil
    store.byEntityId[slot.entityId] = nil
    if slot.bodyId ~= "" then store.byBodyId[slot.bodyId] = nil end
    store.generations[index] = store.generations[index] + 1
    store.free[#store.free + 1] = index
    store.metrics.removes = store.metrics.removes + 1
    state.metrics.totalRemoves = state.metrics.totalRemoves + 1
    return true
end

function dense.iterate(kind)
    local state = dense.state
    local store = _store(kind)
    if not state.initialized or store == nil then return {}, "dense store is not initialized" end
    local result = {}
    for position, index in ipairs(store.activeIndices) do
        result[position] = _clone(store.slots[index])
    end
    store.metrics.denseIterations = store.metrics.denseIterations + 1
    state.metrics.totalDenseIterations = state.metrics.totalDenseIterations + 1
    return result
end

function dense.snapshot(kind)
    local entries, errorText = dense.iterate(kind)
    if errorText ~= nil then return nil, errorText end
    return {
        protocolVersion = dense.protocolVersion,
        worldGeneration = dense.state.generation,
        kind = kind,
        entries = entries,
    }
end

function dense.recordComparison(kind, legacyIterations, denseIterations, memoryBytes, gcBytes)
    local store = _store(kind)
    if store == nil then return false, "unknown dense store" end
    store.metrics.legacyTableIterations = store.metrics.legacyTableIterations + math.max(0, math.floor(tonumber(legacyIterations) or 0))
    local state = dense.state
    state.metrics.totalLegacyTableIterations = state.metrics.totalLegacyTableIterations + math.max(0, math.floor(tonumber(legacyIterations) or 0))
    store.metrics.memorySamples = store.metrics.memorySamples + math.max(0, math.floor(tonumber(memoryBytes) or 0))
    store.metrics.gcSamples = store.metrics.gcSamples + math.max(0, math.floor(tonumber(gcBytes) or 0))
    state.metrics.memorySamples = state.metrics.memorySamples + 1
    state.metrics.gcSamples = state.metrics.gcSamples + 1
    return true
end

function dense.tick(dt)
    if not dense.state.initialized then return false end
    return tonumber(dt) ~= nil
end

function dense.getDiagnostics()
    local state = dense.state
    local stores = {}
    for kind, store in pairs(state.stores) do
        stores[kind] = {
            capacity = store.capacity,
            active = #store.activeIndices,
            free = #store.free,
            registers = store.metrics.registers,
            removes = store.metrics.removes,
            reuses = store.metrics.reuses,
            staleRejected = store.metrics.staleRejected,
            duplicateRejected = store.metrics.duplicateRejected,
            capacityRejected = store.metrics.capacityRejected,
            denseIterations = store.metrics.denseIterations,
            legacyTableIterations = store.metrics.legacyTableIterations,
            memorySamples = store.metrics.memorySamples,
            gcSamples = store.metrics.gcSamples,
            maxActive = store.metrics.maxActive,
        }
    end
    return {
        protocolVersion = dense.protocolVersion,
        initialized = state.initialized,
        generation = state.generation,
        staleHandleRejected = state.metrics.staleHandleRejected,
        totalRegisters = state.metrics.totalRegisters,
        totalRemoves = state.metrics.totalRemoves,
        totalReuses = state.metrics.totalReuses,
        totalDenseIterations = state.metrics.totalDenseIterations,
        totalLegacyTableIterations = state.metrics.totalLegacyTableIterations,
        memorySamples = state.metrics.memorySamples,
        gcSamples = state.metrics.gcSamples,
        stores = stores,
    }
end
