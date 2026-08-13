---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Pure visual actuator/LOD DTO.  It smooths a solver command and chooses a
-- bounded presentation profile; engine Joint/particle/audio calls are outside
-- this adapter.

cm2TurretVisualActuatorV1 = cm2TurretVisualActuatorV1 or {}
local actuator = cm2TurretVisualActuatorV1

actuator.protocolVersion = "cm2.turret-visual-actuator/1"
actuator.lodProfiles = { "near", "far", "cull" }

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        turretId = "",
        yaw = 0.0,
        pitch = 0.0,
        lifecycle = "new",
        lod = "cull",
        fallbackMode = "static-anchor",
        metrics = {
            initCount = 0,
            applies = 0,
            dtClamps = 0,
            yawSteps = 0,
            pitchSteps = 0,
            lodQueries = 0,
            nearFrames = 0,
            farFrames = 0,
            culledFrames = 0,
            staleRejects = 0,
            ownerRejects = 0,
        },
    }
end

actuator.state = actuator.state or _newState()

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

local function _validHandle(handle)
    local state = actuator.state
    if type(handle) ~= "table" then return false, "actuator handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "actuator identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "actuator owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "actuator generation is stale" end
    return true
end

local function _approach(current, target, maximum)
    local delta = target - current
    if math.abs(delta) <= maximum then return target end
    if delta < 0.0 then return current - maximum end
    return current + maximum
end

function actuator.serverInit(generation, identity, ownerId, options)
    local state = actuator.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.identity = _safeString(identity, "turret-actuator")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.turretId = _safeString(resolved.turretId, "turret")
    state.yaw = _safeNumber(resolved.yaw, 0.0)
    state.pitch = _safeNumber(resolved.pitch, 0.0)
    state.lifecycle = "active"
    state.lod = "cull"
    state.fallbackMode = _safeString(resolved.fallbackMode, "static-anchor")
    local initCount = (state.metrics.initCount or 0) + 1
    state.metrics = {
        initCount = initCount, applies = 0, dtClamps = 0, yawSteps = 0,
        pitchSteps = 0, lodQueries = 0, nearFrames = 0, farFrames = 0,
        culledFrames = 0, staleRejects = 0, ownerRejects = 0,
    }
    return actuator.handle()
end

function actuator.handle()
    local state = actuator.state
    return { protocolVersion = actuator.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation, turretId = state.turretId }
end

function actuator.applyCommand(handle, command, dt, profile)
    local state = actuator.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    local target = type(command) == "table" and command or {}
    local resolvedProfile = type(profile) == "table" and profile or {}
    local delta = _safeNumber(dt, 0.0)
    if delta < 0.0 then delta = 0.0 end
    if delta > 0.1 then state.metrics.dtClamps = state.metrics.dtClamps + 1; delta = 0.1 end
    local maxYawSpeed = math.max(0.0, _safeNumber(resolvedProfile.maxYawSpeed, 90.0))
    local maxPitchSpeed = math.max(0.0, _safeNumber(resolvedProfile.maxPitchSpeed, maxYawSpeed))
    local oldYaw = state.yaw
    local oldPitch = state.pitch
    state.yaw = _approach(state.yaw, _safeNumber(target.yaw, state.yaw), maxYawSpeed * delta)
    state.pitch = _approach(state.pitch, _safeNumber(target.pitch, state.pitch), maxPitchSpeed * delta)
    if state.yaw ~= oldYaw then state.metrics.yawSteps = state.metrics.yawSteps + 1 end
    if state.pitch ~= oldPitch then state.metrics.pitchSteps = state.metrics.pitchSteps + 1 end
    state.metrics.applies = state.metrics.applies + 1
    return {
        protocolVersion = actuator.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        turretId = state.turretId,
        yaw = state.yaw,
        pitch = state.pitch,
        targetYaw = _safeNumber(target.yaw, state.yaw),
        targetPitch = _safeNumber(target.pitch, state.pitch),
        dt = delta,
        fallbackMode = state.fallbackMode,
        lod = state.lod,
    }
end

function actuator.selectLod(handle, distance, budget)
    local state = actuator.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    local value = type(budget) == "table" and budget or {}
    local range = math.max(0.0, _safeNumber(distance, 0.0))
    local nearDistance = math.max(0.0, _safeNumber(value.nearDistance, 40.0))
    local farDistance = math.max(nearDistance, _safeNumber(value.farDistance, 120.0))
    local selected = "cull"
    if value.enabled == false then selected = "cull" elseif range <= nearDistance then selected = "near" elseif range <= farDistance then selected = "far" end
    state.lod = selected
    state.metrics.lodQueries = state.metrics.lodQueries + 1
    if selected == "near" then state.metrics.nearFrames = state.metrics.nearFrames + 1 elseif selected == "far" then state.metrics.farFrames = state.metrics.farFrames + 1 else state.metrics.culledFrames = state.metrics.culledFrames + 1 end
    return { protocolVersion = actuator.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation, turretId = state.turretId, distance = range, lod = selected, fallbackMode = state.fallbackMode }
end

function actuator.dispose(handle, reason)
    local state = actuator.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    state.lifecycle = "disposed"
    state.lod = "cull"
    state.fallbackMode = _safeString(reason, "static-anchor")
    return true, actuator.snapshot(handle)
end

function actuator.snapshot(handle)
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    return { protocolVersion = actuator.protocolVersion, identity = actuator.state.identity, ownerId = actuator.state.ownerId, generation = actuator.state.generation, turretId = actuator.state.turretId, lifecycle = actuator.state.lifecycle, yaw = actuator.state.yaw, pitch = actuator.state.pitch, lod = actuator.state.lod, fallbackMode = actuator.state.fallbackMode }
end

function actuator.getDiagnostics()
    local state = actuator.state
    return {
        protocolVersion = actuator.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        turretId = state.turretId,
        lifecycle = state.lifecycle,
        yaw = state.yaw,
        pitch = state.pitch,
        lod = state.lod,
        fallbackMode = state.fallbackMode,
        initCount = state.metrics.initCount,
        applies = state.metrics.applies,
        dtClamps = state.metrics.dtClamps,
        yawSteps = state.metrics.yawSteps,
        pitchSteps = state.metrics.pitchSteps,
        lodQueries = state.metrics.lodQueries,
        nearFrames = state.metrics.nearFrames,
        farFrames = state.metrics.farFrames,
        culledFrames = state.metrics.culledFrames,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
    }
end
