---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Pure TurretSolver v1.  It consumes DTO basis/target data and returns a
-- deterministic yaw/pitch command; no Body, Joint, raycast or input API is
-- accessed here.

cm2TurretSolverV1 = cm2TurretSolverV1 or {}
local solver = cm2TurretSolverV1

solver.protocolVersion = "cm2.turret-solver/1"

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        metrics = {
            initCount = 0,
            selections = 0,
            selected = 0,
            solves = 0,
            solveRejects = 0,
            clampedYaw = 0,
            clampedPitch = 0,
            leadApplications = 0,
            staleRejects = 0,
            ownerRejects = 0,
            filterRejects = 0,
        },
    }
end

solver.state = solver.state or _newState()

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

local function _vec(value, fallback)
    local source = type(value) == "table" and value or {}
    local base = fallback or { x = 0.0, y = 0.0, z = 0.0 }
    return {
        x = _safeNumber(source.x or source[1], base.x),
        y = _safeNumber(source.y or source[2], base.y),
        z = _safeNumber(source.z or source[3], base.z),
    }
end

local function _add(a, b)
    return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

local function _scale(a, value)
    return { x = a.x * value, y = a.y * value, z = a.z * value }
end

local function _sub(a, b)
    return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function _dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function _length(a)
    return math.sqrt(_dot(a, a))
end

local function _normalize(a)
    local length = _length(a)
    if length < 0.000001 then return nil end
    return _scale(a, 1.0 / length)
end

local function _atan2(y, x)
    if x > 0.0 then return math.atan(y / x) end
    if x < 0.0 and y >= 0.0 then return math.atan(y / x) + math.pi end
    if x < 0.0 and y < 0.0 then return math.atan(y / x) - math.pi end
    if x == 0.0 and y > 0.0 then return math.pi * 0.5 end
    if x == 0.0 and y < 0.0 then return -math.pi * 0.5 end
    return 0.0
end

local function _clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function _validHandle(handle)
    local state = solver.state
    if type(handle) ~= "table" then return false, "solver handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "solver identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "solver owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "solver generation is stale" end
    return true
end

local function _candidateAllowed(candidate, filters)
    local value = type(candidate) == "table" and candidate or {}
    local rule = type(filters) == "table" and filters or {}
    if value.alive == false then return false end
    if rule.hostileOnly == true and value.hostile ~= true then return false end
    local kind = _safeString(value.kind, "unknown")
    if type(rule.allowedKinds) == "table" and #rule.allowedKinds > 0 then
        local allowed = false
        for _, allowedKind in ipairs(rule.allowedKinds) do if _safeString(allowedKind) == kind then allowed = true; break end end
        if not allowed then return false end
    end
    local distance = _safeNumber(value.distance, 0.0)
    if rule.maxDistance ~= nil and distance > _safeNumber(rule.maxDistance, distance) then return false end
    return true
end

function solver.serverInit(generation, identity, ownerId, options)
    local state = solver.state
    state.initialized = true
    state.identity = _safeString(identity, "turret-solver")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    local initCount = (state.metrics.initCount or 0) + 1
    state.metrics = {
        initCount = initCount, selections = 0, selected = 0, solves = 0,
        solveRejects = 0, clampedYaw = 0, clampedPitch = 0,
        leadApplications = 0, staleRejects = 0, ownerRejects = 0, filterRejects = 0,
    }
    return solver.handle()
end

function solver.handle()
    local state = solver.state
    return { protocolVersion = solver.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation }
end

function solver.selectTargets(handle, candidates, filters, limit)
    local state = solver.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    state.metrics.selections = state.metrics.selections + 1
    local accepted = {}
    for _, candidate in ipairs(candidates or {}) do
        if _candidateAllowed(candidate, filters) then accepted[#accepted + 1] = _clone(candidate) else state.metrics.filterRejects = state.metrics.filterRejects + 1 end
    end
    table.sort(accepted, function(left, right)
        local leftPriority = _safeNumber(left.priority, 0.0)
        local rightPriority = _safeNumber(right.priority, 0.0)
        if leftPriority ~= rightPriority then return leftPriority > rightPriority end
        local leftDistance = _safeNumber(left.distance, 0.0)
        local rightDistance = _safeNumber(right.distance, 0.0)
        if leftDistance ~= rightDistance then return leftDistance < rightDistance end
        return _safeString(left.targetId) < _safeString(right.targetId)
    end)
    local maxCount = math.max(0, math.floor(_safeNumber(limit, #accepted)))
    while #accepted > maxCount do table.remove(accepted) end
    state.metrics.selected = state.metrics.selected + #accepted
    return accepted
end

function solver.solve(handle, definition, base, target)
    local state = solver.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    local config = type(definition) == "table" and definition or {}
    local frame = type(base) == "table" and base or {}
    local candidate = type(target) == "table" and target or {}
    local position = _vec(frame.position)
    local forward = _normalize(_vec(frame.forward, { x = 0.0, y = 0.0, z = -1.0 }))
    local up = _normalize(_vec(frame.up, { x = 0.0, y = 1.0, z = 0.0 }))
    local right = _normalize(_vec(frame.right, { x = 1.0, y = 0.0, z = 0.0 }))
    if forward == nil or up == nil or right == nil then state.metrics.solveRejects = state.metrics.solveRejects + 1; return nil, "turret basis is invalid" end
    local targetPosition = _vec(candidate.position)
    local targetVelocity = _vec(candidate.velocity)
    local leadTime = math.max(0.0, _safeNumber(candidate.leadTime, _safeNumber(config.leadTime, 0.0)))
    if leadTime > 0.0 then targetPosition = _add(targetPosition, _scale(targetVelocity, leadTime)); state.metrics.leadApplications = state.metrics.leadApplications + 1 end
    local direction = _normalize(_sub(targetPosition, position))
    if direction == nil then state.metrics.solveRejects = state.metrics.solveRejects + 1; return nil, "target position equals turret position" end
    local yaw = _atan2(_dot(direction, right), _dot(direction, forward)) * 180.0 / math.pi
    local pitch = math.asin(_clamp(_dot(direction, up), -1.0, 1.0)) * 180.0 / math.pi
    local joint = type(config.joint) == "table" and config.joint or {}
    local pitchConfig = type(config.pitch) == "table" and config.pitch or {}
    local minYaw = _safeNumber(joint.minAngle, -180.0)
    local maxYaw = _safeNumber(joint.maxAngle, 180.0)
    local minPitch = _safeNumber(pitchConfig.minAngle, -90.0)
    local maxPitch = _safeNumber(pitchConfig.maxAngle, 90.0)
    local clampedYaw = _clamp(yaw, minYaw, maxYaw)
    local clampedPitch = _clamp(pitch, minPitch, maxPitch)
    if clampedYaw ~= yaw then state.metrics.clampedYaw = state.metrics.clampedYaw + 1 end
    if clampedPitch ~= pitch then state.metrics.clampedPitch = state.metrics.clampedPitch + 1 end
    state.metrics.solves = state.metrics.solves + 1
    return {
        protocolVersion = solver.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        targetId = _safeString(candidate.targetId),
        leadTime = leadTime,
        aimPoint = targetPosition,
        rawYaw = yaw,
        rawPitch = pitch,
        yaw = clampedYaw,
        pitch = clampedPitch,
        clampedYaw = clampedYaw ~= yaw,
        clampedPitch = clampedPitch ~= pitch,
    }
end

function solver.getDiagnostics()
    local state = solver.state
    return {
        protocolVersion = solver.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        initCount = state.metrics.initCount,
        selections = state.metrics.selections,
        selected = state.metrics.selected,
        solves = state.metrics.solves,
        solveRejects = state.metrics.solveRejects,
        clampedYaw = state.metrics.clampedYaw,
        clampedPitch = state.metrics.clampedPitch,
        leadApplications = state.metrics.leadApplications,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
        filterRejects = state.metrics.filterRejects,
    }
end
