---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Gate-6 cutover ledger for the five current Vehicle definitions.  It records
-- ownership and feature switches without claiming that live engine golden
-- evidence exists.  Legacy remains the safe source until each vehicle passes
-- the S0-S7 runtime gate.

cm2VehiclePlatformCutoverV1 = cm2VehiclePlatformCutoverV1 or {}
local cutover = cm2VehiclePlatformCutoverV1

cutover.protocolVersion = "cm2.vehicle-platform-cutover/1"
cutover.vehicleOrder = {
    "advancedStrikeCraft",
    "advancedSwarmerMissile",
    "devastatorTorpedo",
    "battlecruiser",
    "titan",
}

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        defaultMode = "legacy",
        rootAuthority = "adapter-only",
        vehicles = {},
        metrics = {
            initCount = 0,
            registrations = 0,
            modeChanges = 0,
            comparisons = 0,
            comparisonPasses = 0,
            comparisonMismatches = 0,
            cutoverRejects = 0,
            rollbacks = 0,
            staleRejects = 0,
            ownerRejects = 0,
        },
    }
end

cutover.state = cutover.state or _newState()

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
    local state = cutover.state
    if type(handle) ~= "table" then return false, "cutover handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "cutover identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "cutover owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "cutover generation is stale" end
    return true
end

local function _vehicleIndex(vehicleType)
    for index, value in ipairs(cutover.vehicleOrder) do if value == vehicleType then return index end end
    return nil
end

local function _newVehicle(vehicleType, index, mode)
    return {
        vehicleType = vehicleType,
        order = index,
        mode = mode,
        previousMode = "legacy",
        factory = "cm2VehicleFactoryV1",
        entityGraph = "cm2EntityGraphV1",
        transformAnchor = "cm2TransformAnchorV1",
        rootBodyAuthority = "adapter-only",
        lifecycle = "registered",
        comparison = nil,
        rollbackReason = "",
        notes = "legacy adapter remains until live S0-S7 evidence",
    }
end

function cutover.serverInit(generation, identity, ownerId, options)
    local state = cutover.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.identity = _safeString(identity, "vehicle-platform-cutover")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.defaultMode = _safeString(resolved.defaultMode, "legacy")
    if state.defaultMode ~= "legacy" and state.defaultMode ~= "shadow" then state.defaultMode = "legacy" end
    state.rootAuthority = "adapter-only"
    state.vehicles = {}
    local initCount = (state.metrics.initCount or 0) + 1
    state.metrics = {
        initCount = initCount, registrations = 0, modeChanges = 0,
        comparisons = 0, comparisonPasses = 0, comparisonMismatches = 0,
        cutoverRejects = 0, rollbacks = 0, staleRejects = 0, ownerRejects = 0,
    }
    for index, vehicleType in ipairs(cutover.vehicleOrder) do
        state.vehicles[vehicleType] = _newVehicle(vehicleType, index, state.defaultMode)
        state.metrics.registrations = state.metrics.registrations + 1
    end
    return cutover.handle()
end

function cutover.handle()
    local state = cutover.state
    return { protocolVersion = cutover.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation }
end

function cutover.getVehicle(vehicleType)
    return cutover.state.vehicles[_safeString(vehicleType)]
end

function cutover.recordComparison(handle, vehicleType, legacyValue, anchorValue, options)
    local state = cutover.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local vehicle = state.vehicles[_safeString(vehicleType)]
    if vehicle == nil then state.metrics.cutoverRejects = state.metrics.cutoverRejects + 1; return false, "unknown vehicle type" end
    local resolved = type(options) == "table" and options or {}
    local equal = true
    if type(legacyValue) ~= type(anchorValue) then equal = false elseif type(legacyValue) == "table" then
        for key, value in pairs(legacyValue) do if value ~= anchorValue[key] then equal = false; break end end
        for key in pairs(anchorValue) do if legacyValue[key] == nil then equal = false; break end end
    elseif legacyValue ~= anchorValue then equal = false end
    vehicle.comparison = {
        equal = equal,
        legacy = _clone(legacyValue),
        anchor = _clone(anchorValue),
        evidence = _safeString(resolved.evidence, "offline-ledger"),
    }
    state.metrics.comparisons = state.metrics.comparisons + 1
    if equal then state.metrics.comparisonPasses = state.metrics.comparisonPasses + 1 else state.metrics.comparisonMismatches = state.metrics.comparisonMismatches + 1 end
    return equal, _clone(vehicle.comparison)
end

function cutover.setMode(handle, vehicleType, mode, note)
    local state = cutover.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local vehicle = state.vehicles[_safeString(vehicleType)]
    local requested = _safeString(mode)
    if vehicle == nil or (requested ~= "legacy" and requested ~= "shadow" and requested ~= "anchor") then state.metrics.cutoverRejects = state.metrics.cutoverRejects + 1; return false, "unknown vehicle or mode" end
    if requested == "anchor" and (vehicle.comparison == nil or vehicle.comparison.equal ~= true) then state.metrics.cutoverRejects = state.metrics.cutoverRejects + 1; return false, "anchor cutover requires a clean comparison" end
    vehicle.previousMode = vehicle.mode
    vehicle.mode = requested
    vehicle.notes = _safeString(note, vehicle.notes)
    state.metrics.modeChanges = state.metrics.modeChanges + 1
    return true, _clone(vehicle)
end

function cutover.rollback(handle, vehicleType, reason)
    local state = cutover.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local vehicle = state.vehicles[_safeString(vehicleType)]
    if vehicle == nil then state.metrics.cutoverRejects = state.metrics.cutoverRejects + 1; return false, "unknown vehicle type" end
    vehicle.previousMode = vehicle.mode
    vehicle.mode = "legacy"
    vehicle.lifecycle = "registered"
    vehicle.rollbackReason = _safeString(reason, "manual cutover rollback")
    state.metrics.rollbacks = state.metrics.rollbacks + 1
    return true, _clone(vehicle)
end

function cutover.validateAll(handle)
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    for _, vehicleType in ipairs(cutover.vehicleOrder) do
        local vehicle = cutover.state.vehicles[vehicleType]
        if vehicle == nil or vehicle.factory == "" or vehicle.entityGraph == "" or vehicle.transformAnchor == "" or vehicle.rootBodyAuthority ~= "adapter-only" then return false, "vehicle cutover ownership is incomplete: " .. vehicleType end
    end
    return true, cutover.snapshot(handle)
end

function cutover.snapshot(handle)
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    return {
        protocolVersion = cutover.protocolVersion,
        identity = cutover.state.identity,
        ownerId = cutover.state.ownerId,
        generation = cutover.state.generation,
        defaultMode = cutover.state.defaultMode,
        rootBodyAuthority = cutover.state.rootAuthority,
        vehicleOrder = _clone(cutover.vehicleOrder),
        vehicles = _clone(cutover.state.vehicles),
    }
end

function cutover.getDiagnostics()
    local state = cutover.state
    local active = 0
    for _, vehicle in pairs(state.vehicles) do if vehicle.mode == "anchor" then active = active + 1 end end
    return {
        protocolVersion = cutover.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        defaultMode = state.defaultMode,
        rootBodyAuthority = state.rootAuthority,
        vehicleCount = #cutover.vehicleOrder,
        anchorModeCount = active,
        registrations = state.metrics.registrations,
        modeChanges = state.metrics.modeChanges,
        comparisons = state.metrics.comparisons,
        comparisonPasses = state.metrics.comparisonPasses,
        comparisonMismatches = state.metrics.comparisonMismatches,
        cutoverRejects = state.metrics.cutoverRejects,
        rollbacks = state.metrics.rollbacks,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
    }
end
