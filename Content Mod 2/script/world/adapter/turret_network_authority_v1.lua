---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Multiplayer-authority DTO for the turret fixture. Server owns commands and
-- fire events; clients consume monotonic snapshots and interpolate locally.

cm2TurretNetworkAuthorityV1 = cm2TurretNetworkAuthorityV1 or {}
local network = cm2TurretNetworkAuthorityV1

network.protocolVersion = "cm2.turret-network/1"

local function _newState()
    return {
        initialized = false,
        clientInitialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        sequence = 0,
        lastCommandSequence = 0,
        lastSnapshotSequence = 0,
        yaw = 0.0,
        pitch = 0.0,
        targetId = "",
        commandWindow = 0.0,
        commandCount = 0,
        commandRate = 20,
        clientYaw = 0.0,
        clientPitch = 0.0,
        clientSnapshotSequence = 0,
        metrics = {
            initCount = 0,
            clientInits = 0,
            snapshots = 0,
            commandsAccepted = 0,
            commandsRejected = 0,
            staleCommands = 0,
            foreignCommands = 0,
            rateRejected = 0,
            fires = 0,
            duplicateFires = 0,
            clientSnapshots = 0,
            clientStaleSnapshots = 0,
            interpolations = 0,
            staleRejects = 0,
            ownerRejects = 0,
        },
    }
end

network.state = network.state or _newState()

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

local function _validServer(handle)
    local state = network.state
    if type(handle) ~= "table" then return false, "network handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "network identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "network owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "network generation is stale" end
    return true
end

local function _snapshot(kind)
    local state = network.state
    state.sequence = state.sequence + 1
    state.lastSnapshotSequence = state.sequence
    state.metrics.snapshots = state.metrics.snapshots + 1
    return {
        protocolVersion = network.protocolVersion,
        kind = kind or "turret.snapshot",
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        sequence = state.sequence,
        yaw = state.yaw,
        pitch = state.pitch,
        targetId = state.targetId,
    }
end

function network.serverInit(generation, identity, ownerId, options)
    local state = network.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.clientInitialized = false
    state.identity = _safeString(identity, "turret-network")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.sequence = 0
    state.lastCommandSequence = 0
    state.lastSnapshotSequence = 0
    state.yaw = 0.0
    state.pitch = 0.0
    state.targetId = ""
    state.commandWindow = 0.0
    state.commandCount = 0
    state.commandRate = math.max(1, math.floor(_safeNumber(resolved.commandRate, 20)))
    local initCount = (state.metrics.initCount or 0) + 1
    state.metrics = {
        initCount = initCount, clientInits = 0, snapshots = 0,
        commandsAccepted = 0, commandsRejected = 0, staleCommands = 0,
        foreignCommands = 0, rateRejected = 0, fires = 0, duplicateFires = 0,
        clientSnapshots = 0, clientStaleSnapshots = 0, interpolations = 0,
        staleRejects = 0, ownerRejects = 0,
    }
    return network.handle()
end

function network.handle()
    local state = network.state
    return { protocolVersion = network.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation }
end

function network.serverTick(handle, dt)
    local valid, errorText = _validServer(handle)
    if not valid then return false, errorText end
    local delta = math.max(0.0, _safeNumber(dt, 0.0))
    network.state.commandWindow = network.state.commandWindow + delta
    if network.state.commandWindow >= 1.0 then network.state.commandWindow = network.state.commandWindow - 1.0; network.state.commandCount = 0 end
    return true
end

function network.serverSnapshot(handle)
    local valid, errorText = _validServer(handle)
    if not valid then return nil, errorText end
    return _snapshot("turret.snapshot")
end

function network.serverAcceptCommand(handle, command)
    local state = network.state
    local valid, errorText = _validServer(handle)
    if not valid then return nil, errorText end
    local request = type(command) == "table" and command or {}
    if _safeString(request.ownerId, state.ownerId) ~= state.ownerId then state.metrics.foreignCommands = state.metrics.foreignCommands + 1; state.metrics.commandsRejected = state.metrics.commandsRejected + 1; return nil, "command owner mismatch" end
    local generation = math.floor(_safeNumber(request.generation, state.generation))
    if generation ~= state.generation then state.metrics.staleCommands = state.metrics.staleCommands + 1; state.metrics.commandsRejected = state.metrics.commandsRejected + 1; return nil, "command generation is stale" end
    local sequence = math.floor(_safeNumber(request.sequence, 0))
    if sequence <= state.lastCommandSequence then state.metrics.staleCommands = state.metrics.staleCommands + 1; state.metrics.commandsRejected = state.metrics.commandsRejected + 1; return nil, "command sequence is stale" end
    if state.commandCount >= state.commandRate then state.metrics.rateRejected = state.metrics.rateRejected + 1; state.metrics.commandsRejected = state.metrics.commandsRejected + 1; return nil, "command rate exceeded" end
    state.lastCommandSequence = sequence
    state.commandCount = state.commandCount + 1
    state.yaw = _safeNumber(request.yaw, state.yaw)
    state.pitch = _safeNumber(request.pitch, state.pitch)
    state.targetId = _safeString(request.targetId, state.targetId)
    state.metrics.commandsAccepted = state.metrics.commandsAccepted + 1
    return _snapshot("turret.command-accepted")
end

function network.serverFire(handle, fire)
    local state = network.state
    local valid, errorText = _validServer(handle)
    if not valid then return nil, errorText end
    local event = type(fire) == "table" and fire or {}
    local sequence = math.floor(_safeNumber(event.sequence, 0))
    if sequence <= state.lastSnapshotSequence then state.metrics.duplicateFires = state.metrics.duplicateFires + 1; return nil, "fire sequence is stale" end
    state.metrics.fires = state.metrics.fires + 1
    state.lastSnapshotSequence = sequence
    return { protocolVersion = network.protocolVersion, kind = "turret.fire", identity = state.identity, ownerId = state.ownerId, generation = state.generation, sequence = sequence, targetId = _safeString(event.targetId, state.targetId), groupId = _safeString(event.groupId, "default") }
end

function network.clientInit(generation, identity, ownerId)
    local state = network.state
    state.clientInitialized = true
    state.identity = _safeString(identity, state.identity)
    state.ownerId = _safeString(ownerId, state.ownerId)
    state.generation = math.max(1, math.floor(_safeNumber(generation, state.generation)))
    state.clientYaw = state.yaw
    state.clientPitch = state.pitch
    state.clientSnapshotSequence = 0
    state.metrics.clientInits = state.metrics.clientInits + 1
    return network.handle()
end

function network.clientApplySnapshot(handle, snapshot)
    local state = network.state
    local valid, errorText = _validServer(handle)
    if not valid then return false, errorText end
    local value = type(snapshot) == "table" and snapshot or {}
    if math.floor(_safeNumber(value.generation, 0)) ~= state.generation then state.metrics.clientStaleSnapshots = state.metrics.clientStaleSnapshots + 1; return false, "snapshot generation is stale" end
    local sequence = math.floor(_safeNumber(value.sequence, 0))
    if sequence <= state.clientSnapshotSequence then state.metrics.clientStaleSnapshots = state.metrics.clientStaleSnapshots + 1; return false, "snapshot sequence is stale" end
    state.clientSnapshotSequence = sequence
    state.clientYaw = _safeNumber(value.yaw, state.clientYaw)
    state.clientPitch = _safeNumber(value.pitch, state.clientPitch)
    state.metrics.clientSnapshots = state.metrics.clientSnapshots + 1
    return true, { sequence = sequence, yaw = state.clientYaw, pitch = state.clientPitch }
end

function network.clientInterpolate(handle, alpha)
    local valid, errorText = _validServer(handle)
    if not valid then return nil, errorText end
    local blend = math.max(0.0, math.min(1.0, _safeNumber(alpha, 1.0)))
    network.state.metrics.interpolations = network.state.metrics.interpolations + 1
    return { protocolVersion = network.protocolVersion, identity = network.state.identity, ownerId = network.state.ownerId, generation = network.state.generation, sequence = network.state.clientSnapshotSequence, yaw = network.state.clientYaw * blend, pitch = network.state.clientPitch * blend }
end

function network.getDiagnostics()
    local state = network.state
    return {
        protocolVersion = network.protocolVersion,
        initialized = state.initialized,
        clientInitialized = state.clientInitialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        sequence = state.sequence,
        lastCommandSequence = state.lastCommandSequence,
        lastSnapshotSequence = state.lastSnapshotSequence,
        clientSnapshotSequence = state.clientSnapshotSequence,
        yaw = state.yaw,
        pitch = state.pitch,
        clientYaw = state.clientYaw,
        clientPitch = state.clientPitch,
        commandRate = state.commandRate,
        initCount = state.metrics.initCount,
        clientInits = state.metrics.clientInits,
        snapshots = state.metrics.snapshots,
        commandsAccepted = state.metrics.commandsAccepted,
        commandsRejected = state.metrics.commandsRejected,
        staleCommands = state.metrics.staleCommands,
        foreignCommands = state.metrics.foreignCommands,
        rateRejected = state.metrics.rateRejected,
        fires = state.metrics.fires,
        duplicateFires = state.metrics.duplicateFires,
        clientSnapshots = state.metrics.clientSnapshots,
        clientStaleSnapshots = state.metrics.clientStaleSnapshots,
        interpolations = state.metrics.interpolations,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
    }
end
