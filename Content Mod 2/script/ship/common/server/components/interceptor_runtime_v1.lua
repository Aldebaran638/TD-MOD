---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Bounded Interceptor Runtime v1.
-- The legacy strike-craft controller remains authoritative by default. Runtime
-- mode is an explicit shadow/promotion switch with fixed target, flight,
-- intercept, impact and presentation budgets.

cm2InterceptorRuntimeV1 = cm2InterceptorRuntimeV1 or {}
local interceptor = cm2InterceptorRuntimeV1

interceptor.protocolVersion = "cm2.interceptor-runtime/1"
interceptor.defaultMaxPerOwner = 4
interceptor.defaultMaxGlobal = 24
interceptor.defaultThinkHz = 5.0
interceptor.defaultUpdateHz = 30.0
interceptor.defaultMaxThinkPerTick = 4
interceptor.defaultMaxUpdatePerTick = 24
interceptor.defaultLifetime = 24.0

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerBodyId = 0,
        generation = 0,
        mode = "legacy",
        maxPerOwner = interceptor.defaultMaxPerOwner,
        maxGlobal = interceptor.defaultMaxGlobal,
        thinkHz = interceptor.defaultThinkHz,
        updateHz = interceptor.defaultUpdateHz,
        maxThinkPerTick = interceptor.defaultMaxThinkPerTick,
        maxUpdatePerTick = interceptor.defaultMaxUpdatePerTick,
        thinkAccumulator = 0.0,
        updateAccumulator = 0.0,
        entries = {},
        byId = {},
        metrics = {
            registered = 0,
            registerRejected = 0,
            targetQueries = 0,
            targetSelected = 0,
            targetLost = 0,
            staleRejected = 0,
            ownerRejected = 0,
            thinkTicks = 0,
            thinkProcessed = 0,
            thinkBudgetRejected = 0,
            updateTicks = 0,
            updateProcessed = 0,
            updateBudgetRejected = 0,
            flightUpdates = 0,
            intercepts = 0,
            impacts = 0,
            presentations = 0,
            finishes = 0,
            idempotentFinishes = 0,
            ownerTerminated = 0,
            sceneReloadTerminated = 0,
            replayEvents = 0,
            activeHighWatermark = 0,
        },
    }
end

interceptor.state = interceptor.state or _newState()

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback or "" end
    return value
end

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _vector(value)
    local source = type(value) == "table" and value or {}
    return {
        x = _safeNumber(source.x or source[1], 0.0),
        y = _safeNumber(source.y or source[2], 0.0),
        z = _safeNumber(source.z or source[3], 0.0),
    }
end

local function _copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do
        if type(child) == "table" then result[key] = _copy(child) else result[key] = child end
    end
    return result
end

local function _phase(seed, id)
    local numericSeed = math.floor(_safeNumber(seed, 0.0))
    if numericSeed == 0 then numericSeed = #tostring(id or "") * 37 end
    return (math.abs(numericSeed) % 997) / 997.0
end

local function _entry(id)
    return interceptor.state.byId[_safeString(id)]
end

local function _activeCount()
    local count = 0
    for _, value in pairs(interceptor.state.entries) do
        if value ~= nil and value.status ~= "finished" then count = count + 1 end
    end
    return count
end

local function _ownerCount(ownerId)
    local count = 0
    local resolved = _safeString(ownerId)
    for _, value in pairs(interceptor.state.entries) do
        if value ~= nil and value.status ~= "finished" and value.ownerId == resolved then count = count + 1 end
    end
    return count
end

local function _sortedEntries()
    local values = {}
    for _, value in pairs(interceptor.state.entries) do
        if value ~= nil and value.status ~= "finished" then values[#values + 1] = value end
    end
    table.sort(values, function(left, right)
        return tostring(left.id) < tostring(right.id)
    end)
    return values
end

local function _isGenerationValid(value)
    return value ~= nil and math.floor(_safeNumber(value.generation, 0)) == interceptor.state.generation
end

local function _candidateUsable(entryValue, candidate)
    if type(candidate) ~= "table" then return false end
    local candidateId = _safeString(candidate.entityId or candidate.id)
    if candidateId == "" then return false end
    if candidate.disabled == true or candidate.destroyed == true then return false end
    local expectedGeneration = math.floor(_safeNumber(entryValue.targetGeneration, 0))
    local candidateGeneration = math.floor(_safeNumber(candidate.generation or candidate.targetGeneration, 0))
    return expectedGeneration == 0 or candidateGeneration == expectedGeneration
end

local function _recordTargetLost(entryValue, reason)
    entryValue.targetId = ""
    entryValue.targetGeneration = 0
    entryValue.targetRevision = 0
    entryValue.lastTargetLossReason = _safeString(reason, "target-lost")
    entryValue.status = "return"
    interceptor.state.metrics.targetLost = interceptor.state.metrics.targetLost + 1
end

function interceptor.serverInit(identity, ownerBodyId, generation, options)
    local state = interceptor.state
    if state.initialized then return interceptor.getDiagnostics() end
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.identity = _safeString(identity, "interceptor-runtime")
    state.ownerBodyId = math.floor(_safeNumber(ownerBodyId, 0))
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.mode = _safeString(resolved.mode, "legacy")
    if state.mode ~= "legacy" and state.mode ~= "shadow" and state.mode ~= "runtime" then state.mode = "legacy" end
    state.maxPerOwner = math.max(1, math.floor(_safeNumber(resolved.maxPerOwner, interceptor.defaultMaxPerOwner)))
    state.maxGlobal = math.max(state.maxPerOwner, math.floor(_safeNumber(resolved.maxGlobal, interceptor.defaultMaxGlobal)))
    state.thinkHz = math.max(1.0, _safeNumber(resolved.thinkHz, interceptor.defaultThinkHz))
    state.updateHz = math.max(1.0, _safeNumber(resolved.updateHz, interceptor.defaultUpdateHz))
    state.maxThinkPerTick = math.max(1, math.floor(_safeNumber(resolved.maxThinkPerTick, interceptor.defaultMaxThinkPerTick)))
    state.maxUpdatePerTick = math.max(1, math.floor(_safeNumber(resolved.maxUpdatePerTick, interceptor.defaultMaxUpdatePerTick)))
    state.thinkAccumulator = 0.0
    state.updateAccumulator = 0.0
    state.entries = {}
    state.byId = {}
    state.metrics = {
        registered = 0, registerRejected = 0, targetQueries = 0, targetSelected = 0,
        targetLost = 0, staleRejected = 0, ownerRejected = 0, thinkTicks = 0,
        thinkProcessed = 0, thinkBudgetRejected = 0, updateTicks = 0,
        updateProcessed = 0, updateBudgetRejected = 0, flightUpdates = 0,
        intercepts = 0, impacts = 0, presentations = 0, finishes = 0,
        idempotentFinishes = 0, ownerTerminated = 0, sceneReloadTerminated = 0,
        replayEvents = 0, activeHighWatermark = 0,
    }
    return interceptor.getDiagnostics()
end

function interceptor.setMode(mode)
    local resolved = _safeString(mode, "")
    if resolved ~= "legacy" and resolved ~= "shadow" and resolved ~= "runtime" then return false, "unknown interceptor runtime mode" end
    interceptor.state.mode = resolved
    return true
end

function interceptor.register(definition)
    local state = interceptor.state
    local source = type(definition) == "table" and definition or {}
    if not state.initialized then return nil, "interceptor runtime is not initialized" end
    local id = _safeString(source.id)
    if id == "" then state.metrics.registerRejected = state.metrics.registerRejected + 1; return nil, "interceptor id is required" end
    if state.byId[id] ~= nil then return nil, "interceptor id already registered" end
    local ownerId = _safeString(source.ownerId, state.identity)
    if _ownerCount(ownerId) >= state.maxPerOwner or _activeCount() >= state.maxGlobal then
        state.metrics.registerRejected = state.metrics.registerRejected + 1
        return nil, "interceptor capacity exhausted"
    end
    local generation = math.floor(_safeNumber(source.generation, state.generation))
    if generation ~= state.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return nil, "interceptor generation is stale" end
    local value = {
        id = id,
        generation = generation,
        ownerId = ownerId,
        ownerBodyId = math.floor(_safeNumber(source.ownerBodyId, state.ownerBodyId)),
        seed = math.floor(_safeNumber(source.seed, #state.entries + 1)),
        status = "launch",
        age = 0.0,
        lifetime = math.max(0.1, _safeNumber(source.lifetime, interceptor.defaultLifetime)),
        position = _vector(source.position),
        velocity = _vector(source.velocity),
        targetId = _safeString(source.targetId or source.targetEntityId),
        targetGeneration = math.max(0, math.floor(_safeNumber(source.targetGeneration, 0))),
        targetRevision = math.max(0, math.floor(_safeNumber(source.targetRevision, 0))),
        phase = _phase(source.seed, id),
        thinkAccumulator = 0.0,
        updateAccumulator = 0.0,
        lifecycleHandle = source.lifecycleHandle,
        presentationSourceId = _safeString(source.presentationSourceId, id),
    }
    state.entries[id] = value
    state.byId[id] = value
    state.metrics.registered = state.metrics.registered + 1
    local active = _activeCount()
    if active > state.metrics.activeHighWatermark then state.metrics.activeHighWatermark = active end
    return _copy(value)
end

function interceptor.selectTarget(id, targetCatalog, origin, radius, filter, candidate)
    local value = _entry(id)
    if value == nil then return false, "interceptor is unknown" end
    if not _isGenerationValid(value) then interceptor.state.metrics.staleRejected = interceptor.state.metrics.staleRejected + 1; return false, "interceptor generation is stale" end
    local selected = nil
    if type(targetCatalog) == "table" and type(targetCatalog.query) == "function" then
        interceptor.state.metrics.targetQueries = interceptor.state.metrics.targetQueries + 1
        local candidates = targetCatalog.query(origin or value.position, math.max(0.0, _safeNumber(radius, 0.0)), filter or {})
        if type(candidates) == "table" then
            for _, option in ipairs(candidates) do
                if _candidateUsable(value, option) then selected = option; break end
            end
        end
    elseif _candidateUsable(value, candidate) then
        selected = candidate
    end
    if selected == nil then
        _recordTargetLost(value, "target-lost")
        return false, "target-lost"
    end
    value.targetId = _safeString(selected.entityId or selected.id)
    value.targetGeneration = math.floor(_safeNumber(selected.generation or selected.targetGeneration, value.targetGeneration))
    value.targetRevision = math.floor(_safeNumber(selected.revision, value.targetRevision))
    value.status = "flight"
    value.lastTarget = _copy(selected)
    interceptor.state.metrics.targetSelected = interceptor.state.metrics.targetSelected + 1
    return true, _copy(selected)
end

function interceptor.intercept(id, candidate)
    local value = _entry(id)
    if value == nil then return false, "interceptor is unknown" end
    if not _isGenerationValid(value) then interceptor.state.metrics.staleRejected = interceptor.state.metrics.staleRejected + 1; return false, "interceptor generation is stale" end
    if not _candidateUsable(value, candidate) then _recordTargetLost(value, "target-stale"); return false, "target-stale" end
    interceptor.state.metrics.intercepts = interceptor.state.metrics.intercepts + 1
    value.status = "intercept"
    value.lastTarget = _copy(candidate)
    if candidate.hit == true or candidate.intercepted == true then
        return interceptor.impact(id, candidate)
    end
    return true, "intercepting"
end

function interceptor.impact(id, hit)
    local value = _entry(id)
    if value == nil then return false, "interceptor is unknown" end
    if not _isGenerationValid(value) then interceptor.state.metrics.staleRejected = interceptor.state.metrics.staleRejected + 1; return false, "interceptor generation is stale" end
    if value.status == "finished" then interceptor.state.metrics.idempotentFinishes = interceptor.state.metrics.idempotentFinishes + 1; return false, "already-finished" end
    local impact = type(hit) == "table" and hit or {}
    value.status = "impact"
    value.lastImpact = _copy(impact)
    interceptor.state.metrics.impacts = interceptor.state.metrics.impacts + 1
    local lifecycle = cm2ProjectileLifecycleV1
    if lifecycle ~= nil and value.lifecycleHandle ~= nil then
        if lifecycle.collide ~= nil then lifecycle.collide(value.lifecycleHandle, impact) end
        if lifecycle.finish ~= nil then lifecycle.finish(value.lifecycleHandle, "impact", impact) end
        if lifecycle.destroy ~= nil then lifecycle.destroy(value.lifecycleHandle, "impact") end
    end
    if server ~= nil and server.presentationPublisherPublish ~= nil then
        server.presentationPublisherPublish("sound", {
            sourceId = value.presentationSourceId,
            position = impact.position,
            payload = { event = "interceptor-impact", interceptorId = value.id },
            route = "missile.impactSound",
            routeArgs = { "interceptor", impact.position and impact.position[1] or 0.0, impact.position and impact.position[2] or 0.0, impact.position and impact.position[3] or 0.0 },
        })
        interceptor.state.metrics.presentations = interceptor.state.metrics.presentations + 1
    end
    interceptor.finish(id, "impact", impact)
    return true, "impact"
end

function interceptor.finish(id, reason, evidence)
    local state = interceptor.state
    local value = _entry(id)
    if value == nil then state.metrics.idempotentFinishes = state.metrics.idempotentFinishes + 1; return false, "already-finished" end
    if not _isGenerationValid(value) then state.metrics.staleRejected = state.metrics.staleRejected + 1; return false, "interceptor generation is stale" end
    value.status = "finished"
    value.finishReason = _safeString(reason, "finish")
    value.finishEvidence = _copy(evidence)
    state.entries[value.id] = nil
    state.byId[value.id] = nil
    state.metrics.finishes = state.metrics.finishes + 1
    return true, value.finishReason
end

function interceptor.ownerDestroyed(ownerId)
    local terminated = 0
    local resolved = _safeString(ownerId)
    for _, value in ipairs(_sortedEntries()) do
        if value.ownerId == resolved then
            interceptor.finish(value.id, "owner-destroyed")
            terminated = terminated + 1
        end
    end
    interceptor.state.metrics.ownerTerminated = interceptor.state.metrics.ownerTerminated + terminated
    return terminated
end

function interceptor.sceneReload(generation)
    local terminated = 0
    for _, value in ipairs(_sortedEntries()) do
        interceptor.finish(value.id, "scene-reload")
        terminated = terminated + 1
    end
    interceptor.state.generation = math.max(1, math.floor(_safeNumber(generation, interceptor.state.generation + 1)))
    interceptor.state.metrics.sceneReloadTerminated = interceptor.state.metrics.sceneReloadTerminated + terminated
    return terminated
end

local function _updateFlight(value, delta, flightAdapter)
    value.age = value.age + delta
    if value.age >= value.lifetime then interceptor.finish(value.id, "ttl"); return false end
    if type(flightAdapter) == "function" then
        local result = flightAdapter(_copy(value), delta)
        if type(result) == "table" then
            if result.position ~= nil then value.position = _vector(result.position) end
            if result.velocity ~= nil then value.velocity = _vector(result.velocity) end
            if result.status ~= nil then value.status = _safeString(result.status, value.status) end
        end
        interceptor.state.metrics.flightUpdates = interceptor.state.metrics.flightUpdates + 1
    end
    value.updateAccumulator = 0.0
    return true
end

function interceptor.serverTick(dt, context)
    local state = interceptor.state
    if not state.initialized or state.mode == "legacy" then return 0 end
    local delta = math.max(0.0, _safeNumber(dt, 0.0))
    local source = type(context) == "table" and context or {}
    state.thinkAccumulator = state.thinkAccumulator + delta
    state.updateAccumulator = state.updateAccumulator + delta
    local processed = 0
    if state.thinkAccumulator >= 1.0 / state.thinkHz then
        state.thinkAccumulator = state.thinkAccumulator - 1.0 / state.thinkHz
        state.metrics.thinkTicks = state.metrics.thinkTicks + 1
        for _, value in ipairs(_sortedEntries()) do
            if processed >= state.maxThinkPerTick then state.metrics.thinkBudgetRejected = state.metrics.thinkBudgetRejected + 1; break end
            if value.status ~= "return" and value.status ~= "impact" then
                interceptor.selectTarget(value.id, source.targetCatalog, value.position, source.targetRadius, source.targetFilter, source.candidateById and source.candidateById[value.id] or nil)
            end
            processed = processed + 1
            state.metrics.thinkProcessed = state.metrics.thinkProcessed + 1
        end
    end
    processed = 0
    if state.updateAccumulator >= 1.0 / state.updateHz then
        state.updateAccumulator = state.updateAccumulator - 1.0 / state.updateHz
        state.metrics.updateTicks = state.metrics.updateTicks + 1
        for _, value in ipairs(_sortedEntries()) do
            if processed >= state.maxUpdatePerTick then state.metrics.updateBudgetRejected = state.metrics.updateBudgetRejected + 1; break end
            _updateFlight(value, delta, source.flightAdapter)
            processed = processed + 1
            state.metrics.updateProcessed = state.metrics.updateProcessed + 1
        end
    end
    return processed
end

function interceptor.replay(trace)
    if type(trace) ~= "table" then return nil, "replay trace is required" end
    local results = {}
    for _, event in ipairs(trace) do
        local kind = _safeString(event.event)
        local result = "ignored"
        if kind == "register" then result = interceptor.register(event.definition or event)
        elseif kind == "select" then result = interceptor.selectTarget(event.id, nil, nil, event.radius, event.filter, event.candidate)
        elseif kind == "intercept" then result = interceptor.intercept(event.id, event.candidate)
        elseif kind == "impact" then result = interceptor.impact(event.id, event.hit)
        elseif kind == "finish" then result = interceptor.finish(event.id, event.reason)
        elseif kind == "tick" then result = interceptor.serverTick(event.dt, event.context)
        end
        results[#results + 1] = { event = kind, result = result }
        interceptor.state.metrics.replayEvents = interceptor.state.metrics.replayEvents + 1
    end
    return { protocolVersion = interceptor.protocolVersion, synthetic = true, events = #trace, results = results, diagnostics = interceptor.getDiagnostics() }
end

function interceptor.getDiagnostics()
    local state = interceptor.state
    return {
        protocolVersion = interceptor.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerBodyId = state.ownerBodyId,
        generation = state.generation,
        mode = state.mode,
        active = _activeCount(),
        maxPerOwner = state.maxPerOwner,
        maxGlobal = state.maxGlobal,
        thinkHz = state.thinkHz,
        updateHz = state.updateHz,
        registered = state.metrics.registered,
        registerRejected = state.metrics.registerRejected,
        targetQueries = state.metrics.targetQueries,
        targetSelected = state.metrics.targetSelected,
        targetLost = state.metrics.targetLost,
        staleRejected = state.metrics.staleRejected,
        ownerRejected = state.metrics.ownerRejected,
        thinkTicks = state.metrics.thinkTicks,
        thinkProcessed = state.metrics.thinkProcessed,
        thinkBudgetRejected = state.metrics.thinkBudgetRejected,
        updateTicks = state.metrics.updateTicks,
        updateProcessed = state.metrics.updateProcessed,
        updateBudgetRejected = state.metrics.updateBudgetRejected,
        flightUpdates = state.metrics.flightUpdates,
        intercepts = state.metrics.intercepts,
        impacts = state.metrics.impacts,
        presentations = state.metrics.presentations,
        finishes = state.metrics.finishes,
        idempotentFinishes = state.metrics.idempotentFinishes,
        ownerTerminated = state.metrics.ownerTerminated,
        sceneReloadTerminated = state.metrics.sceneReloadTerminated,
        replayEvents = state.metrics.replayEvents,
        activeHighWatermark = state.metrics.activeHighWatermark,
    }
end
