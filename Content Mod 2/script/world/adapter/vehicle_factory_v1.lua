---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- VehicleFactory v1 is a DTO transaction boundary.  It models graph/body/
-- shape/joint/mount/runtime stages and their rollback without touching engine
-- creation APIs; a later runtime adapter may supply those implementations.

cm2VehicleFactoryV1 = cm2VehicleFactoryV1 or {}
local factory = cm2VehicleFactoryV1

factory.protocolVersion = "cm2.vehicle-factory/1"
factory.stageOrder = { "graph", "body", "shape", "joint", "mount", "runtime" }

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        mode = "legacy",
        maxInstances = 16,
        nextSequence = 0,
        instances = {},
        events = {},
        eventSequence = 0,
        eventCapacity = 64,
        metrics = {
            initCount = 0,
            spawnAttempts = 0,
            spawns = 0,
            spawnRejects = 0,
            stageFailures = 0,
            rollbacks = 0,
            ticks = 0,
            disposes = 0,
            idempotentDisposes = 0,
            activePeak = 0,
            eventsEmitted = 0,
            eventsDropped = 0,
            staleRejects = 0,
            ownerRejects = 0,
        },
    }
end

factory.state = factory.state or _newState()

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback or "" end
    return value
end

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
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

local function _clear(value)
    for key in pairs(value) do value[key] = nil end
end

local function _validFactoryHandle(handle)
    local state = factory.state
    if type(handle) ~= "table" then return false, "factory handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "factory identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "factory owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "factory generation is stale" end
    return true
end

local function _instanceHandle(instance)
    local state = factory.state
    return {
        protocolVersion = factory.protocolVersion,
        factoryIdentity = state.identity,
        identity = instance.identity,
        ownerId = instance.ownerId,
        generation = instance.generation,
        instanceId = instance.instanceId,
        instanceGeneration = instance.instanceGeneration,
    }
end

local function _validInstanceHandle(handle)
    local state = factory.state
    if type(handle) ~= "table" then return false, "instance handle is required" end
    if _safeString(handle.factoryIdentity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "instance factory identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "instance owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "instance generation is stale" end
    local id = _safeString(handle.instanceId)
    local instance = state.instances[id]
    if instance == nil then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "instance is missing" end
    if math.floor(_safeNumber(handle.instanceGeneration, 0)) ~= instance.instanceGeneration then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "instance generation is stale" end
    return true, instance
end

local function _activeCount()
    local count = 0
    for _, instance in pairs(factory.state.instances) do if instance.lifecycle == "active" then count = count + 1 end end
    return count
end

local function _emit(kind, instance, reason)
    local state = factory.state
    state.eventSequence = state.eventSequence + 1
    local event = {
        protocolVersion = factory.protocolVersion,
        eventId = state.eventSequence,
        kind = kind,
        identity = instance ~= nil and instance.identity or state.identity,
        ownerId = instance ~= nil and instance.ownerId or state.ownerId,
        generation = state.generation,
        instanceId = instance ~= nil and instance.instanceId or "",
        instanceGeneration = instance ~= nil and instance.instanceGeneration or 0,
        reason = _safeString(reason, ""),
    }
    if #state.events >= state.eventCapacity then table.remove(state.events, 1); state.metrics.eventsDropped = state.metrics.eventsDropped + 1 end
    state.events[#state.events + 1] = event
    state.metrics.eventsEmitted = state.metrics.eventsEmitted + 1
end

local function _stageStatus(instance, status)
    for _, stage in ipairs(factory.stageOrder) do instance.stages[stage] = status end
end

local function _instanceSnapshot(instance)
    return {
        protocolVersion = factory.protocolVersion,
        factoryIdentity = factory.state.identity,
        identity = instance.identity,
        ownerId = instance.ownerId,
        generation = instance.generation,
        instanceId = instance.instanceId,
        instanceGeneration = instance.instanceGeneration,
        definitionId = instance.definitionId,
        mode = instance.mode,
        lifecycle = instance.lifecycle,
        stages = _clone(instance.stages),
        ticks = instance.ticks,
        resources = _clone(instance.resources),
    }
end

function factory.serverInit(generation, ownerId, options)
    local state = factory.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.identity = _safeString(resolved.identity, "vehicle-factory:" .. _safeString(ownerId, "owner"))
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.mode = _safeString(resolved.mode, "legacy")
    if state.mode ~= "legacy" and state.mode ~= "shadow" and state.mode ~= "synthetic" then state.mode = "legacy" end
    state.maxInstances = math.max(1, math.floor(_safeNumber(resolved.maxInstances, 16)))
    state.eventCapacity = math.max(8, math.floor(_safeNumber(resolved.eventCapacity, 64)))
    state.nextSequence = 0
    state.instances = {}
    state.events = {}
    state.eventSequence = 0
    local initCount = (state.metrics.initCount or 0) + 1
    state.metrics = {
        initCount = initCount, spawnAttempts = 0, spawns = 0, spawnRejects = 0,
        stageFailures = 0, rollbacks = 0, ticks = 0, disposes = 0,
        idempotentDisposes = 0, activePeak = 0, eventsEmitted = 0,
        eventsDropped = 0, staleRejects = 0, ownerRejects = 0,
    }
    return factory.handle()
end

function factory.handle()
    local state = factory.state
    return { protocolVersion = factory.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation }
end

function factory.spawn(handle, definition, options)
    local state = factory.state
    local valid, errorText = _validFactoryHandle(handle)
    if not valid then return nil, errorText end
    state.metrics.spawnAttempts = state.metrics.spawnAttempts + 1
    local source = type(definition) == "table" and definition or {}
    local resolved = type(options) == "table" and options or {}
    if _activeCount() >= state.maxInstances then state.metrics.spawnRejects = state.metrics.spawnRejects + 1; return nil, "factory capacity reached" end
    state.nextSequence = state.nextSequence + 1
    local instanceId = _safeString(resolved.instanceId, _safeString(source.identity, _safeString(source.definitionId, "vehicle") .. ":" .. tostring(state.nextSequence)))
    if state.instances[instanceId] ~= nil then state.metrics.spawnRejects = state.metrics.spawnRejects + 1; return nil, "instance identity already exists" end
    local ownerId = _safeString(resolved.ownerId, state.ownerId)
    if ownerId ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; state.metrics.spawnRejects = state.metrics.spawnRejects + 1; return nil, "instance owner mismatch" end
    local instance = {
        identity = instanceId,
        ownerId = ownerId,
        generation = state.generation,
        instanceId = instanceId,
        instanceGeneration = state.nextSequence,
        definitionId = _safeString(source.definitionId, instanceId),
        mode = _safeString(resolved.mode, state.mode),
        lifecycle = "spawning",
        stages = {},
        resources = {},
        ticks = 0,
    }
    local failStage = _safeString(resolved.failStage, "")
    for _, stage in ipairs(factory.stageOrder) do
        if failStage == stage then
            instance.lifecycle = "failed"
            instance.failureStage = stage
            state.metrics.stageFailures = state.metrics.stageFailures + 1
            state.metrics.rollbacks = state.metrics.rollbacks + 1
            for _, rollbackStage in ipairs(factory.stageOrder) do instance.stages[rollbackStage] = "rolled_back" end
            _emit("spawn_failed", instance, "stage:" .. stage)
            state.metrics.spawnRejects = state.metrics.spawnRejects + 1
            return nil, "spawn failed at stage: " .. stage
        end
        instance.stages[stage] = "created"
        instance.resources[stage] = { stage = stage, ownerId = ownerId, generation = state.generation }
    end
    instance.lifecycle = "active"
    state.instances[instanceId] = instance
    state.metrics.spawns = state.metrics.spawns + 1
    local active = _activeCount()
    if active > state.metrics.activePeak then state.metrics.activePeak = active end
    _emit("spawned", instance, "factory")
    return _instanceHandle(instance), _instanceSnapshot(instance)
end

function factory.serverTick(handle, instanceHandle, dt)
    local validFactory, factoryError = _validFactoryHandle(handle)
    if not validFactory then return false, factoryError end
    local valid, instanceOrError = _validInstanceHandle(instanceHandle)
    if not valid then return false, instanceOrError end
    local instance = instanceOrError
    if instance.lifecycle ~= "active" then return false, "instance is not active" end
    instance.ticks = instance.ticks + 1
    factory.state.metrics.ticks = factory.state.metrics.ticks + 1
    return true, _instanceSnapshot(instance)
end

function factory.dispose(handle, instanceHandle, reason)
    local validFactory, factoryError = _validFactoryHandle(handle)
    if not validFactory then return false, factoryError end
    local valid, instanceOrError = _validInstanceHandle(instanceHandle)
    if not valid then return false, instanceOrError end
    local instance = instanceOrError
    if instance.lifecycle == "disposed" then factory.state.metrics.idempotentDisposes = factory.state.metrics.idempotentDisposes + 1; return false, "instance already disposed" end
    for index = #factory.stageOrder, 1, -1 do
        local stage = factory.stageOrder[index]
        instance.stages[stage] = "disposed"
        instance.resources[stage] = nil
    end
    instance.lifecycle = "disposed"
    factory.state.metrics.disposes = factory.state.metrics.disposes + 1
    _emit("disposed", instance, reason or "factory-dispose")
    return true, _instanceSnapshot(instance)
end

function factory.disposeAll(handle, reason)
    local valid, errorText = _validFactoryHandle(handle)
    if not valid then return false, errorText end
    local count = 0
    for _, instance in pairs(factory.state.instances) do
        if instance.lifecycle == "active" then
            local ok = factory.dispose(handle, _instanceHandle(instance), reason or "factory-dispose-all")
            if ok then count = count + 1 end
        end
    end
    return true, count
end

function factory.validateInstance(instanceHandle)
    local valid, value = _validInstanceHandle(instanceHandle)
    if not valid then return false, value end
    return true, _instanceSnapshot(value)
end

function factory.snapshot(handle)
    local valid, errorText = _validFactoryHandle(handle)
    if not valid then return nil, errorText end
    local instances = {}
    for id, instance in pairs(factory.state.instances) do instances[id] = _instanceSnapshot(instance) end
    return {
        protocolVersion = factory.protocolVersion,
        identity = factory.state.identity,
        ownerId = factory.state.ownerId,
        generation = factory.state.generation,
        mode = factory.state.mode,
        maxInstances = factory.state.maxInstances,
        instances = instances,
    }
end

function factory.drainEvents(handle, limit)
    local valid, errorText = _validFactoryHandle(handle)
    if not valid then return nil, errorText end
    local count = math.max(1, math.floor(_safeNumber(limit, #factory.state.events)))
    local result = {}
    while #result < count and #factory.state.events > 0 do result[#result + 1] = table.remove(factory.state.events, 1) end
    return result
end

function factory.getDiagnostics()
    local state = factory.state
    local active = _activeCount()
    local total = 0
    for _ in pairs(state.instances) do total = total + 1 end
    return {
        protocolVersion = factory.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        mode = state.mode,
        maxInstances = state.maxInstances,
        activeInstances = active,
        totalInstances = total,
        eventQueue = #state.events,
        eventCapacity = state.eventCapacity,
        initCount = state.metrics.initCount,
        spawnAttempts = state.metrics.spawnAttempts,
        spawns = state.metrics.spawns,
        spawnRejects = state.metrics.spawnRejects,
        stageFailures = state.metrics.stageFailures,
        rollbacks = state.metrics.rollbacks,
        ticks = state.metrics.ticks,
        disposes = state.metrics.disposes,
        idempotentDisposes = state.metrics.idempotentDisposes,
        activePeak = state.metrics.activePeak,
        eventsEmitted = state.metrics.eventsEmitted,
        eventsDropped = state.metrics.eventsDropped,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
    }
end
