-- Scene-wide Presentation/Audio ownership facade for Gate 4.4.
-- The root Content Host owns this state. Ship contexts only publish bounded
-- event announcements; legacy local rendering remains the explicit fallback.

cm2PresentationAudioHostV1 = cm2PresentationAudioHostV1 or {}
local scene = cm2PresentationAudioHostV1

scene.protocolVersion = "cm2.world.presentation/1"
scene.rootKey = "cm2/world-presentation/v1"
scene.criticalCapacity = 64
scene.ambientCapacity = 128
scene.eventSlots = 32

local function _newState()
    return {
        initialized = false,
        mode = "local",
        ownerId = "",
        generation = 0,
        critical = { head = 1, tail = 1, entries = {} },
        ambient = { head = 1, tail = 1, entries = {}, byKey = {} },
        lastSequence = {},
        resources = {},
        latency = {},
        metrics = {
            effectPlayerOwnerCount = 0,
            audioVoiceOwnerCount = 0,
            resourceCacheOwnerCount = 0,
            accepted = 0,
            criticalAccepted = 0,
            ambientAccepted = 0,
            criticalDropped = 0,
            ambientDropped = 0,
            ambientCoalesced = 0,
            duplicateRejected = 0,
            staleRejected = 0,
            localFallbackBypass = 0,
            drained = 0,
        },
    }
end

scene.state = scene.state or _newState()

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback end
    return value
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

local function _now()
    if GetTime ~= nil then return GetTime() end
    return 0.0
end

local function _ringDepth(ring)
    return math.max(0, ring.tail - ring.head)
end

local function _ringPush(ring, capacity, value)
    if _ringDepth(ring) >= capacity then return false end
    ring.entries[ring.tail] = value
    ring.tail = ring.tail + 1
    return true
end

local function _ringPop(ring)
    if ring.head >= ring.tail then return nil end
    local value = ring.entries[ring.head]
    ring.entries[ring.head] = nil
    ring.head = ring.head + 1
    return value
end

local function _recordLatency(emittedAt)
    local value = math.max(0.0, _now() - _safeNumber(emittedAt, _now()))
    local samples = scene.state.latency
    samples[#samples + 1] = value
    if #samples > 128 then table.remove(samples, 1) end
end

local function _latencyP95()
    local copy = {}
    for index, value in ipairs(scene.state.latency) do copy[index] = value end
    table.sort(copy)
    if #copy == 0 then return 0.0 end
    local index = math.max(1, math.ceil(#copy * 0.95))
    return copy[index]
end

local function _resetQueues()
    local state = scene.state
    state.critical = { head = 1, tail = 1, entries = {} }
    state.ambient = { head = 1, tail = 1, entries = {}, byKey = {} }
end

local function _eventSlotPrefix(slot)
    return scene.rootKey .. "/slot/" .. tostring(slot)
end

local function _publishHostStatus()
    local state = scene.state
    if SetString ~= nil then SetString(scene.rootKey .. "/owner", state.ownerId, true); SetString(scene.rootKey .. "/mode", state.mode, true) end
    if SetInt ~= nil then SetInt(scene.rootKey .. "/generation", state.generation, true) end
    if SetBool ~= nil then SetBool(scene.rootKey .. "/ready", state.initialized and state.mode == "content-host", true) end
end

function scene.clientInit(requestedMode, generation)
    local state = scene.state
    if state.initialized then return scene.getDiagnostics() end
    local mode = _safeString(requestedMode, "local")
    if mode ~= "content-host" then mode = "local" end
    state.mode = mode
    state.ownerId = "scene-presentation-host"
    state.generation = math.max(1, math.floor(_safeNumber(generation, _readInt("cm2/world-host/v1/generation", 1))))
    state.initialized = true
    state.metrics.effectPlayerOwnerCount = 1
    state.metrics.audioVoiceOwnerCount = 1
    state.metrics.resourceCacheOwnerCount = 1
    _resetQueues()
    state.lastSequence = {}
    state.resources = {}
    state.latency = {}
    if client ~= nil and client.effectPlayer ~= nil and client.effectPlayer.init ~= nil then client.effectPlayer.init(128) end
    _publishHostStatus()
    return scene.getDiagnostics()
end

function scene.clientTick(dt)
    if not scene.state.initialized then return false, "presentation host is not initialized" end
    scene.consumeAnnouncements()
    local elapsed = math.max(0.0, _safeNumber(dt, 0.0))
    local budget = math.max(1, math.floor(elapsed * 240.0) + 1)
    for _index = 1, budget do
        local event = _ringPop(scene.state.critical) or _ringPop(scene.state.ambient)
        if event == nil then break end
        scene.state.metrics.drained = scene.state.metrics.drained + 1
        _recordLatency(event.emittedAt)
    end
    return true
end

function scene.submitEvent(event)
    local state = scene.state
    if not state.initialized then return false, "presentation host is not initialized" end
    if type(event) ~= "table" then return false, "event must be a table" end
    local source = _safeString(event.sourceId, "")
    local sequence = math.floor(_safeNumber(event.sequence, 0))
    if source == "" or sequence < 1 then return false, "event identity is invalid" end
    local last = state.lastSequence[source] or 0
    if sequence <= last then state.metrics.duplicateRejected = state.metrics.duplicateRejected + 1; return false, "duplicate or stale presentation event" end
    if event.generation ~= nil and math.floor(_safeNumber(event.generation, 0)) ~= state.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return false, "stale presentation generation" end
    state.lastSequence[source] = sequence
    event = {
        sourceId = source,
        sequence = sequence,
        generation = state.generation,
        kind = _safeString(event.kind, "ambient"),
        coalesceKey = _safeString(event.coalesceKey, source .. ":" .. tostring(event.kind or "ambient")),
        critical = event.critical == true,
        emittedAt = _safeNumber(event.emittedAt, _now()),
        effectId = event.effectId,
        anchorId = event.anchorId,
    }
    if event.critical then
        if not _ringPush(state.critical, scene.criticalCapacity, event) then state.metrics.criticalDropped = state.metrics.criticalDropped + 1; return false, "critical presentation queue full" end
        state.metrics.criticalAccepted = state.metrics.criticalAccepted + 1
    else
        local existing = state.ambient.byKey[event.coalesceKey]
        if existing ~= nil then
            state.ambient.entries[existing] = event
            state.metrics.ambientCoalesced = state.metrics.ambientCoalesced + 1
        elseif not _ringPush(state.ambient, scene.ambientCapacity, event) then
            state.metrics.ambientDropped = state.metrics.ambientDropped + 1
            return false, "ambient presentation queue full"
        else
            state.ambient.byKey[event.coalesceKey] = state.ambient.tail - 1
            state.metrics.ambientAccepted = state.metrics.ambientAccepted + 1
        end
    end
    state.metrics.accepted = state.metrics.accepted + 1
    return true
end

function scene.consumeAnnouncements()
    if not scene.state.initialized or scene.state.mode ~= "content-host" then return 0 end
    local consumed = 0
    for slot = 1, scene.eventSlots do
        local prefix = _eventSlotPrefix(slot)
        if _readBool(prefix .. "/active", false) then
            local event = {
                sourceId = _readString(prefix .. "/source", ""),
                sequence = _readInt(prefix .. "/sequence", 0),
                generation = _readInt(prefix .. "/generation", 0),
                kind = _readString(prefix .. "/kind", "ambient"),
                coalesceKey = _readString(prefix .. "/coalesceKey", ""),
                critical = _readBool(prefix .. "/critical", false),
                emittedAt = _safeNumber(_readString(prefix .. "/emittedAt", "0"), 0.0),
                effectId = _readString(prefix .. "/effectId", ""),
                anchorId = _readString(prefix .. "/anchorId", ""),
            }
            if scene.submitEvent(event) then consumed = consumed + 1 end
        end
    end
    return consumed
end

function scene.sceneReload()
    local state = scene.state
    if not state.initialized then return false end
    _resetQueues()
    state.lastSequence = {}
    state.resources = {}
    state.latency = {}
    return true
end

function scene.getDiagnostics()
    local state = scene.state
    return {
        protocolVersion = scene.protocolVersion,
        initialized = state.initialized,
        mode = state.mode,
        ownerId = state.ownerId,
        generation = state.generation,
        effectPlayerOwnerCount = state.metrics.effectPlayerOwnerCount,
        audioVoiceOwnerCount = state.metrics.audioVoiceOwnerCount,
        resourceCacheOwnerCount = state.metrics.resourceCacheOwnerCount,
        criticalDepth = _ringDepth(state.critical),
        ambientDepth = _ringDepth(state.ambient),
        accepted = state.metrics.accepted,
        criticalDropped = state.metrics.criticalDropped,
        ambientDropped = state.metrics.ambientDropped,
        ambientCoalesced = state.metrics.ambientCoalesced,
        duplicateRejected = state.metrics.duplicateRejected,
        staleRejected = state.metrics.staleRejected,
        localFallbackBypass = state.metrics.localFallbackBypass,
        latencyP95 = _latencyP95(),
        drained = state.metrics.drained,
    }
end
