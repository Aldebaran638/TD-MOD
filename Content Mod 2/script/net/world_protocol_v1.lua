-- Versioned World Host protocol and Owner Lease DTOs.
-- This module is transport-neutral. It defines the boundary for Step 4.2;
-- Step 4.3 will provide the production Host/adapter implementation.

cm2WorldProtocolV1 = cm2WorldProtocolV1 or {}
local protocol = cm2WorldProtocolV1

protocol.protocolVersion = "cm2.world/1"
protocol.messageKinds = {
    register = true,
    unregister = true,
    heartbeat = true,
    command = true,
    snapshot = true,
    delta = true,
    presentation = true,
    lifecycle = true,
}
protocol.capabilities = {
    register = true,
    heartbeat = true,
    command = true,
    snapshotRead = true,
    snapshotWrite = true,
    deltaRead = true,
    presentationPublish = true,
    lifecycleRead = true,
}
protocol.channelBudgets = {
    presentation = { frequencyHz = 60, payloadBytes = 256, reliability = "ambient-coalesce" },
    snapshot = { frequencyHz = 10, payloadBytes = 1024, reliability = "ordered-reliable" },
}
protocol.forbiddenKeys = {
    callback = true,
    functionName = true,
    engineHandle = true,
    bodyHandle = true,
    shapeHandle = true,
    jointHandle = true,
    registryReference = true,
    sharedTable = true,
}

local function _isInteger(value)
    return type(value) == "number" and value == math.floor(value)
end

local function _nonEmptyString(value)
    return type(value) == "string" and value ~= ""
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

local function _hasForbidden(value, seen)
    if type(value) == "function" or type(value) == "userdata" or type(value) == "thread" then return true end
    if type(value) ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for key, child in pairs(value) do
        if protocol.forbiddenKeys[key] or _hasForbidden(child, seen) then return true end
    end
    return false
end

local function _leaseKey(ownerId, generation)
    return tostring(ownerId) .. "@" .. tostring(generation)
end

function protocol.newOwnerLease(ownerId, generation, now, timeout)
    if not _nonEmptyString(ownerId) then return nil, "ownerId must be a non-empty string" end
    if not _isInteger(generation) or generation < 1 then return nil, "generation must be a positive integer" end
    local issuedAt = tonumber(now) or 0
    local duration = tonumber(timeout) or 0
    if duration <= 0 then return nil, "timeout must be positive" end
    return {
        ownerId = ownerId,
        generation = generation,
        issuedAt = issuedAt,
        expiresAt = issuedAt + duration,
        leaseKey = _leaseKey(ownerId, generation),
    }
end

function protocol.validateOwnerLease(lease, now, expectedGeneration)
    if type(lease) ~= "table" then return false, "lease must be a table" end
    if not _nonEmptyString(lease.ownerId) then return false, "lease.ownerId is required" end
    if not _isInteger(lease.generation) or lease.generation < 1 then return false, "lease.generation is invalid" end
    if expectedGeneration ~= nil and lease.generation ~= expectedGeneration then return false, "lease generation is stale" end
    if type(lease.expiresAt) ~= "number" or type(lease.issuedAt) ~= "number" then return false, "lease time bounds are invalid" end
    if lease.expiresAt <= lease.issuedAt then return false, "lease must have positive duration" end
    if lease.leaseKey ~= _leaseKey(lease.ownerId, lease.generation) then return false, "lease key is not canonical" end
    if tonumber(now) ~= nil and tonumber(now) >= lease.expiresAt then return false, "owner lease is expired" end
    return true
end

function protocol.acquireOwnerLease(current, ownerId, generation, now, timeout)
    if current ~= nil then
        local valid = protocol.validateOwnerLease(current, now, generation)
        if valid then return nil, "owner lease already held" end
    end
    return protocol.newOwnerLease(ownerId, generation, now, timeout)
end

function protocol.renewOwnerLease(lease, ownerId, generation, now, timeout)
    local valid, errorText = protocol.validateOwnerLease(lease, now, generation)
    if not valid then return nil, errorText end
    if lease.ownerId ~= ownerId then return nil, "owner lease owner mismatch" end
    return protocol.newOwnerLease(ownerId, generation, now, timeout)
end

function protocol.releaseOwnerLease(lease, ownerId, generation)
    local valid, errorText = protocol.validateOwnerLease(lease, 0, generation)
    if not valid then return false, errorText end
    if lease.ownerId ~= ownerId then return false, "owner lease owner mismatch" end
    return true
end

function protocol.hasCapability(capabilities, capability)
    return type(capabilities) == "table" and capabilities[capability] == true and protocol.capabilities[capability] == true
end

function protocol.newMessage(kind, sourceContext, ownerId, generation, sequence, payload, payloadBytes, capabilities)
    return {
        protocolVersion = protocol.protocolVersion,
        kind = kind,
        source = { contextId = sourceContext, ownerId = ownerId },
        generation = generation,
        sequence = sequence,
        payload = payload,
        payloadBytes = payloadBytes,
        capabilities = capabilities or {},
    }
end

function protocol.validateMessage(value, expectedGeneration, lease, previousSequence, maxPayloadBytes)
    if type(value) ~= "table" then return false, "message must be a table" end
    if value.protocolVersion ~= protocol.protocolVersion then return false, "protocol version is incompatible" end
    if not protocol.messageKinds[value.kind] then return false, "message kind is unsupported" end
    if type(value.source) ~= "table" or not _nonEmptyString(value.source.contextId) or not _nonEmptyString(value.source.ownerId) then return false, "source identity is invalid" end
    if not _isInteger(value.generation) or value.generation < 1 then return false, "message generation is invalid" end
    if expectedGeneration ~= nil and value.generation ~= expectedGeneration then return false, "message generation is stale" end
    if not _isInteger(value.sequence) or value.sequence < 1 then return false, "message sequence is invalid" end
    if previousSequence ~= nil and value.sequence <= previousSequence then return false, "message sequence is duplicate or stale" end
    if type(value.payloadBytes) ~= "number" or value.payloadBytes < 0 or value.payloadBytes ~= math.floor(value.payloadBytes) then return false, "payloadBytes must be a non-negative integer" end
    if maxPayloadBytes ~= nil and value.payloadBytes > maxPayloadBytes then return false, "payload exceeds fixed transport budget" end
    if type(value.capabilities) ~= "table" then return false, "capabilities must be a table" end
    for capability, enabled in pairs(value.capabilities) do
        if enabled == true and not protocol.capabilities[capability] then return false, "unknown capability" end
    end
    if lease ~= nil then
        local leaseValid, leaseError = protocol.validateOwnerLease(lease, nil, expectedGeneration)
        if not leaseValid then return false, leaseError end
        if lease.ownerId ~= value.source.ownerId then return false, "message owner does not hold lease" end
    end
    if _hasForbidden(value.payload) then return false, "payload contains forbidden runtime reference" end
    return true
end

function protocol.newTransport(capacity)
    local fixedCapacity = math.max(1, math.floor(tonumber(capacity) or 1))
    return { capacity = fixedCapacity, head = 1, tail = 1, entries = {}, accepted = 0, dropped = 0 }
end

function protocol.enqueue(transport, value)
    if type(transport) ~= "table" or type(transport.capacity) ~= "number" then return false, "transport is invalid" end
    if transport.tail - transport.head >= transport.capacity then
        transport.dropped = transport.dropped + 1
        return false, "queue overflow"
    end
    transport.entries[transport.tail] = _clone(value)
    transport.tail = transport.tail + 1
    transport.accepted = transport.accepted + 1
    return true
end

function protocol.dequeue(transport)
    if type(transport) ~= "table" or transport.head >= transport.tail then return nil, "queue is empty" end
    local value = transport.entries[transport.head]
    transport.entries[transport.head] = nil
    transport.head = transport.head + 1
    return value
end

function protocol.queueDepth(transport)
    if type(transport) ~= "table" then return 0 end
    return math.max(0, transport.tail - transport.head)
end

function protocol.getReport(transport)
    return {
        capacity = transport and transport.capacity or 0,
        depth = protocol.queueDepth(transport),
        accepted = transport and transport.accepted or 0,
        dropped = transport and transport.dropped or 0,
    }
end
