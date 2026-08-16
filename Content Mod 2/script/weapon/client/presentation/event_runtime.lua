---@diagnostic disable: undefined-global

client = client or {}

local function _newRing(capacity)
    return { capacity = capacity, slots = {}, head = 1, tail = 1, count = 0 }
end

local function _telemetry(eventName, data)
    if client.cm2TelemetryRecord ~= nil then
        client.cm2TelemetryRecord(eventName, data)
    end
end

client.presentationEventRuntime = client.presentationEventRuntime or {
    lastSequence = 0,
    lastSequenceBySource = {},
    lastSourceSequenceBySource = {},
    accepted = 0,
    rejected = 0,
    duplicate = 0,
    gap = 0,
    outOfOrder = 0,
    droppedCritical = 0,
    droppedAmbient = 0,
    disposed = 0,
    cancelled = 0,
    critical = _newRing(128),
    ambient = _newRing(32),
}

local _criticalKinds = {
    projectile = true,
    impact = true,
    craft_launch = true,
    craft_recover = true,
}

local function _sourceKey(value)
    return tostring(((value or {}).source or {}).id or "world")
end

local function _eventIsCritical(value)
    local kind = tostring(value.kind or "")
    if _criticalKinds[kind] then return true end
    if kind == "charge" then
        local phase = tostring(((value.payload or {}).phase) or "")
        return phase == "stop" or phase == "charge-stop"
    end
    return false
end

local function _ambientKey(value)
    local source = _sourceKey(value)
    local effect = tostring(((value.effect or {}).id) or ((value.weapon or {}).id) or "")
    return source .. "|" .. effect .. "|" .. tostring(value.kind or "ambient")
end

local function _ringPush(ring, value)
    if ring.count >= ring.capacity then return false end
    ring.slots[ring.tail] = value
    ring.tail = (ring.tail % ring.capacity) + 1
    ring.count = ring.count + 1
    return true
end

local function _ringPop(ring)
    if ring.count <= 0 then return nil end
    local value = ring.slots[ring.head]
    ring.slots[ring.head] = nil
    ring.head = (ring.head % ring.capacity) + 1
    ring.count = ring.count - 1
    return value
end

local function _ringRemoveOwner(ring, sourceId)
    local kept = _newRing(ring.capacity)
    local removed = 0
    while ring.count > 0 do
        local value = _ringPop(ring)
        if _sourceKey(value) == tostring(sourceId) then
            removed = removed + 1
        else
            _ringPush(kept, value)
        end
    end
    ring.head, ring.tail, ring.count, ring.slots = kept.head, kept.tail, kept.count, kept.slots
    return removed
end

local function _ringCollectSources(ring, sources)
    local index = ring.head
    for _ = 1, ring.count do
        local value = ring.slots[index]
        if value ~= nil then sources[_sourceKey(value)] = true end
        index = (index % ring.capacity) + 1
    end
end

local function _ambientReplaceOrPush(ring, value)
    local key = _ambientKey(value)
    local index = ring.head
    for _ = 1, ring.count do
        local current = ring.slots[index]
        if current ~= nil and _ambientKey(current) == key then
            ring.slots[index] = value
            return true, true
        end
        index = (index % ring.capacity) + 1
    end
    return _ringPush(ring, value), false
end

function client.receiveWeaponPresentationEventV1(value)
    local state = client.presentationEventRuntime
    -- The ring owns duplicate/gap ordering diagnostics per source; do not use
    -- one global previous-sequence guard here because independent sources may
    -- legitimately interleave their events.
    local decoded, errorText = cm2PresentationEventV1.decode(value)
    if decoded == nil then
        state.rejected = state.rejected + 1
        _telemetry("presentation_ring_rejected", { reason = tostring(errorText or "invalid event") })
        return false, errorText
    end
    local source = _sourceKey(decoded)
    local previousSourceSequence = state.lastSequenceBySource[source]
    local sourceSequence = tonumber(((decoded.extensions or {}).sourceSequence))
    local previousLocalSequence = state.lastSourceSequenceBySource[source]
    if previousSourceSequence ~= nil then
        if decoded.sequence == previousSourceSequence then
            state.duplicate = state.duplicate + 1
            _telemetry("presentation_ring_diagnostic", {
                action = "duplicate",
                source_id = source,
                sequence = decoded.sequence,
            })
            return false, "duplicate source sequence"
        elseif decoded.sequence < previousSourceSequence then
            state.outOfOrder = state.outOfOrder + 1
            _telemetry("presentation_ring_diagnostic", {
                action = "out-of-order",
                source_id = source,
                sequence = decoded.sequence,
                previous_sequence = previousSourceSequence,
            })
            return false, "out-of-order source sequence"
        end
    end
    if sourceSequence ~= nil and sourceSequence == math.floor(sourceSequence) and sourceSequence > 0 then
        if previousLocalSequence ~= nil and sourceSequence > previousLocalSequence + 1 then
            state.gap = state.gap + (sourceSequence - previousLocalSequence - 1)
            _telemetry("presentation_ring_diagnostic", {
                action = "gap",
                source_id = source,
                sequence = sourceSequence,
                previous_sequence = previousLocalSequence,
                missing = sourceSequence - previousLocalSequence - 1,
            })
        end
        state.lastSourceSequenceBySource[source] = sourceSequence
    end
    state.lastSequenceBySource[source] = decoded.sequence
    state.lastSequence = math.max(state.lastSequence, decoded.sequence)
    state.accepted = state.accepted + 1
    local isCritical = _eventIsCritical(decoded)
    if isCritical then
        if not _ringPush(state.critical, decoded) then
            state.droppedCritical = state.droppedCritical + 1
            _telemetry("presentation_ring_drop", {
                class = "critical",
                source_id = source,
                sequence = decoded.sequence,
                kind = decoded.kind,
            })
            return false, "critical event ring is full"
        end
    else
        local pushed, replaced = _ambientReplaceOrPush(state.ambient, decoded)
        if not pushed and not replaced then
            state.droppedAmbient = state.droppedAmbient + 1
            _telemetry("presentation_ring_drop", {
                class = "ambient",
                source_id = source,
                sequence = decoded.sequence,
                kind = decoded.kind,
            })
        end
    end
    return true
end

function client.presentationEventGetDiagnostics()
    local state = client.presentationEventRuntime
    return {
        lastSequence = state.lastSequence,
        accepted = state.accepted,
        rejected = state.rejected,
        duplicate = state.duplicate,
        gap = state.gap,
        outOfOrder = state.outOfOrder,
        droppedCritical = state.droppedCritical,
        droppedAmbient = state.droppedAmbient,
        disposed = state.disposed,
        cancelled = state.cancelled,
        criticalQueued = state.critical.count,
        ambientQueued = state.ambient.count,
        criticalCapacity = state.critical.capacity,
        ambientCapacity = state.ambient.capacity,
    }
end

function client.presentationEventDrain()
    local state = client.presentationEventRuntime
    local result = {}
    local criticalCount, ambientCount = 0, 0
    local sequences, kinds = {}, {}
    while state.critical.count > 0 do
        local value = _ringPop(state.critical)
        result[#result + 1] = value
        criticalCount = criticalCount + 1
        sequences[#sequences + 1] = value.sequence
        kinds[#kinds + 1] = value.kind
    end
    while state.ambient.count > 0 do
        local value = _ringPop(state.ambient)
        result[#result + 1] = value
        ambientCount = ambientCount + 1
        sequences[#sequences + 1] = value.sequence
        kinds[#kinds + 1] = value.kind
    end
    if #result > 0 then
        _telemetry("presentation_ring_drain", {
            critical_count = criticalCount,
            ambient_count = ambientCount,
            count = #result,
            sequences = sequences,
            kinds = kinds,
        })
    end
    return result
end

function client.presentationEventDisposeOwner(sourceId)
    local state = client.presentationEventRuntime
    local removed = _ringRemoveOwner(state.critical, sourceId)
    removed = removed + _ringRemoveOwner(state.ambient, sourceId)
    state.disposed = state.disposed + removed
    if removed > 0 then state.cancelled = state.cancelled + 1 end
    _telemetry("presentation_ring_cancel", {
        source_id = tostring(sourceId),
        removed = removed,
        cancelled = removed > 0,
    })
    return removed
end

function client.presentationEventDisposeAll()
    local state = client.presentationEventRuntime
    local sources = {}
    _ringCollectSources(state.critical, sources)
    _ringCollectSources(state.ambient, sources)
    local removed = 0
    for sourceId, _ in pairs(sources) do
        removed = removed + client.presentationEventDisposeOwner(sourceId)
    end
    if next(sources) == nil then
        _telemetry("presentation_ring_cancel", {
            source_id = "*",
            removed = 0,
            cancelled = false,
            owner_scope = "client",
        })
    end
    return removed
end
