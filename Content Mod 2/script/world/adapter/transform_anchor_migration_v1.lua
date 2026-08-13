---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Ordered migration facade for systems that currently own their coordinates.
-- Legacy remains the default. Shadow executes both resolvers and records a
-- bounded DTO difference; anchor mode is enabled only after a clean comparison.

cm2TransformAnchorMigrationV1 = cm2TransformAnchorMigrationV1 or {}
local migration = cm2TransformAnchorMigrationV1

migration.protocolVersion = "cm2.transform-anchor-migration/1"
migration.batchOrder = {
    "mount-fire",
    "camera-engine-thruster",
    "weapon-projectile",
    "fx-audio-shake",
    "damage-part-health",
}

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        defaultMode = "legacy",
        batches = {},
        sequence = 0,
        metrics = {
            initCount = 0,
            modeChanges = 0,
            resolves = 0,
            legacyResolves = 0,
            anchorResolves = 0,
            shadowResolves = 0,
            comparisons = 0,
            comparisonPasses = 0,
            comparisonMismatches = 0,
            rollbacks = 0,
            rejects = 0,
            staleRejects = 0,
            ownerRejects = 0,
        },
    }
end

migration.state = migration.state or _newState()

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
    local state = migration.state
    if type(handle) ~= "table" then migration.state.metrics.rejects = migration.state.metrics.rejects + 1; return false, "migration handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "migration identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "migration owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "migration generation is stale" end
    return true
end

local function _batchIndex(batchId)
    for index, value in ipairs(migration.batchOrder) do if value == batchId then return index end end
    return nil
end

local function _newBatch(batchId, index, mode)
    return {
        batchId = batchId,
        order = index,
        mode = mode,
        previousMode = "legacy",
        comparison = nil,
        comparisons = 0,
        mismatches = 0,
        lastRollback = "",
        migrationNote = "",
    }
end

local function _numberEqual(left, right, epsilon)
    return math.abs((tonumber(left) or 0.0) - (tonumber(right) or 0.0)) <= epsilon
end

local function _equal(left, right, epsilon, depth)
    if type(left) == "number" or type(right) == "number" then return _numberEqual(left, right, epsilon) end
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    depth = depth or 0
    if depth > 8 then return false end
    for key, value in pairs(left) do if not _equal(value, right[key], epsilon, depth + 1) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function _diffSummary(left, right, epsilon)
    if _equal(left, right, epsilon, 0) then return { equal = true, field = "", delta = 0.0 } end
    local function firstDifference(a, b, path, depth)
        if depth > 8 then return path, 1.0 end
        if type(a) == "number" or type(b) == "number" then
            return path, math.abs((tonumber(a) or 0.0) - (tonumber(b) or 0.0))
        end
        if type(a) ~= type(b) then return path, 1.0 end
        if type(a) ~= "table" then if a ~= b then return path, 1.0 end; return "", 0.0 end
        for key, value in pairs(a) do
            local field, delta = firstDifference(value, b[key], path .. "." .. tostring(key), depth + 1)
            if field ~= "" then return field, delta end
        end
        for key in pairs(b) do if a[key] == nil then return path .. "." .. tostring(key), 1.0 end end
        return "", 0.0
    end
    local field, delta = firstDifference(left, right, "$", 0)
    return { equal = false, field = field, delta = delta }
end

function migration.serverInit(generation, identity, ownerId, options)
    local state = migration.state
    local resolved = type(options) == "table" and options or {}
    local oldInitCount = state.metrics.initCount or 0
    state.initialized = true
    state.identity = _safeString(identity, "transform-migration")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.defaultMode = _safeString(resolved.defaultMode, "legacy")
    if state.defaultMode ~= "legacy" and state.defaultMode ~= "shadow" then state.defaultMode = "legacy" end
    state.batches = {}
    state.sequence = 0
    state.metrics = {
        initCount = oldInitCount + 1,
        modeChanges = 0, resolves = 0, legacyResolves = 0, anchorResolves = 0,
        shadowResolves = 0, comparisons = 0, comparisonPasses = 0,
        comparisonMismatches = 0, rollbacks = 0, rejects = 0,
        staleRejects = 0, ownerRejects = 0,
    }
    for index, batchId in ipairs(migration.batchOrder) do state.batches[batchId] = _newBatch(batchId, index, state.defaultMode) end
    return migration.handle()
end

function migration.handle()
    local state = migration.state
    return { protocolVersion = migration.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation }
end

function migration.getBatch(batchId)
    return migration.state.batches[_safeString(batchId)]
end

function migration.setBatchMode(handle, batchId, mode, note)
    local state = migration.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local id = _safeString(batchId)
    local batch = state.batches[id]
    local requested = _safeString(mode)
    if batch == nil or (requested ~= "legacy" and requested ~= "shadow" and requested ~= "anchor") then state.metrics.rejects = state.metrics.rejects + 1; return false, "unknown batch or mode" end
    if requested == "anchor" and batch.comparison == nil then state.metrics.rejects = state.metrics.rejects + 1; return false, "anchor mode requires a comparison" end
    if requested == "anchor" and batch.comparison.equal ~= true then state.metrics.rejects = state.metrics.rejects + 1; return false, "anchor mode requires a clean comparison" end
    batch.previousMode = batch.mode
    batch.mode = requested
    batch.migrationNote = _safeString(note, batch.migrationNote)
    state.metrics.modeChanges = state.metrics.modeChanges + 1
    return true, _clone(batch)
end

function migration.recordComparison(handle, batchId, legacyValue, anchorValue, options)
    local state = migration.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local id = _safeString(batchId)
    local batch = state.batches[id]
    if batch == nil then state.metrics.rejects = state.metrics.rejects + 1; return false, "unknown migration batch" end
    local resolved = type(options) == "table" and options or {}
    local epsilon = math.max(0.0, _safeNumber(resolved.epsilon, 0.0001))
    local summary = _diffSummary(legacyValue, anchorValue, epsilon)
    state.sequence = state.sequence + 1
    batch.comparison = {
        sequence = state.sequence,
        epsilon = epsilon,
        equal = summary.equal,
        field = summary.field,
        delta = summary.delta,
        legacy = _clone(legacyValue),
        anchor = _clone(anchorValue),
        evidence = _safeString(resolved.evidence, "offline-dto"),
    }
    batch.comparisons = batch.comparisons + 1
    state.metrics.comparisons = state.metrics.comparisons + 1
    if summary.equal then state.metrics.comparisonPasses = state.metrics.comparisonPasses + 1 else batch.mismatches = batch.mismatches + 1; state.metrics.comparisonMismatches = state.metrics.comparisonMismatches + 1 end
    return summary.equal, _clone(batch.comparison)
end

function migration.resolve(handle, batchId, legacyResolver, anchorResolver, context)
    local state = migration.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    local batch = state.batches[_safeString(batchId)]
    if batch == nil then state.metrics.rejects = state.metrics.rejects + 1; return nil, "unknown migration batch" end
    if type(legacyResolver) ~= "function" then state.metrics.rejects = state.metrics.rejects + 1; return nil, "legacy resolver is required" end
    local legacyValue = legacyResolver(context)
    state.metrics.resolves = state.metrics.resolves + 1
    state.metrics.legacyResolves = state.metrics.legacyResolves + 1
    if batch.mode == "legacy" or type(anchorResolver) ~= "function" then return legacyValue, "legacy" end
    local anchorValue = anchorResolver(context)
    if batch.mode == "shadow" then
        state.metrics.shadowResolves = state.metrics.shadowResolves + 1
        migration.recordComparison(handle, batch.batchId, legacyValue, anchorValue, { evidence = "resolver-shadow" })
        return legacyValue, "shadow"
    end
    state.metrics.anchorResolves = state.metrics.anchorResolves + 1
    return anchorValue, "anchor"
end

function migration.rollback(handle, batchId, reason)
    local state = migration.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local batch = state.batches[_safeString(batchId)]
    if batch == nil then state.metrics.rejects = state.metrics.rejects + 1; return false, "unknown migration batch" end
    batch.previousMode = batch.mode
    batch.mode = "legacy"
    batch.lastRollback = _safeString(reason, "manual rollback")
    state.metrics.rollbacks = state.metrics.rollbacks + 1
    return true, _clone(batch)
end

function migration.snapshot()
    local state = migration.state
    return {
        protocolVersion = migration.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        defaultMode = state.defaultMode,
        batchOrder = _clone(migration.batchOrder),
        batches = _clone(state.batches),
        sequence = state.sequence,
    }
end

function migration.getDiagnostics()
    local state = migration.state
    return {
        protocolVersion = migration.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        defaultMode = state.defaultMode,
        batchCount = #migration.batchOrder,
        sequence = state.sequence,
        initCount = state.metrics.initCount,
        modeChanges = state.metrics.modeChanges,
        resolves = state.metrics.resolves,
        legacyResolves = state.metrics.legacyResolves,
        anchorResolves = state.metrics.anchorResolves,
        shadowResolves = state.metrics.shadowResolves,
        comparisons = state.metrics.comparisons,
        comparisonPasses = state.metrics.comparisonPasses,
        comparisonMismatches = state.metrics.comparisonMismatches,
        rollbacks = state.metrics.rollbacks,
        rejects = state.metrics.rejects,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
    }
end
