-- Minimal Scene World Host skeleton for Gate 4.3.
-- It owns only registration, clock, generation and diagnostics. Weapon and
-- damage authority stays in the existing ship adapter/runtime for now.

cm2WorldHostV1 = cm2WorldHostV1 or {}
local host = cm2WorldHostV1

host.protocolVersion = "cm2.world/1"
host.rootKey = "cm2/world-host/v1"
host.maxInstances = 12
host.heartbeatInterval = 0.5

local function _newState()
    return {
        initialized = false,
        mode = "local",
        hostId = "",
        generation = 0,
        lease = nil,
        elapsed = 0.0,
        heartbeat = 0,
        tickCount = 0,
        registerCount = 0,
        unregisterCount = 0,
        rejectedCount = 0,
        fallbackCount = 0,
        dense = {},
        byId = {},
        metrics = { queueDepth = 0, queueDropped = 0, activeInstances = 0 },
    }
end

host.state = host.state or _newState()
local state = host.state

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback end
    return value
end

local function _now()
    if GetTime ~= nil then return GetTime() end
    return 0.0
end

local function _readString(key, fallback)
    if GetString == nil then return fallback end
    return _safeString(GetString(key), fallback)
end

local function _readInt(key, fallback)
    if GetInt == nil then return fallback end
    return math.floor(_safeNumber(GetInt(key), fallback))
end

local function _readBool(key, fallback)
    if GetBool == nil then return fallback end
    return GetBool(key)
end

local function _writeString(key, value)
    if SetString ~= nil then SetString(key, tostring(value or ""), true) end
end

local function _writeInt(key, value)
    if SetInt ~= nil then SetInt(key, math.floor(_safeNumber(value, 0)), true) end
end

local function _writeBool(key, value)
    if SetBool ~= nil then SetBool(key, value and true or false, true) end
end

local function _announcementPrefix(slot)
    return host.rootKey .. "/announcement/slot/" .. tostring(slot)
end

local function _consumeAnnouncements()
    if host.state.mode ~= "content-host" then return end
    for slot = 1, host.maxInstances do
        local prefix = _announcementPrefix(slot)
        local id = _readString(prefix .. "/id", "")
        if id ~= "" then host.observeAnnouncement(slot) end
    end
end

local function _publishStatus()
    local state = host.state
    if state.mode ~= "content-host" then return end
    _writeString(host.rootKey .. "/protocolVersion", host.protocolVersion)
    _writeString(host.rootKey .. "/hostId", state.hostId)
    _writeString(host.rootKey .. "/mode", state.mode)
    _writeInt(host.rootKey .. "/generation", state.generation)
    _writeInt(host.rootKey .. "/heartbeat", state.heartbeat)
    _writeInt(host.rootKey .. "/activeInstances", #state.dense)
    _writeBool(host.rootKey .. "/ready", state.initialized and state.mode == "content-host")
end

local function _firstFreeIndex()
    for index = 1, host.maxInstances do
        if state.dense[index] == nil then return index end
    end
    return nil
end

function host.serverInit(requestedMode, hostId)
    state = host.state
    if state.initialized then return host.getReport() end
    local mode = _safeString(requestedMode, "local")
    if mode ~= "content-host" then mode = "local" end
    state.mode = mode
    state.hostId = _safeString(hostId, "scene-host-1")
    local previousGeneration = (mode == "content-host") and _readInt(host.rootKey .. "/generation", 0) or 0
    state.generation = math.max(1, previousGeneration + 1)
    state.lease = {
        ownerId = state.hostId,
        generation = state.generation,
        issuedAt = _now(),
        expiresAt = _now() + 2.0,
    }
    state.initialized = true
    state.elapsed = 0.0
    state.heartbeat = 0
    state.tickCount = 0
    state.registerCount = 0
    state.unregisterCount = 0
    state.rejectedCount = 0
    state.fallbackCount = 0
    state.dense = {}
    state.byId = {}
    state.metrics = { queueDepth = 0, queueDropped = 0, activeInstances = 0 }
    _publishStatus()
    return host.getReport()
end

function host.serverTick(dt)
    if not state.initialized then return false, "host is not initialized" end
    local delta = math.max(0.0, _safeNumber(dt, 0.0))
    state.elapsed = state.elapsed + delta
    state.tickCount = state.tickCount + 1
    if state.elapsed >= host.heartbeatInterval then
        state.elapsed = state.elapsed - host.heartbeatInterval
        state.heartbeat = state.heartbeat + 1
        state.lease.expiresAt = _now() + 2.0
        _publishStatus()
    end
    _consumeAnnouncements()
    state.metrics.activeInstances = #state.dense
    return true
end

function host.clientInit()
    local advertisedMode = _readString(host.rootKey .. "/mode", "local")
    local ready = _readBool(host.rootKey .. "/ready", false)
    return {
        mode = (ready and advertisedMode == "content-host") and "content-host" or "local",
        generation = _readInt(host.rootKey .. "/generation", 0),
        hostId = _readString(host.rootKey .. "/hostId", ""),
    }
end

function host.clientTick(_dt)
    return host.clientInit()
end

function host.isReady()
    return state.initialized and state.mode == "content-host"
end

function host.mode()
    return state.mode
end

function host.generation()
    return state.generation
end

function host.registerInstance(instanceId, ownerId, capabilities)
    if not state.initialized then return nil, "host is not initialized" end
    if type(instanceId) ~= "string" or instanceId == "" then state.rejectedCount = state.rejectedCount + 1; return nil, "instanceId is required" end
    if type(ownerId) ~= "string" or ownerId == "" then state.rejectedCount = state.rejectedCount + 1; return nil, "ownerId is required" end
    if state.byId[instanceId] ~= nil then state.rejectedCount = state.rejectedCount + 1; return nil, "duplicate instance registration" end
    local index = _firstFreeIndex()
    if index == nil then state.rejectedCount = state.rejectedCount + 1; return nil, "instance capacity exhausted" end
    local entry = {
        id = instanceId,
        ownerId = ownerId,
        index = index,
        generation = state.generation,
        capabilities = capabilities or {},
        heartbeat = 0,
        active = true,
        slot = 0,
    }
    state.dense[index] = instanceId
    state.byId[instanceId] = entry
    state.registerCount = state.registerCount + 1
    state.metrics.activeInstances = #state.dense
    return {
        id = entry.id,
        index = entry.index,
        generation = entry.generation,
        mode = state.mode,
    }
end

function host.observeAnnouncement(slot)
    if not state.initialized or state.mode ~= "content-host" then return false, "host is not content-host" end
    local numericSlot = math.floor(_safeNumber(slot, 0))
    if numericSlot < 1 or numericSlot > host.maxInstances then state.rejectedCount = state.rejectedCount + 1; return false, "announcement slot is invalid" end
    local prefix = _announcementPrefix(numericSlot)
    local instanceId = _readString(prefix .. "/id", "")
    if instanceId == "" then return false, "announcement is empty" end
    local ownerId = _readString(prefix .. "/owner", "")
    local generation = _readInt(prefix .. "/generation", 0)
    local active = _readBool(prefix .. "/active", false)
    local entry = state.byId[instanceId]
    if not active then
        if entry ~= nil and entry.slot == numericSlot then
            return host.unregisterInstance(instanceId, ownerId, generation, "adapter-unregister")
        end
        return true
    end
    if generation ~= state.generation then state.rejectedCount = state.rejectedCount + 1; return false, "announcement generation is stale" end
    if entry == nil then
        local registration, errorText = host.registerInstance(instanceId, ownerId, {})
        if registration == nil then return false, errorText end
        state.byId[instanceId].slot = numericSlot
        return true
    end
    entry.slot = numericSlot
    return host.heartbeatInstance(instanceId, ownerId, generation)
end

function host.heartbeatInstance(instanceId, ownerId, generation)
    local entry = state.byId[instanceId]
    if entry == nil then state.rejectedCount = state.rejectedCount + 1; return false, "unknown instance" end
    if entry.ownerId ~= ownerId then state.rejectedCount = state.rejectedCount + 1; return false, "owner mismatch" end
    if entry.generation ~= generation or generation ~= state.generation then state.rejectedCount = state.rejectedCount + 1; return false, "stale generation" end
    entry.heartbeat = entry.heartbeat + 1
    return true
end

function host.unregisterInstance(instanceId, ownerId, generation, _reason)
    local entry = state.byId[instanceId]
    if entry == nil then return false, "unknown instance" end
    if entry.ownerId ~= ownerId then state.rejectedCount = state.rejectedCount + 1; return false, "owner mismatch" end
    if entry.generation ~= generation then state.rejectedCount = state.rejectedCount + 1; return false, "stale generation" end
    local lastIndex = #state.dense
    local removedIndex = entry.index
    local movedId = state.dense[lastIndex]
    if movedId ~= nil and removedIndex ~= lastIndex then
        state.dense[removedIndex] = movedId
        state.byId[movedId].index = removedIndex
    end
    state.dense[lastIndex] = nil
    state.byId[instanceId] = nil
    state.unregisterCount = state.unregisterCount + 1
    state.metrics.activeInstances = #state.dense
    return true
end

function host.dispose(reason)
    if not state.initialized then return false end
    state.generation = state.generation + 1
    state.dense = {}
    state.byId = {}
    state.initialized = false
    if state.mode == "content-host" then
        _writeString(host.rootKey .. "/disposeReason", _safeString(reason, "scene-unload"))
        _writeBool(host.rootKey .. "/ready", false)
        _writeInt(host.rootKey .. "/generation", state.generation)
    end
    return true
end

function host.snapshot()
    local instances = {}
    for index, instanceId in ipairs(state.dense) do
        local entry = state.byId[instanceId]
        instances[index] = {
            id = entry.id,
            ownerId = entry.ownerId,
            index = entry.index,
            generation = entry.generation,
            slot = entry.slot,
            heartbeat = entry.heartbeat,
            active = entry.active,
        }
    end
    return { protocolVersion = host.protocolVersion, hostId = state.hostId, mode = state.mode, generation = state.generation, instances = instances }
end

function host.getReport()
    return {
        protocolVersion = host.protocolVersion,
        hostId = state.hostId,
        mode = state.mode,
        initialized = state.initialized,
        generation = state.generation,
        tickCount = state.tickCount,
        heartbeat = state.heartbeat,
        registerCount = state.registerCount,
        unregisterCount = state.unregisterCount,
        rejectedCount = state.rejectedCount,
        fallbackCount = state.fallbackCount,
        activeInstances = #state.dense,
        maxInstances = host.maxInstances,
        queueDepth = state.metrics.queueDepth,
        queueDropped = state.metrics.queueDropped,
    }
end
