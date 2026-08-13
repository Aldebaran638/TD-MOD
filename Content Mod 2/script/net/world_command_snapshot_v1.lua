-- Versioned multiplayer Command/Snapshot boundary for Gate 4.6.
-- Commands are client intents; snapshots/acks are server facts. No raw
-- definitions, engine handles or arbitrary effect callbacks cross this API.

cm2WorldMultiplayerV1 = cm2WorldMultiplayerV1 or {}
local multiplayer = cm2WorldMultiplayerV1

multiplayer.protocolVersion = "cm2.world.multiplayer/1"
multiplayer.commandKinds = { input = true, loadout = true, target = true, fireIntent = true }
multiplayer.snapshotKinds = { lifecycle = true, shot = true, damage = true, snapshot = true, delta = true, presentation = true }
multiplayer.stableKinds = { lifecycle = true, snapshot = true, delta = true }
multiplayer.forbiddenKeys = {
    definition = true,
    rawDefinition = true,
    engineHandle = true,
    bodyHandle = true,
    shapeHandle = true,
    jointHandle = true,
    callback = true,
    functionName = true,
    effect = true,
}
multiplayer.maxCommandBytes = 512
multiplayer.maxCommandsPerWindow = 30
multiplayer.rateWindowSeconds = 1.0
multiplayer.commandQueueCapacity = 32
multiplayer.snapshotQueueCapacity = 64

local function _newState()
    return {
        initialized = false,
        generation = 0,
        revision = 0,
        commandSequence = 0,
        snapshotSequence = 0,
        sessions = {},
        lastStableSnapshot = nil,
        destroyed = {},
        seenDamage = {},
        metrics = {
            sessions = 0,
            acceptedCommands = 0,
            rejectedCommands = 0,
            staleRejected = 0,
            ownerRejected = 0,
            revisionRejected = 0,
            cooldownRejected = 0,
            fitRejected = 0,
            targetRejected = 0,
            malformedRejected = 0,
            versionRejected = 0,
            rateRejected = 0,
            transientPublished = 0,
            stablePublished = 0,
            duplicateDamageRejected = 0,
            destroyedResurrectionRejected = 0,
            lateJoinSnapshots = 0,
            reconnects = 0,
            networkBytesIn = 0,
            networkBytesOut = 0,
            commandQueueDepth = 0,
            commandQueueHighWatermark = 0,
            snapshotQueueDepth = 0,
            snapshotQueueHighWatermark = 0,
            transientReplaySuppressed = 0,
        },
    }
end

multiplayer.state = multiplayer.state or _newState()

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback end
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

local function _containsForbidden(value, seen)
    if type(value) == "function" or type(value) == "userdata" or type(value) == "thread" then return true end
    if type(value) ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for key, child in pairs(value) do
        if multiplayer.forbiddenKeys[key] or _containsForbidden(child, seen) then return true end
    end
    return false
end

local function _session(state, sessionId)
    return state.sessions[_safeString(sessionId, "")]
end

function multiplayer.serverInit(generation)
    local state = multiplayer.state
    if state.initialized then return multiplayer.getDiagnostics() end
    state.initialized = true
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.revision = 1
    state.commandSequence = 0
    state.snapshotSequence = 0
    state.sessions = {}
    state.lastStableSnapshot = nil
    state.destroyed = {}
    state.seenDamage = {}
    state.metrics = {
        sessions = 0, acceptedCommands = 0, rejectedCommands = 0, staleRejected = 0,
        ownerRejected = 0, revisionRejected = 0, cooldownRejected = 0, fitRejected = 0,
        targetRejected = 0, malformedRejected = 0, versionRejected = 0, rateRejected = 0,
        transientPublished = 0, stablePublished = 0, duplicateDamageRejected = 0,
        destroyedResurrectionRejected = 0, lateJoinSnapshots = 0, reconnects = 0,
        networkBytesIn = 0, networkBytesOut = 0, commandQueueDepth = 0,
        commandQueueHighWatermark = 0, snapshotQueueDepth = 0,
        snapshotQueueHighWatermark = 0, transientReplaySuppressed = 0,
    }
    return multiplayer.getDiagnostics()
end

function multiplayer.negotiateVersion(clientVersion, compatibleVersions)
    if clientVersion == multiplayer.protocolVersion then return { accepted = true, mode = "exact", protocolVersion = multiplayer.protocolVersion } end
    if type(compatibleVersions) == "table" then
        for _, version in ipairs(compatibleVersions) do
            if version == multiplayer.protocolVersion then return { accepted = true, mode = "declared-compatible", protocolVersion = multiplayer.protocolVersion } end
        end
    end
    multiplayer.state.metrics.versionRejected = multiplayer.state.metrics.versionRejected + 1
    return nil, "protocol version is incompatible"
end

function multiplayer.registerSession(sessionId, ownerId, clientVersion, compatibleVersions)
    local state = multiplayer.state
    if not state.initialized then return nil, "server is not initialized" end
    local id = _safeString(sessionId, "")
    local owner = _safeString(ownerId, "")
    if id == "" or owner == "" then state.metrics.malformedRejected = state.metrics.malformedRejected + 1; return nil, "session identity is required" end
    local negotiation, errorText = multiplayer.negotiateVersion(clientVersion, compatibleVersions)
    if negotiation == nil then return nil, errorText end
    local existing = state.sessions[id]
    if existing ~= nil and existing.ownerId ~= owner then state.metrics.ownerRejected = state.metrics.ownerRejected + 1; return nil, "session owner mismatch" end
    if existing == nil then
        existing = { sessionId = id, ownerId = owner, generation = state.generation, lastSequence = 0, rateWindowStart = 0.0, rateCount = 0, cooldownUntil = 0.0, connected = true, epoch = 1 }
        state.sessions[id] = existing
        state.metrics.sessions = state.metrics.sessions + 1
    else
        existing.connected = true
        existing.epoch = existing.epoch + 1
    end
    return { sessionId = id, ownerId = owner, generation = state.generation, epoch = existing.epoch, negotiation = negotiation }
end

function multiplayer.newCommand(sessionId, ownerId, generation, sequence, revision, kind, payload, payloadBytes)
    return {
        protocolVersion = multiplayer.protocolVersion,
        sessionId = sessionId,
        ownerId = ownerId,
        generation = generation,
        sequence = sequence,
        revision = revision,
        kind = kind,
        payload = payload,
        payloadBytes = payloadBytes,
    }
end

function multiplayer.validateCommand(command, sessionContext, now)
    if type(command) ~= "table" then return false, "command must be a table" end
    if command.protocolVersion ~= multiplayer.protocolVersion then return false, "protocol version is incompatible" end
    if not multiplayer.commandKinds[command.kind] then return false, "command kind is unsupported" end
    if type(sessionContext) ~= "table" then return false, "session context is required" end
    if command.sessionId ~= sessionContext.sessionId or command.ownerId ~= sessionContext.ownerId then return false, "command owner is unauthorized" end
    if math.floor(_safeNumber(command.generation, 0)) ~= sessionContext.generation then return false, "command generation is stale" end
    if math.floor(_safeNumber(command.sequence, 0)) <= math.floor(_safeNumber(sessionContext.lastSequence, 0)) then return false, "command sequence is duplicate or stale" end
    if math.floor(_safeNumber(command.revision, 0)) ~= sessionContext.revision then return false, "command revision is stale" end
    if math.floor(_safeNumber(command.payloadBytes, 0)) < 0 or math.floor(_safeNumber(command.payloadBytes, 0)) > multiplayer.maxCommandBytes then return false, "command payload exceeds limit" end
    if _containsForbidden(command.payload) then return false, "command contains forbidden runtime reference" end
    local context = sessionContext.validation or {}
    if context.fit == false then return false, "loadout fit validation failed" end
    if context.targetValid == false and command.kind == "target" then return false, "target is invalid" end
    local currentTime = _safeNumber(now, 0.0)
    if command.kind == "fireIntent" and context.cooldownReady == false then return false, "fire cooldown is not ready" end
    if command.kind == "fireIntent" and currentTime < _safeNumber(sessionContext.cooldownUntil, 0.0) then return false, "fire cooldown is not ready" end
    return true
end

function multiplayer.acceptCommand(command, now, validation)
    local state = multiplayer.state
    if not state.initialized then return nil, "server is not initialized" end
    local commandSessionId = type(command) == "table" and command.sessionId or ""
    local session = _session(state, commandSessionId)
    if session == nil then state.metrics.ownerRejected = state.metrics.ownerRejected + 1; state.metrics.rejectedCommands = state.metrics.rejectedCommands + 1; return nil, "unknown session" end
    local context = {
        sessionId = session.sessionId,
        ownerId = session.ownerId,
        generation = session.generation,
        revision = state.revision,
        lastSequence = session.lastSequence,
        cooldownUntil = session.cooldownUntil,
        validation = validation or {},
    }
    local valid, errorText = multiplayer.validateCommand(command, context, now)
    if not valid then
        state.metrics.rejectedCommands = state.metrics.rejectedCommands + 1
        if errorText == "command generation is stale" or errorText == "command sequence is duplicate or stale" then state.metrics.staleRejected = state.metrics.staleRejected + 1 end
        if errorText == "command revision is stale" then state.metrics.revisionRejected = state.metrics.revisionRejected + 1 end
        if errorText == "loadout fit validation failed" then state.metrics.fitRejected = state.metrics.fitRejected + 1 end
        if errorText == "target is invalid" then state.metrics.targetRejected = state.metrics.targetRejected + 1 end
        if errorText == "fire cooldown is not ready" then state.metrics.cooldownRejected = state.metrics.cooldownRejected + 1 end
        if errorText == "protocol version is incompatible" then state.metrics.versionRejected = state.metrics.versionRejected + 1 end
        return nil, errorText
    end
    local currentTime = _safeNumber(now, 0.0)
    if currentTime - session.rateWindowStart >= multiplayer.rateWindowSeconds then session.rateWindowStart = currentTime; session.rateCount = 0 end
    if session.rateCount >= multiplayer.maxCommandsPerWindow then state.metrics.rateRejected = state.metrics.rateRejected + 1; state.metrics.rejectedCommands = state.metrics.rejectedCommands + 1; return nil, "command rate limit exceeded" end
    session.rateCount = session.rateCount + 1
    session.lastSequence = math.floor(command.sequence)
    if command.kind == "fireIntent" then session.cooldownUntil = currentTime + 0.1 end
    state.commandSequence = state.commandSequence + 1
    state.metrics.acceptedCommands = state.metrics.acceptedCommands + 1
    state.metrics.networkBytesIn = state.metrics.networkBytesIn + math.floor(_safeNumber(command.payloadBytes, 0)) + 64
    state.metrics.commandQueueDepth = 1
    if state.metrics.commandQueueHighWatermark < state.metrics.commandQueueDepth then state.metrics.commandQueueHighWatermark = state.metrics.commandQueueDepth end
    state.metrics.commandQueueDepth = 0
    return {
        protocolVersion = multiplayer.protocolVersion,
        kind = "ack",
        accepted = true,
        sessionId = session.sessionId,
        ownerId = session.ownerId,
        generation = state.generation,
        revision = state.revision,
        commandSequence = state.commandSequence,
        clientSequence = command.sequence,
    }
end

function multiplayer.publishSnapshot(kind, payload, stable)
    local state = multiplayer.state
    if not state.initialized then return nil, "server is not initialized" end
    if not multiplayer.snapshotKinds[kind] then return nil, "snapshot kind is unsupported" end
    if _containsForbidden(payload) then return nil, "snapshot contains forbidden runtime reference" end
    if type(payload) == "table" then
        local entityId = payload.entityId or payload.targetEntityId
        if entityId ~= nil and state.destroyed[_safeString(entityId, "")] then
            state.metrics.destroyedResurrectionRejected = state.metrics.destroyedResurrectionRejected + 1
            return nil, "destroyed entity cannot be resurrected"
        end
        if kind == "damage" then
            local damageId = payload.eventId or payload.damageId
            if damageId ~= nil then
                local normalizedDamageId = _safeString(damageId, "")
                if state.seenDamage[normalizedDamageId] then
                    state.metrics.duplicateDamageRejected = state.metrics.duplicateDamageRejected + 1
                    return nil, "duplicate damage event"
                end
                state.seenDamage[normalizedDamageId] = true
            end
        end
    end
    state.snapshotSequence = state.snapshotSequence + 1
    local value = {
        protocolVersion = multiplayer.protocolVersion,
        kind = kind,
        generation = state.generation,
        revision = state.revision,
        sequence = state.snapshotSequence,
        stable = stable == true,
        payload = _clone(payload or {}),
    }
    state.metrics.networkBytesOut = state.metrics.networkBytesOut + 64
    state.metrics.snapshotQueueDepth = 1
    if state.metrics.snapshotQueueHighWatermark < state.metrics.snapshotQueueDepth then state.metrics.snapshotQueueHighWatermark = state.metrics.snapshotQueueDepth end
    state.metrics.snapshotQueueDepth = 0
    if value.stable and multiplayer.stableKinds[kind] then state.lastStableSnapshot = _clone(value); state.metrics.stablePublished = state.metrics.stablePublished + 1 else state.metrics.transientPublished = state.metrics.transientPublished + 1; state.metrics.transientReplaySuppressed = state.metrics.transientReplaySuppressed + 1 end
    return value
end

function multiplayer.lateJoin(sessionId)
    local state = multiplayer.state
    local session = _session(state, sessionId)
    if session == nil then return nil, "unknown session" end
    state.metrics.lateJoinSnapshots = state.metrics.lateJoinSnapshots + 1
    if state.lastStableSnapshot == nil then return nil, "stable snapshot is not ready" end
    return _clone(state.lastStableSnapshot)
end

function multiplayer.reconnect(sessionId, ownerId, clientVersion, compatibleVersions)
    local state = multiplayer.state
    local session = _session(state, sessionId)
    if session == nil or session.ownerId ~= ownerId then state.metrics.ownerRejected = state.metrics.ownerRejected + 1; return nil, "reconnect owner mismatch" end
    local registered, errorText = multiplayer.registerSession(sessionId, ownerId, clientVersion, compatibleVersions)
    if registered == nil then return nil, errorText end
    session.lastSequence = 0
    session.generation = state.generation
    state.metrics.reconnects = state.metrics.reconnects + 1
    registered.snapshot = multiplayer.lateJoin(sessionId)
    return registered
end

function multiplayer.markDestroyed(entityId)
    local id = _safeString(entityId, "")
    if id == "" then return false end
    multiplayer.state.destroyed[id] = true
    return true
end

function multiplayer.getDiagnostics()
    local state = multiplayer.state
    return {
        protocolVersion = multiplayer.protocolVersion,
        initialized = state.initialized,
        generation = state.generation,
        revision = state.revision,
        sessions = state.metrics.sessions,
        acceptedCommands = state.metrics.acceptedCommands,
        rejectedCommands = state.metrics.rejectedCommands,
        staleRejected = state.metrics.staleRejected,
        ownerRejected = state.metrics.ownerRejected,
        revisionRejected = state.metrics.revisionRejected,
        cooldownRejected = state.metrics.cooldownRejected,
        fitRejected = state.metrics.fitRejected,
        targetRejected = state.metrics.targetRejected,
        malformedRejected = state.metrics.malformedRejected,
        versionRejected = state.metrics.versionRejected,
        rateRejected = state.metrics.rateRejected,
        transientPublished = state.metrics.transientPublished,
        stablePublished = state.metrics.stablePublished,
        lateJoinSnapshots = state.metrics.lateJoinSnapshots,
        reconnects = state.metrics.reconnects,
        destroyedResurrectionRejected = state.metrics.destroyedResurrectionRejected,
        duplicateDamageRejected = state.metrics.duplicateDamageRejected,
        networkBytesIn = state.metrics.networkBytesIn,
        networkBytesOut = state.metrics.networkBytesOut,
        commandQueueDepth = state.metrics.commandQueueDepth,
        commandQueueHighWatermark = state.metrics.commandQueueHighWatermark,
        snapshotQueueDepth = state.metrics.snapshotQueueDepth,
        snapshotQueueHighWatermark = state.metrics.snapshotQueueHighWatermark,
        transientReplaySuppressed = state.metrics.transientReplaySuppressed,
    }
end
