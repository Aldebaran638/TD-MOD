-- Unified Projectile lifecycle contract and logical dense store v1.
-- The legacy manager remains the production default until live replay promotes
-- this adapter. No engine handle, callback or raw Definition crosses this API.

cm2ProjectileLifecycleV1 = cm2ProjectileLifecycleV1 or {}
local lifecycle = cm2ProjectileLifecycleV1

lifecycle.protocolVersion = "cm2.projectile.lifecycle/1"
lifecycle.allowedBackends = {
    hitscan = true,
    logicalSwept = true,
    kinematicBody = true,
    physicalBody = true,
}
lifecycle.defaultCapacity = 500

local function _newState()
    return {
        initialized = false,
        generation = 0,
        capacity = lifecycle.defaultCapacity,
        seedCounter = 0,
        slots = {},
        generations = {},
        free = {},
        activeIndices = {},
        activePosition = {},
        byProjectileId = {},
        metrics = {
            spawned = 0,
            updates = 0,
            corrections = 0,
            collisions = 0,
            finishes = 0,
            idempotentFinishes = 0,
            destroys = 0,
            ttlFinishes = 0,
            impactFinishes = 0,
            ownerTerminated = 0,
            sceneReloadTerminated = 0,
            staleRejected = 0,
            ownerRejected = 0,
            malformedRejected = 0,
            backendRejected = 0,
            capacityRejected = 0,
            maxActive = 0,
            replayEvents = 0,
            memoryBytesActive = 0,
            memoryBytesHighWatermark = 0,
        },
    }
end

lifecycle.state = lifecycle.state or _newState()

local function _safeString(value)
    if type(value) ~= "string" or value == "" then return "" end
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

local function _containsForbidden(value, seen)
    if type(value) == "function" or type(value) == "userdata" or type(value) == "thread" then return true end
    if type(value) ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for key, child in pairs(value) do
        if key == "engineHandle" or key == "bodyHandle" or key == "shapeHandle" or key == "jointHandle" or key == "definition" or key == "rawDefinition" or key == "callback" then return true end
        if _containsForbidden(child, seen) then return true end
    end
    return false
end

local function _vector(value)
    local source = type(value) == "table" and value or {}
    return {
        x = _safeNumber(source.x or source[1], 0.0),
        y = _safeNumber(source.y or source[2], 0.0),
        z = _safeNumber(source.z or source[3], 0.0),
    }
end

local function _resetState(state, generation, capacity)
    state.initialized = true
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.capacity = math.max(1, math.floor(_safeNumber(capacity, lifecycle.defaultCapacity)))
    state.seedCounter = 0
    state.slots = {}
    state.generations = {}
    state.free = {}
    state.activeIndices = {}
    state.activePosition = {}
    state.byProjectileId = {}
    state.metrics = {
        spawned = 0, updates = 0, corrections = 0, collisions = 0,
        finishes = 0, idempotentFinishes = 0, destroys = 0, ttlFinishes = 0,
        impactFinishes = 0, ownerTerminated = 0, sceneReloadTerminated = 0,
        staleRejected = 0, ownerRejected = 0, malformedRejected = 0,
        backendRejected = 0, capacityRejected = 0, maxActive = 0,
        replayEvents = 0, memoryBytesActive = 0, memoryBytesHighWatermark = 0,
    }
    for index = state.capacity, 1, -1 do
        state.generations[index] = 1
        state.free[#state.free + 1] = index
    end
end

local function _slotFromHandle(handle, expectedOwner)
    local state = lifecycle.state
    if type(handle) ~= "table" then state.metrics.staleRejected = state.metrics.staleRejected + 1; return nil, "stale projectile handle" end
    local index = math.floor(_safeNumber(handle.index, 0))
    local generation = math.floor(_safeNumber(handle.generation, 0))
    local slot = state.slots[index]
    if index < 1 or index > state.capacity or slot == nil or state.generations[index] ~= generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return nil, "stale projectile handle" end
    if expectedOwner ~= nil and slot.ownerId ~= expectedOwner then state.metrics.ownerRejected = state.metrics.ownerRejected + 1; return nil, "projectile owner mismatch" end
    return slot
end

local function _handle(slot)
    return {
        protocolVersion = lifecycle.protocolVersion,
        projectileId = slot.projectileId,
        index = slot.index,
        generation = slot.generation,
        ownerId = slot.ownerId,
    }
end

local function _memoryUpdate(state)
    local activeCount = #state.activeIndices
    state.metrics.memoryBytesActive = activeCount * 256
    if state.metrics.memoryBytesActive > state.metrics.memoryBytesHighWatermark then state.metrics.memoryBytesHighWatermark = state.metrics.memoryBytesActive end
    if activeCount > state.metrics.maxActive then state.metrics.maxActive = activeCount end
end

local function _finishSlot(slot, reason, hit)
    local state = lifecycle.state
    if slot.status == "finished" then state.metrics.idempotentFinishes = state.metrics.idempotentFinishes + 1; return _clone(slot.finishResult), "idempotent" end
    if slot.status == "destroyed" then state.metrics.staleRejected = state.metrics.staleRejected + 1; return nil, "stale projectile handle" end
    slot.status = "finished"
    slot.finishReason = _safeString(reason) ~= "" and _safeString(reason) or "completed"
    slot.finishHit = _clone(hit)
    slot.finishResult = {
        projectileId = slot.projectileId,
        ownerId = slot.ownerId,
        generation = slot.generation,
        reason = slot.finishReason,
        hit = _clone(hit),
    }
    state.metrics.finishes = state.metrics.finishes + 1
    if slot.finishReason == "ttl" then state.metrics.ttlFinishes = state.metrics.ttlFinishes + 1 end
    if slot.finishReason == "impact" then state.metrics.impactFinishes = state.metrics.impactFinishes + 1 end
    return _clone(slot.finishResult)
end

local function _destroySlot(slot, reason)
    local state = lifecycle.state
    local index = slot.index
    local position = state.activePosition[index]
    local lastPosition = #state.activeIndices
    local lastIndex = state.activeIndices[lastPosition]
    if position ~= lastPosition then state.activeIndices[position] = lastIndex; state.activePosition[lastIndex] = position end
    state.activeIndices[lastPosition] = nil
    state.activePosition[index] = nil
    state.slots[index] = nil
    state.byProjectileId[slot.projectileId] = nil
    state.generations[index] = state.generations[index] + 1
    state.free[#state.free + 1] = index
    state.metrics.destroys = state.metrics.destroys + 1
    slot.status = "destroyed"
    slot.destroyReason = _safeString(reason) ~= "" and _safeString(reason) or "destroy"
    _memoryUpdate(state)
    return true
end

function lifecycle.serverInit(generation, capacity)
    local state = lifecycle.state
    if state.initialized then return lifecycle.getDiagnostics() end
    _resetState(state, generation, capacity)
    return lifecycle.getDiagnostics()
end

function lifecycle.spawn(definitionId, fireContext, backend)
    local state = lifecycle.state
    local context = type(fireContext) == "table" and fireContext or {}
    local resolvedBackend = _safeString(backend) ~= "" and _safeString(backend) or _safeString(context.backend)
    if not state.initialized then return nil, "projectile lifecycle is not initialized" end
    if _safeString(definitionId) == "" or _safeString(context.ownerId) == "" then state.metrics.malformedRejected = state.metrics.malformedRejected + 1; return nil, "definitionId and ownerId are required" end
    if not lifecycle.allowedBackends[resolvedBackend] then state.metrics.backendRejected = state.metrics.backendRejected + 1; return nil, "projectile backend is unsupported" end
    if _containsForbidden(context) then state.metrics.malformedRejected = state.metrics.malformedRejected + 1; return nil, "projectile context contains forbidden runtime reference" end
    if #state.free == 0 then state.metrics.capacityRejected = state.metrics.capacityRejected + 1; return nil, "projectile capacity exhausted" end
    local index = table.remove(state.free)
    local generationValue = state.generations[index]
    state.seedCounter = state.seedCounter + 1
    local seed = math.floor(_safeNumber(context.seed, state.seedCounter))
    local projectileId = "projectile:" .. tostring(state.generation) .. ":" .. tostring(index) .. ":" .. tostring(seed)
    local slot = {
        protocolVersion = lifecycle.protocolVersion,
        projectileId = projectileId,
        index = index,
        generation = generationValue,
        definitionId = _safeString(definitionId),
        backend = resolvedBackend,
        ownerId = _safeString(context.ownerId),
        status = "active",
        seed = seed,
        position = _vector(context.origin),
        direction = _vector(context.direction),
        velocity = _vector(context.velocity),
        flightRemain = math.max(0.0, _safeNumber(context.lifetime, 0.0)),
        targetEntityId = _safeString(context.targetEntityId),
        targetGeneration = math.max(0, math.floor(_safeNumber(context.targetGeneration, 0))),
        damage = math.max(0.0, _safeNumber(context.damage, 0.0)),
        priority = math.floor(_safeNumber(context.priority, 0)),
        impactEventId = _safeString(context.impactEventId),
        lifecycleRevision = 1,
    }
    state.slots[index] = slot
    state.activeIndices[#state.activeIndices + 1] = index
    state.activePosition[index] = #state.activeIndices
    state.byProjectileId[projectileId] = index
    state.metrics.spawned = state.metrics.spawned + 1
    _memoryUpdate(state)
    return _handle(slot)
end

function lifecycle.update(handle, updateDto)
    local state = lifecycle.state
    local update = type(updateDto) == "table" and updateDto or {}
    local slot, errorText = _slotFromHandle(handle, update.ownerId)
    if slot == nil then return false, errorText end
    if slot.status == "finished" then return false, "projectile is already finished" end
    if _containsForbidden(update) then state.metrics.malformedRejected = state.metrics.malformedRejected + 1; return false, "projectile update contains forbidden runtime reference" end
    if update.position ~= nil then slot.position = _vector(update.position) end
    if update.velocity ~= nil then slot.velocity = _vector(update.velocity) end
    if update.flightRemain ~= nil then slot.flightRemain = math.max(0.0, _safeNumber(update.flightRemain, slot.flightRemain)) end
    if update.targetEntityId ~= nil then slot.targetEntityId = _safeString(update.targetEntityId) end
    if update.targetGeneration ~= nil then slot.targetGeneration = math.max(0, math.floor(_safeNumber(update.targetGeneration, slot.targetGeneration))) end
    slot.lifecycleRevision = slot.lifecycleRevision + 1
    state.metrics.updates = state.metrics.updates + 1
    return true
end

function lifecycle.correct(handle, correctionDto)
    local slot, errorText = _slotFromHandle(handle, type(correctionDto) == "table" and correctionDto.ownerId or nil)
    if slot == nil then return false, errorText end
    local correction = type(correctionDto) == "table" and correctionDto or {}
    if _containsForbidden(correction) then lifecycle.state.metrics.malformedRejected = lifecycle.state.metrics.malformedRejected + 1; return false, "projectile correction contains forbidden runtime reference" end
    if correction.position ~= nil then slot.position = _vector(correction.position) end
    if correction.velocity ~= nil then slot.velocity = _vector(correction.velocity) end
    slot.status = "active"
    slot.lifecycleRevision = slot.lifecycleRevision + 1
    lifecycle.state.metrics.corrections = lifecycle.state.metrics.corrections + 1
    return true
end

function lifecycle.collide(handle, hitDto)
    local hit = type(hitDto) == "table" and hitDto or {}
    local slot, errorText = _slotFromHandle(handle, hit.ownerId)
    if slot == nil then return false, errorText end
    if _containsForbidden(hit) then lifecycle.state.metrics.malformedRejected = lifecycle.state.metrics.malformedRejected + 1; return false, "projectile collision contains forbidden runtime reference" end
    if slot.status == "finished" then return false, "projectile is already finished" end
    slot.status = "colliding"
    slot.collision = _clone(hit)
    slot.lifecycleRevision = slot.lifecycleRevision + 1
    lifecycle.state.metrics.collisions = lifecycle.state.metrics.collisions + 1
    return true
end

function lifecycle.finish(handle, reason, hit)
    local slot, errorText = _slotFromHandle(handle)
    if slot == nil then return nil, errorText end
    return _finishSlot(slot, reason, hit)
end

function lifecycle.destroy(handle, reason)
    local slot, errorText = _slotFromHandle(handle)
    if slot == nil then return false, errorText end
    return _destroySlot(slot, reason)
end

function lifecycle.ownerDestroyed(ownerId)
    local state = lifecycle.state
    local owner = _safeString(ownerId)
    local terminated = 0
    for index = #state.activeIndices, 1, -1 do
        local slot = state.slots[state.activeIndices[index]]
        if slot ~= nil and slot.ownerId == owner then
            _finishSlot(slot, "owner-destroyed", nil)
            _destroySlot(slot, "owner-destroyed")
            terminated = terminated + 1
        end
    end
    state.metrics.ownerTerminated = state.metrics.ownerTerminated + terminated
    return terminated
end

function lifecycle.sceneReload()
    local state = lifecycle.state
    local terminated = 0
    for index = #state.activeIndices, 1, -1 do
        local slot = state.slots[state.activeIndices[index]]
        if slot ~= nil then
            _finishSlot(slot, "scene-reload", nil)
            _destroySlot(slot, "scene-reload")
            terminated = terminated + 1
        end
    end
    state.metrics.sceneReloadTerminated = state.metrics.sceneReloadTerminated + terminated
    return terminated
end

function lifecycle.tick(dt)
    local state = lifecycle.state
    if not state.initialized then return 0 end
    local delta = math.max(0.0, _safeNumber(dt, 0.0))
    local terminated = 0
    for index = #state.activeIndices, 1, -1 do
        local slot = state.slots[state.activeIndices[index]]
        if slot ~= nil and slot.status ~= "finished" then
            slot.flightRemain = slot.flightRemain - delta
            if slot.flightRemain <= 0.0 then
                _finishSlot(slot, "ttl", nil)
                _destroySlot(slot, "ttl")
                terminated = terminated + 1
            end
        end
    end
    return terminated
end

function lifecycle.snapshot()
    local state = lifecycle.state
    local entries = {}
    for _, index in ipairs(state.activeIndices) do
        local slot = state.slots[index]
        if slot ~= nil then entries[#entries + 1] = _clone(slot) end
    end
    return {
        protocolVersion = lifecycle.protocolVersion,
        generation = state.generation,
        revision = state.metrics.spawned + state.metrics.updates + state.metrics.corrections,
        entries = entries,
    }
end

function lifecycle.replay(trace)
    if type(trace) ~= "table" then lifecycle.state.metrics.malformedRejected = lifecycle.state.metrics.malformedRejected + 1; return nil, "replay trace is required" end
    lifecycle.state.metrics.replayEvents = lifecycle.state.metrics.replayEvents + #trace
    return { protocolVersion = lifecycle.protocolVersion, synthetic = true, events = #trace, trace = _clone(trace) }
end

function lifecycle.getDiagnostics()
    local state = lifecycle.state
    return {
        protocolVersion = lifecycle.protocolVersion,
        initialized = state.initialized,
        generation = state.generation,
        capacity = state.capacity,
        active = #state.activeIndices,
        free = #state.free,
        spawned = state.metrics.spawned,
        updates = state.metrics.updates,
        corrections = state.metrics.corrections,
        collisions = state.metrics.collisions,
        finishes = state.metrics.finishes,
        idempotentFinishes = state.metrics.idempotentFinishes,
        destroys = state.metrics.destroys,
        ttlFinishes = state.metrics.ttlFinishes,
        impactFinishes = state.metrics.impactFinishes,
        ownerTerminated = state.metrics.ownerTerminated,
        sceneReloadTerminated = state.metrics.sceneReloadTerminated,
        staleRejected = state.metrics.staleRejected,
        ownerRejected = state.metrics.ownerRejected,
        malformedRejected = state.metrics.malformedRejected,
        backendRejected = state.metrics.backendRejected,
        capacityRejected = state.metrics.capacityRejected,
        maxActive = state.metrics.maxActive,
        replayEvents = state.metrics.replayEvents,
        memoryBytesActive = state.metrics.memoryBytesActive,
        memoryBytesHighWatermark = state.metrics.memoryBytesHighWatermark,
    }
end
