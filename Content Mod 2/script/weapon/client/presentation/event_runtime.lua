---@diagnostic disable: undefined-global

client = client or {}

local function _newRing(capacity)
    return { capacity = capacity, slots = {}, head = 1, tail = 1, count = 0 }
end

client.presentationEventRuntime = client.presentationEventRuntime or {
    lastSequence = 0,
    lastSequenceBySource = {},
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
        return false, errorText
    end
    local source = _sourceKey(decoded)
    local previousSourceSequence = state.lastSequenceBySource[source]
    if previousSourceSequence ~= nil then
        if decoded.sequence == previousSourceSequence then
            state.duplicate = state.duplicate + 1
            return false, "duplicate source sequence"
        elseif decoded.sequence < previousSourceSequence then
            state.outOfOrder = state.outOfOrder + 1
            return false, "out-of-order source sequence"
        elseif decoded.sequence > previousSourceSequence + 1 then
            state.gap = state.gap + (decoded.sequence - previousSourceSequence - 1)
        end
    end
    state.lastSequenceBySource[source] = decoded.sequence
    state.lastSequence = math.max(state.lastSequence, decoded.sequence)
    state.accepted = state.accepted + 1
    if _eventIsCritical(decoded) then
        if not _ringPush(state.critical, decoded) then
            state.droppedCritical = state.droppedCritical + 1
            return false, "critical event ring is full"
        end
    else
        local pushed, replaced = _ambientReplaceOrPush(state.ambient, decoded)
        if not pushed and not replaced then state.droppedAmbient = state.droppedAmbient + 1 end
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
    while state.critical.count > 0 do result[#result + 1] = _ringPop(state.critical) end
    while state.ambient.count > 0 do result[#result + 1] = _ringPop(state.ambient) end
    return result
end

function client.presentationEventDisposeOwner(sourceId)
    local state = client.presentationEventRuntime
    local removed = _ringRemoveOwner(state.critical, sourceId)
    removed = removed + _ringRemoveOwner(state.ambient, sourceId)
    state.disposed = state.disposed + removed
    if removed > 0 then state.cancelled = state.cancelled + 1 end
    return removed
end
