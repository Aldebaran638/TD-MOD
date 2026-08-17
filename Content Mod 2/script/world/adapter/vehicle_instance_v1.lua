---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- VehicleInstance v1 wraps the existing single-root Body without changing its
-- physical layout. Identity/generation/owner are authoritative; Body remains
-- an implementation handle behind this adapter boundary.

cm2VehicleInstanceV1 = cm2VehicleInstanceV1 or {}
local vehicle = cm2VehicleInstanceV1

vehicle.protocolVersion = "cm2.vehicle-instance/1"

local function _newState()
    return {
        initialized = false,
        disposed = false,
        identity = "",
        definitionId = "",
        ownerId = "",
        bodyId = 0,
        generation = 0,
        lifecycle = "new",
        mode = "local",
        capabilities = {},
        health = { shield = 0.0, armor = 0.0, body = 0.0 },
        inputRevision = 0,
        mountRevision = 0,
        lastTick = 0.0,
        adapterReport = nil,
        metrics = {
            initCount = 0,
            ticks = 0,
            staleRejects = 0,
            ownerRejects = 0,
            lifecycleChanges = 0,
            healthReads = 0,
            mountResolves = 0,
            mountResolveRejects = 0,
            disposed = 0,
        },
    }
end

vehicle.state = vehicle.state or _newState()

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback or "" end
    return value
end

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _capabilities(value)
    local result = {}
    if type(value) ~= "table" then return result end
    for key, enabled in pairs(value) do
        if type(key) == "number" then result[tostring(enabled)] = true else result[tostring(key)] = enabled and true or false end
    end
    return result
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

local function _setLifecycle(nextLifecycle)
    local state = vehicle.state
    local value = _safeString(nextLifecycle, "active")
    if value ~= "new" and value ~= "spawning" and value ~= "active"
        and value ~= "recovering" and value ~= "destroyed" and value ~= "disposed" then
        return false
    end
    if state.lifecycle ~= value then state.lifecycle = value; state.metrics.lifecycleChanges = state.metrics.lifecycleChanges + 1 end
    return true
end

local function _validHandle(handle)
    local state = vehicle.state
    if type(handle) ~= "table" then return false, "vehicle handle is required" end
    if _safeString(handle.identity) ~= state.identity then return false, "vehicle identity mismatch" end
    if handle.ownerId ~= nil and _safeString(handle.ownerId) ~= state.ownerId then return false, "vehicle owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then return false, "vehicle generation is stale" end
    if math.floor(_safeNumber(handle.bodyId, 0)) ~= state.bodyId then return false, "vehicle body is stale" end
    if state.disposed then return false, "vehicle is disposed" end
    return true
end

function vehicle.serverInit(identity, definitionId, bodyId, ownerId, capabilities, options)
    local state = vehicle.state
    local resolvedOptions = type(options) == "table" and options or {}
    state.initialized = false
    state.disposed = false
    state.identity = _safeString(identity, "vehicle-instance")
    state.definitionId = _safeString(definitionId, state.identity)
    state.ownerId = _safeString(ownerId, state.identity)
    state.bodyId = math.floor(_safeNumber(bodyId, 0))
    state.capabilities = _capabilities(capabilities)
    state.lifecycle = "spawning"
    state.inputRevision = 0
    state.mountRevision = 0
    state.lastTick = 0.0
    state.health = { shield = 0.0, armor = 0.0, body = 0.0 }
    state.metrics.initCount = state.metrics.initCount + 1
    local adapterReport = nil
    if cm2ShipInstanceAdapterV1 ~= nil and cm2ShipInstanceAdapterV1.state ~= nil
        and cm2ShipInstanceAdapterV1.state.initialized then
        adapterReport = cm2ShipInstanceAdapterV1.getReport()
    elseif cm2ShipInstanceAdapterV1 ~= nil and cm2ShipInstanceAdapterV1.serverInit ~= nil then
        adapterReport = cm2ShipInstanceAdapterV1.serverInit(state.identity, capabilities, state.ownerId)
    end
    state.adapterReport = adapterReport
    state.mode = _safeString((adapterReport or {}).mode, _safeString(resolvedOptions.mode, "local"))
    state.generation = math.max(1, math.floor(_safeNumber((adapterReport or {}).generation, _safeNumber(resolvedOptions.generation, 1))))
    state.initialized = true
    _setLifecycle("active")
    return vehicle.snapshot()
end

function vehicle.handle()
    local state = vehicle.state
    return { protocolVersion = vehicle.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation, bodyId = state.bodyId }
end

function vehicle.validateHandle(handle)
    local valid, errorText = _validHandle(handle)
    if not valid then
        if errorText == "vehicle owner mismatch" then vehicle.state.metrics.ownerRejects = vehicle.state.metrics.ownerRejects + 1
        else vehicle.state.metrics.staleRejects = vehicle.state.metrics.staleRejects + 1 end
    end
    return valid, errorText
end

function vehicle.setLifecycle(handle, lifecycle)
    local valid, errorText = _validHandle(handle)
    if not valid then vehicle.state.metrics.staleRejects = vehicle.state.metrics.staleRejects + 1; return false, errorText end
    if not _setLifecycle(lifecycle) then return false, "invalid vehicle lifecycle" end
    return true
end

function vehicle.setHealth(handle, shield, armor, body)
    local valid, errorText = _validHandle(handle)
    if not valid then vehicle.state.metrics.staleRejects = vehicle.state.metrics.staleRejects + 1; return false, errorText end
    vehicle.state.health = {
        shield = math.max(0.0, _safeNumber(shield, vehicle.state.health.shield)),
        armor = math.max(0.0, _safeNumber(armor, vehicle.state.health.armor)),
        body = math.max(0.0, _safeNumber(body, vehicle.state.health.body)),
    }
    return true
end

function vehicle.setInputRevision(handle, revision)
    local valid, errorText = _validHandle(handle)
    if not valid then vehicle.state.metrics.staleRejects = vehicle.state.metrics.staleRejects + 1; return false, errorText end
    vehicle.state.inputRevision = math.max(0, math.floor(_safeNumber(revision, vehicle.state.inputRevision)))
    return true
end

function vehicle.setMountRevision(handle, revision)
    local valid, errorText = _validHandle(handle)
    if not valid then vehicle.state.metrics.staleRejects = vehicle.state.metrics.staleRejects + 1; return false, errorText end
    vehicle.state.mountRevision = math.max(0, math.floor(_safeNumber(revision, vehicle.state.mountRevision)))
    return true
end

function vehicle.resolveMount(handle, mountId, resolver)
    local valid, errorText = _validHandle(handle)
    if not valid then vehicle.state.metrics.mountResolveRejects = vehicle.state.metrics.mountResolveRejects + 1; return nil, errorText end
    if not vehicle.state.capabilities.mountLookup then vehicle.state.metrics.mountResolveRejects = vehicle.state.metrics.mountResolveRejects + 1; return nil, "mount lookup capability is disabled" end
    if type(resolver) ~= "function" then vehicle.state.metrics.mountResolveRejects = vehicle.state.metrics.mountResolveRejects + 1; return nil, "mount resolver is unavailable" end
    local resolved = resolver(_safeString(mountId))
    if type(resolved) ~= "table" then vehicle.state.metrics.mountResolveRejects = vehicle.state.metrics.mountResolveRejects + 1; return nil, "mount is missing" end
    vehicle.state.metrics.mountResolves = vehicle.state.metrics.mountResolves + 1
    return { identity = vehicle.state.identity, generation = vehicle.state.generation, mountId = _safeString(mountId), value = _clone(resolved) }
end

function vehicle.serverTick(dt, destroyed)
    local state = vehicle.state
    if not state.initialized or state.disposed then return false end
    local delta = math.max(0.0, _safeNumber(dt, 0.0))
    state.lastTick = state.lastTick + delta
    state.metrics.ticks = state.metrics.ticks + 1
    if destroyed then
        _setLifecycle("destroyed")
        if cm2ShipInstanceAdapterV1 ~= nil and cm2ShipInstanceAdapterV1.serverTick ~= nil then cm2ShipInstanceAdapterV1.serverTick(delta, true) end
        state.disposed = true
        _setLifecycle("disposed")
        state.metrics.disposed = state.metrics.disposed + 1
        return false
    end
    if cm2ShipInstanceAdapterV1 ~= nil and cm2ShipInstanceAdapterV1.serverTick ~= nil then cm2ShipInstanceAdapterV1.serverTick(delta, false) end
    if server ~= nil and server.registryShipGetHP ~= nil and state.bodyId ~= 0 then
        local shield, armor, body = server.registryShipGetHP(state.bodyId)
        if shield ~= nil then
            state.health.shield = math.max(0.0, _safeNumber(shield, state.health.shield))
            state.health.armor = math.max(0.0, _safeNumber(armor, state.health.armor))
            state.health.body = math.max(0.0, _safeNumber(body, state.health.body))
            state.metrics.healthReads = state.metrics.healthReads + 1
        end
    end
    return true
end

function vehicle.dispose(reason)
    local state = vehicle.state
    if state.disposed then return false end
    _setLifecycle("disposed")
    state.disposed = true
    state.metrics.disposed = state.metrics.disposed + 1
    if cm2ShipInstanceAdapterV1 ~= nil and cm2ShipInstanceAdapterV1.dispose ~= nil then cm2ShipInstanceAdapterV1.dispose(reason) end
    return true
end

function vehicle.snapshot()
    local state = vehicle.state
    return {
        protocolVersion = vehicle.protocolVersion,
        identity = state.identity,
        definitionId = state.definitionId,
        ownerId = state.ownerId,
        bodyId = state.bodyId,
        generation = state.generation,
        lifecycle = state.lifecycle,
        mode = state.mode,
        disposed = state.disposed,
        health = _clone(state.health),
        inputRevision = state.inputRevision,
        mountRevision = state.mountRevision,
        capabilities = _clone(state.capabilities),
    }
end

function vehicle.getDiagnostics()
    local state = vehicle.state
    return {
        protocolVersion = vehicle.protocolVersion,
        initialized = state.initialized,
        disposed = state.disposed,
        identity = state.identity,
        definitionId = state.definitionId,
        ownerId = state.ownerId,
        bodyId = state.bodyId,
        generation = state.generation,
        lifecycle = state.lifecycle,
        mode = state.mode,
        inputRevision = state.inputRevision,
        mountRevision = state.mountRevision,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
        lifecycleChanges = state.metrics.lifecycleChanges,
        healthReads = state.metrics.healthReads,
        mountResolves = state.metrics.mountResolves,
        mountResolveRejects = state.metrics.mountResolveRejects,
        ticks = state.metrics.ticks,
        disposedCount = state.metrics.disposed,
    }
end
