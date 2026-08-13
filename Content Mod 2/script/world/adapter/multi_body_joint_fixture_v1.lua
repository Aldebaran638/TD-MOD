---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Small, opt-in multi-body/joint fixture.  It is a lifecycle/resolver test
-- surface only; no production turret or engine Body creation is performed.

cm2MultiBodyJointFixtureV1 = cm2MultiBodyJointFixtureV1 or {}
local fixture = cm2MultiBodyJointFixtureV1

fixture.protocolVersion = "cm2.multi-body-joint-fixture/1"
fixture.formalTurretEnabled = false

local function _newState()
    return {
        initialized = false,
        spawned = false,
        disposed = false,
        identity = "",
        ownerId = "",
        generation = 0,
        fixtureId = "",
        lifecycle = "new",
        bodies = {},
        joints = {},
        snapshots = 0,
        ticks = 0,
        metrics = {
            initCount = 0,
            spawns = 0,
            spawnRejects = 0,
            ticks = 0,
            disposes = 0,
            idempotentDisposes = 0,
            staleRejects = 0,
            ownerRejects = 0,
            limitRejects = 0,
            parentRejects = 0,
            jointRejects = 0,
            snapshots = 0,
            networkSnapshots = 0,
        },
    }
end

fixture.state = fixture.state or _newState()

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

local function _clear(value)
    for key in pairs(value) do value[key] = nil end
end

local function _validHandle(handle)
    local state = fixture.state
    if type(handle) ~= "table" then return false, "fixture handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "fixture identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "fixture owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "fixture generation is stale" end
    if state.disposed then return false, "fixture is disposed" end
    return true
end

local function _validateBodyGraph(bodies)
    local rootCount = 0
    for id, body in pairs(bodies) do
        if body.parentId == "" then rootCount = rootCount + 1 elseif bodies[body.parentId] == nil then return false, "missing body parent: " .. body.parentId end
        local visited = {}
        local cursor = id
        while cursor ~= "" do
            if visited[cursor] then return false, "body parent cycle: " .. cursor end
            visited[cursor] = true
            local current = bodies[cursor]
            if current == nil then return false, "missing body parent: " .. cursor end
            cursor = current.parentId
        end
    end
    if rootCount ~= 1 then return false, "fixture requires exactly one root body" end
    return true
end

local function _validateJointGraph(bodies, joints)
    for id, joint in pairs(joints) do
        if joint.parentId == "" or bodies[joint.parentId] == nil or bodies[joint.childId] == nil then return false, "joint body endpoint missing: " .. id end
        if joint.minLimit > joint.maxLimit then return false, "joint limit inverted: " .. id end
        if joint.parentId == joint.childId then return false, "joint cannot connect body to itself: " .. id end
    end
    return true
end

function fixture.serverInit(generation, identity, ownerId, options)
    local state = fixture.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.spawned = false
    state.disposed = false
    state.identity = _safeString(identity, "multi-body-fixture")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.fixtureId = _safeString(resolved.fixtureId, "two-body-joint")
    state.lifecycle = "ready"
    state.bodies = {}
    state.joints = {}
    state.snapshots = 0
    state.ticks = 0
    local initCount = (state.metrics.initCount or 0) + 1
    state.metrics = {
        initCount = initCount, spawns = 0, spawnRejects = 0, ticks = 0,
        disposes = 0, idempotentDisposes = 0, staleRejects = 0,
        ownerRejects = 0, limitRejects = 0, parentRejects = 0,
        jointRejects = 0, snapshots = 0, networkSnapshots = 0,
    }
    return fixture.handle()
end

function fixture.handle()
    local state = fixture.state
    return { protocolVersion = fixture.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation, fixtureId = state.fixtureId }
end

function fixture.spawn(handle, definition)
    local state = fixture.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    if type(definition) ~= "table" then state.metrics.spawnRejects = state.metrics.spawnRejects + 1; return false, "fixture definition is required" end
    local bodies = {}
    for _, rawBody in ipairs(definition.bodies or {}) do
        local id = _safeString(rawBody.bodyId or rawBody.id)
        if id == "" or bodies[id] ~= nil then state.metrics.spawnRejects = state.metrics.spawnRejects + 1; return false, "duplicate or missing fixture body" end
        bodies[id] = {
            bodyId = id,
            engineBodyId = math.floor(_safeNumber(rawBody.engineBodyId, 0)),
            parentId = _safeString(rawBody.parentId),
            localTransform = _clone(rawBody.localTransform or {}),
            lifecycle = "active",
        }
    end
    local validBodies, bodyError = _validateBodyGraph(bodies)
    if not validBodies then state.metrics.spawnRejects = state.metrics.spawnRejects + 1; state.metrics.parentRejects = state.metrics.parentRejects + 1; return false, bodyError end
    local joints = {}
    for _, rawJoint in ipairs(definition.joints or {}) do
        local id = _safeString(rawJoint.jointId or rawJoint.id)
        if id == "" or joints[id] ~= nil then state.metrics.spawnRejects = state.metrics.spawnRejects + 1; return false, "duplicate or missing fixture joint" end
        local minLimit = _safeNumber(rawJoint.minLimit, -180.0)
        local maxLimit = _safeNumber(rawJoint.maxLimit, 180.0)
        if minLimit > maxLimit then state.metrics.limitRejects = state.metrics.limitRejects + 1; state.metrics.spawnRejects = state.metrics.spawnRejects + 1; return false, "joint limit inverted" end
        joints[id] = {
            jointId = id,
            parentId = _safeString(rawJoint.parentId),
            childId = _safeString(rawJoint.childId),
            axis = _clone(rawJoint.axis or { 0, 1, 0 }),
            minLimit = minLimit,
            maxLimit = maxLimit,
            angle = math.max(minLimit, math.min(maxLimit, _safeNumber(rawJoint.angle, 0.0))),
            active = true,
        }
    end
    local validJoints, jointError = _validateJointGraph(bodies, joints)
    if not validJoints then state.metrics.jointRejects = state.metrics.jointRejects + 1; state.metrics.spawnRejects = state.metrics.spawnRejects + 1; return false, jointError end
    state.bodies = bodies
    state.joints = joints
    state.spawned = true
    state.disposed = false
    state.lifecycle = "active"
    state.metrics.spawns = state.metrics.spawns + 1
    return true, fixture.snapshot(handle)
end

function fixture.serverTick(handle, dt)
    local state = fixture.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    if not state.spawned then return false, "fixture has not spawned" end
    state.ticks = state.ticks + math.max(0.0, _safeNumber(dt, 0.0))
    state.metrics.ticks = state.metrics.ticks + 1
    return true, fixture.snapshot(handle)
end

function fixture.disposeBody(handle, bodyId)
    local state = fixture.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local id = _safeString(bodyId)
    if state.bodies[id] == nil then return false, "fixture body is missing" end
    local removed = {}
    local function mark(target)
        if removed[target] then return end
        removed[target] = true
        for childId, body in pairs(state.bodies) do if body.parentId == target then mark(childId) end end
    end
    mark(id)
    for removedId in pairs(removed) do state.bodies[removedId].lifecycle = "disposed" end
    for _, joint in pairs(state.joints) do if removed[joint.parentId] or removed[joint.childId] then joint.active = false end end
    local remaining = 0
    for bodyIdValue, body in pairs(state.bodies) do if not removed[bodyIdValue] and body.lifecycle ~= "disposed" then remaining = remaining + 1 end end
    if remaining == 0 then state.disposed = true; state.lifecycle = "disposed" end
    state.metrics.disposes = state.metrics.disposes + 1
    return true, fixture.snapshot(handle)
end

function fixture.dispose(handle, reason)
    local state = fixture.state
    if state.disposed then state.metrics.idempotentDisposes = state.metrics.idempotentDisposes + 1; return false, "fixture already disposed" end
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    for _, body in pairs(state.bodies) do body.lifecycle = "disposed" end
    for _, joint in pairs(state.joints) do joint.active = false end
    state.disposed = true
    state.lifecycle = "disposed"
    state.metrics.disposes = state.metrics.disposes + 1
    return true, _safeString(reason, "fixture dispose")
end

function fixture.snapshot(handle)
    local state = fixture.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    state.snapshots = state.snapshots + 1
    state.metrics.snapshots = state.metrics.snapshots + 1
    return {
        protocolVersion = fixture.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        fixtureId = state.fixtureId,
        lifecycle = state.lifecycle,
        formalTurretEnabled = fixture.formalTurretEnabled,
        bodies = _clone(state.bodies),
        joints = _clone(state.joints),
        ticks = state.ticks,
        sequence = state.snapshots,
    }
end

function fixture.networkSnapshot(handle)
    local snapshot, errorText = fixture.snapshot(handle)
    if snapshot == nil then return nil, errorText end
    fixture.state.metrics.networkSnapshots = fixture.state.metrics.networkSnapshots + 1
    snapshot.networkSchema = "cm2.multi-body-joint-fixture-snapshot/1"
    snapshot.networkPolicy = "fixture-only; formal-turret-rejected"
    return snapshot
end

function fixture.promoteFormalTurret(handle)
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    return false, "formal turret is intentionally out of scope for fixture v1"
end

function fixture.getDiagnostics()
    local state = fixture.state
    local bodyCount = 0
    local jointCount = 0
    for _ in pairs(state.bodies) do bodyCount = bodyCount + 1 end
    for _ in pairs(state.joints) do jointCount = jointCount + 1 end
    return {
        protocolVersion = fixture.protocolVersion,
        initialized = state.initialized,
        spawned = state.spawned,
        disposed = state.disposed,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        fixtureId = state.fixtureId,
        lifecycle = state.lifecycle,
        formalTurretEnabled = fixture.formalTurretEnabled,
        bodyCount = bodyCount,
        jointCount = jointCount,
        ticks = state.metrics.ticks,
        spawns = state.metrics.spawns,
        spawnRejects = state.metrics.spawnRejects,
        disposes = state.metrics.disposes,
        idempotentDisposes = state.metrics.idempotentDisposes,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
        limitRejects = state.metrics.limitRejects,
        parentRejects = state.metrics.parentRejects,
        jointRejects = state.metrics.jointRejects,
        snapshots = state.metrics.snapshots,
        networkSnapshots = state.metrics.networkSnapshots,
    }
end
