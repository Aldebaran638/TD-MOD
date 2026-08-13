---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Hero-fixture physical joint actuator DTO.  It enforces limits/rate/torque and
-- parent lifecycle before a future engine Joint adapter is allowed to act.

cm2TurretPhysicalJointActuatorV1 = cm2TurretPhysicalJointActuatorV1 or {}
local joint = cm2TurretPhysicalJointActuatorV1

joint.protocolVersion = "cm2.turret-physical-joint/1"
joint.fixtureOnly = true

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        parentLifecycle = "active",
        lifecycle = "new",
        yaw = 0.0,
        pitch = 0.0,
        torque = 0.0,
        metrics = {
            initCount = 0,
            applies = 0,
            clamped = 0,
            torqueRejected = 0,
            parentRejects = 0,
            lifecycleChanges = 0,
            snapshots = 0,
            staleRejects = 0,
            ownerRejects = 0,
        },
    }
end

joint.state = joint.state or _newState()

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
    local state = joint.state
    if type(handle) ~= "table" then return false, "physical joint handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "physical joint identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "physical joint owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "physical joint generation is stale" end
    return true
end

local function _clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function _approach(current, target, maximum)
    local delta = target - current
    if math.abs(delta) <= maximum then return target end
    if delta < 0.0 then return current - maximum end
    return current + maximum
end

function joint.serverInit(generation, identity, ownerId, options)
    local state = joint.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.identity = _safeString(identity, "physical-joint-fixture")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.parentLifecycle = "active"
    state.lifecycle = "active"
    state.yaw = _safeNumber(resolved.yaw, 0.0)
    state.pitch = _safeNumber(resolved.pitch, 0.0)
    state.torque = 0.0
    local initCount = (state.metrics.initCount or 0) + 1
    state.metrics = { initCount = initCount, applies = 0, clamped = 0, torqueRejected = 0, parentRejects = 0, lifecycleChanges = 0, snapshots = 0, staleRejects = 0, ownerRejects = 0 }
    return joint.handle()
end

function joint.handle()
    local state = joint.state
    return { protocolVersion = joint.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation }
end

function joint.setParentLifecycle(handle, lifecycle)
    local state = joint.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local value = _safeString(lifecycle, "active")
    if value ~= "active" and value ~= "destroyed" and value ~= "disposed" then state.metrics.parentRejects = state.metrics.parentRejects + 1; return false, "invalid parent lifecycle" end
    state.parentLifecycle = value
    if value ~= "active" then state.lifecycle = "disposed"; state.metrics.lifecycleChanges = state.metrics.lifecycleChanges + 1 end
    return true, joint.snapshot(handle)
end

function joint.applyCommand(handle, command, dt, limits)
    local state = joint.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    if state.parentLifecycle ~= "active" or state.lifecycle ~= "active" then state.metrics.parentRejects = state.metrics.parentRejects + 1; return nil, "parent is not active" end
    local target = type(command) == "table" and command or {}
    local config = type(limits) == "table" and limits or {}
    local delta = math.max(0.0, math.min(0.1, _safeNumber(dt, 0.0)))
    local minYaw = _safeNumber(config.minYaw, -90.0)
    local maxYaw = _safeNumber(config.maxYaw, 90.0)
    local minPitch = _safeNumber(config.minPitch, -45.0)
    local maxPitch = _safeNumber(config.maxPitch, 45.0)
    local maxSpeed = math.max(0.0, _safeNumber(config.maxSpeed, 90.0))
    local torque = math.max(0.0, _safeNumber(target.torque, 0.0))
    local maxTorque = math.max(0.0, _safeNumber(config.maxTorque, 100.0))
    if torque > maxTorque then state.metrics.torqueRejected = state.metrics.torqueRejected + 1; return nil, "joint torque budget exceeded" end
    local wantedYaw = _clamp(_safeNumber(target.yaw, state.yaw), minYaw, maxYaw)
    local wantedPitch = _clamp(_safeNumber(target.pitch, state.pitch), minPitch, maxPitch)
    if wantedYaw ~= _safeNumber(target.yaw, state.yaw) or wantedPitch ~= _safeNumber(target.pitch, state.pitch) then state.metrics.clamped = state.metrics.clamped + 1 end
    state.yaw = _approach(state.yaw, wantedYaw, maxSpeed * delta)
    state.pitch = _approach(state.pitch, wantedPitch, maxSpeed * delta)
    state.torque = torque
    state.metrics.applies = state.metrics.applies + 1
    return joint.snapshot(handle)
end

function joint.dispose(handle, reason)
    local state = joint.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    state.parentLifecycle = "disposed"
    state.lifecycle = "disposed"
    state.metrics.lifecycleChanges = state.metrics.lifecycleChanges + 1
    state.disposeReason = _safeString(reason, "joint-dispose")
    return true, joint.snapshot(handle)
end

function joint.snapshot(handle)
    local state = joint.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    state.metrics.snapshots = state.metrics.snapshots + 1
    return { protocolVersion = joint.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation, parentLifecycle = state.parentLifecycle, lifecycle = state.lifecycle, yaw = state.yaw, pitch = state.pitch, torque = state.torque, fixtureOnly = joint.fixtureOnly, disposeReason = state.disposeReason }
end

function joint.getDiagnostics()
    local state = joint.state
    return { protocolVersion = joint.protocolVersion, initialized = state.initialized, identity = state.identity, ownerId = state.ownerId, generation = state.generation, parentLifecycle = state.parentLifecycle, lifecycle = state.lifecycle, yaw = state.yaw, pitch = state.pitch, torque = state.torque, fixtureOnly = joint.fixtureOnly, initCount = state.metrics.initCount, applies = state.metrics.applies, clamped = state.metrics.clamped, torqueRejected = state.metrics.torqueRejected, parentRejects = state.metrics.parentRejects, lifecycleChanges = state.metrics.lifecycleChanges, snapshots = state.metrics.snapshots, staleRejects = state.metrics.staleRejects, ownerRejects = state.metrics.ownerRejects }
end
