---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: undefined-field

-- TurretDefinition v1 compiler.  This is a schema/fixture boundary only; it
-- does not create a production turret or call engine Joint APIs.

cm2TurretDefinitionV1 = cm2TurretDefinitionV1 or {}
local turret = cm2TurretDefinitionV1

turret.protocolVersion = "cm2.turret-definition/1"
turret.fixtureOnly = true

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        compiled = nil,
        fixture = nil,
        metrics = {
            initCount = 0,
            compiles = 0,
            compileRejects = 0,
            fixtureSpawns = 0,
            fixtureDisposes = 0,
            staleRejects = 0,
            ownerRejects = 0,
            limitRejects = 0,
            referenceRejects = 0,
            duplicateRejects = 0,
        },
    }
end

turret.state = turret.state or _newState()

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
    local state = turret.state
    if type(handle) ~= "table" then return false, "turret handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "turret identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "turret owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "turret generation is stale" end
    return true
end

local function _axis(value)
    local axis = type(value) == "table" and value or {}
    return {
        x = _safeNumber(axis.x or axis[1], 0.0),
        y = _safeNumber(axis.y or axis[2], 1.0),
        z = _safeNumber(axis.z or axis[3], 0.0),
    }
end

local function _validateReferences(definition, context)
    local source = type(context) == "table" and context or {}
    local parts = source.parts or {}
    local anchors = source.anchors or {}
    local basePartId = _safeString(definition.basePartId)
    local baseAnchorId = _safeString(definition.baseAnchorId)
    if basePartId == "" or (next(parts) ~= nil and parts[basePartId] == nil) then return false, "turret base part is missing" end
    if baseAnchorId == "" or (next(anchors) ~= nil and anchors[baseAnchorId] == nil) then return false, "turret base anchor is missing" end
    for _, group in ipairs(definition.weaponGroups or {}) do
        for _, anchorId in ipairs(group.muzzleAnchorIds or {}) do
            if next(anchors) ~= nil and anchors[anchorId] == nil then return false, "turret muzzle anchor is missing: " .. tostring(anchorId) end
        end
    end
    return true
end

local function _compile(definition, context)
    local source = type(definition) == "table" and definition or {}
    if _safeString(source.schemaVersion) ~= turret.protocolVersion then return nil, "turret schema version mismatch" end
    if _safeString(source.turretId) == "" then return nil, "turret id is required" end
    if source.playerFacing == true then return nil, "formal player turret is outside fixture v1" end
    local references, referenceError = _validateReferences(source, context)
    if not references then return nil, referenceError end
    local joint = type(source.joint) == "table" and source.joint or {}
    local minAngle = _safeNumber(joint.minAngle, -45.0)
    local maxAngle = _safeNumber(joint.maxAngle, 45.0)
    if minAngle > maxAngle then return nil, "turret joint limits are inverted" end
    local pitch = type(source.pitch) == "table" and source.pitch or {}
    local pitchMin = _safeNumber(pitch.minAngle, -30.0)
    local pitchMax = _safeNumber(pitch.maxAngle, 30.0)
    if pitchMin > pitchMax then return nil, "turret pitch limits are inverted" end
    local groups = {}
    local groupIds = {}
    for _, group in ipairs(source.weaponGroups or {}) do
        local groupId = _safeString(group.groupId)
        if groupId == "" or groupIds[groupId] ~= nil then return nil, "turret weapon group is duplicate or missing" end
        groupIds[groupId] = true
        groups[#groups + 1] = {
            groupId = groupId,
            weaponDefinitionId = _safeString(group.weaponDefinitionId),
            muzzleAnchorIds = _clone(group.muzzleAnchorIds or {}),
            cooldown = math.max(0.0, _safeNumber(group.cooldown, 0.25)),
        }
    end
    return {
        protocolVersion = turret.protocolVersion,
        turretId = _safeString(source.turretId),
        displayName = _safeString(source.displayName, source.turretId),
        fixtureOnly = true,
        playerFacing = false,
        basePartId = _safeString(source.basePartId),
        baseAnchorId = _safeString(source.baseAnchorId),
        joint = {
            jointId = _safeString(joint.jointId, source.turretId .. ":yaw"),
            axis = _axis(joint.axis),
            minAngle = minAngle,
            maxAngle = maxAngle,
            maxSpeed = math.max(0.0, _safeNumber(joint.maxSpeed, 90.0)),
            damping = math.max(0.0, _safeNumber(joint.damping, 1.0)),
        },
        pitch = {
            axis = _axis(pitch.axis or { x = 1.0, y = 0.0, z = 0.0 }),
            minAngle = pitchMin,
            maxAngle = pitchMax,
        },
        targeting = _clone(source.targeting or { maxTargets = 1, maxRange = 100.0, filters = {} }),
        fireControl = _clone(source.fireControl or { cooldown = 0.25, salvoSize = 1 }),
        weaponGroups = groups,
    }
end

function turret.serverInit(generation, identity, ownerId, options)
    local state = turret.state
    state.initialized = true
    state.identity = _safeString(identity, "turret-definition")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.compiled = nil
    state.fixture = nil
    local initCount = (state.metrics.initCount or 0) + 1
    state.metrics = {
        initCount = initCount, compiles = 0, compileRejects = 0,
        fixtureSpawns = 0, fixtureDisposes = 0, staleRejects = 0,
        ownerRejects = 0, limitRejects = 0, referenceRejects = 0,
        duplicateRejects = 0,
    }
    return turret.handle()
end

function turret.handle()
    local state = turret.state
    return { protocolVersion = turret.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation }
end

function turret.compile(handle, definition, context)
    local state = turret.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    local compiled, compileError = _compile(definition, context)
    if compiled == nil then
        state.metrics.compileRejects = state.metrics.compileRejects + 1
        if string.find(compileError or "", "missing", 1, true) ~= nil then state.metrics.referenceRejects = state.metrics.referenceRejects + 1 end
        if string.find(compileError or "", "limit", 1, true) ~= nil then state.metrics.limitRejects = state.metrics.limitRejects + 1 end
        if string.find(compileError or "", "duplicate", 1, true) ~= nil then state.metrics.duplicateRejects = state.metrics.duplicateRejects + 1 end
        return nil, compileError
    end
    state.compiled = compiled
    state.metrics.compiles = state.metrics.compiles + 1
    return _clone(compiled)
end

function turret.fixtureSpawn(handle, runtime)
    local state = turret.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    if state.compiled == nil then return nil, "turret definition is not compiled" end
    local source = type(runtime) == "table" and runtime or {}
    state.fixture = {
        protocolVersion = turret.protocolVersion,
        turretId = state.compiled.turretId,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        basePartId = state.compiled.basePartId,
        baseAnchorId = state.compiled.baseAnchorId,
        bodyId = math.floor(_safeNumber(source.bodyId, 0)),
        jointId = state.compiled.joint.jointId,
        angle = math.max(state.compiled.joint.minAngle, math.min(state.compiled.joint.maxAngle, _safeNumber(source.angle, 0.0))),
        lifecycle = "active",
        fixtureOnly = true,
    }
    state.metrics.fixtureSpawns = state.metrics.fixtureSpawns + 1
    return _clone(state.fixture)
end

function turret.fixtureDispose(handle, reason)
    local state = turret.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    if state.fixture == nil then return false, "turret fixture is not spawned" end
    state.fixture.lifecycle = "disposed"
    state.fixture.disposeReason = _safeString(reason, "fixture-dispose")
    state.metrics.fixtureDisposes = state.metrics.fixtureDisposes + 1
    return true, _clone(state.fixture)
end

function turret.snapshot(handle)
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    return { protocolVersion = turret.protocolVersion, identity = turret.state.identity, ownerId = turret.state.ownerId, generation = turret.state.generation, compiled = _clone(turret.state.compiled), fixture = _clone(turret.state.fixture) }
end

function turret.getDiagnostics()
    local state = turret.state
    return {
        protocolVersion = turret.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        fixtureOnly = turret.fixtureOnly,
        compiled = state.compiled ~= nil,
        fixtureSpawned = state.fixture ~= nil,
        fixtureLifecycle = state.fixture ~= nil and state.fixture.lifecycle or "none",
        initCount = state.metrics.initCount,
        compiles = state.metrics.compiles,
        compileRejects = state.metrics.compileRejects,
        fixtureSpawns = state.metrics.fixtureSpawns,
        fixtureDisposes = state.metrics.fixtureDisposes,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
        limitRejects = state.metrics.limitRejects,
        referenceRejects = state.metrics.referenceRejects,
        duplicateRejects = state.metrics.duplicateRejects,
    }
end
