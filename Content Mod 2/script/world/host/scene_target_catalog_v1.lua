-- Scene Target Catalog and Uniform Grid v1.
-- The catalog is a server-owned, fixed-rate observation boundary. It performs
-- no Find*/physics reads; adapters feed spawn, movement and disable updates.

cm2SceneTargetCatalogV1 = cm2SceneTargetCatalogV1 or {}
local catalog = cm2SceneTargetCatalogV1

catalog.protocolVersion = "cm2.world.target-catalog/1"
catalog.minCellSize = 100.0
catalog.maxCellSize = 250.0
catalog.defaultCellSize = 150.0
catalog.minRefreshHz = 5.0
catalog.maxRefreshHz = 10.0
catalog.defaultRefreshHz = 5.0
catalog.maxSnapshotEntries = 512
catalog.maxQueryResults = 128

local function _newState()
    return {
        initialized = false,
        sceneId = "",
        generation = 0,
        revision = 0,
        cellSize = catalog.defaultCellSize,
        refreshHz = catalog.defaultRefreshHz,
        refreshPeriod = 1.0 / catalog.defaultRefreshHz,
        accumulator = 0.0,
        dirty = true,
        targets = {},
        cells = {},
        snapshot = nil,
        clientSnapshot = nil,
        metrics = {
            registers = 0,
            updates = 0,
            moves = 0,
            disables = 0,
            removes = 0,
            refreshes = 0,
            dirtyRefreshes = 0,
            timedRefreshes = 0,
            queryCount = 0,
            candidateChecks = 0,
            queryResults = 0,
            queryBudgetRejected = 0,
            staleRejected = 0,
            disabledSkipped = 0,
            queryCostSamples = 0,
            queryCostTotalMs = 0.0,
            queryCostP95Ms = 0.0,
            maxQueryCandidates = 0,
            maxSnapshotAge = 0.0,
        },
    }
end

catalog.state = catalog.state or _newState()

local function _safeString(value)
    if type(value) ~= "string" or value == "" then return "" end
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

local function _vector(value)
    local source = type(value) == "table" and value or {}
    return {
        x = _safeNumber(source.x or source[1], 0.0),
        y = _safeNumber(source.y or source[2], 0.0),
        z = _safeNumber(source.z or source[3], 0.0),
    }
end

local function _cellCoord(value, cellSize)
    return math.floor(_safeNumber(value, 0.0) / cellSize)
end

local function _cellKey(position, cellSize)
    local x = _cellCoord(position.x, cellSize)
    local y = _cellCoord(position.y, cellSize)
    local z = _cellCoord(position.z, cellSize)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z), x, y, z
end

local function _distanceSquared(left, right)
    local dx = left.x - right.x
    local dy = left.y - right.y
    local dz = left.z - right.z
    return dx * dx + dy * dy + dz * dz
end

local function _removeCell(target)
    if target.cellKey == nil then return end
    local list = catalog.state.cells[target.cellKey]
    if type(list) ~= "table" then target.cellKey = nil; target.cellPosition = nil; return end
    local position = target.cellPosition
    local lastPosition = #list
    if position ~= nil and position >= 1 and position <= lastPosition then
        local lastId = list[lastPosition]
        if position ~= lastPosition then list[position] = lastId; catalog.state.targets[lastId].cellPosition = position end
        list[lastPosition] = nil
    end
    if #list == 0 then catalog.state.cells[target.cellKey] = nil end
    target.cellKey = nil
    target.cellPosition = nil
end

local function _insertCell(target)
    local key = _cellKey(target.position, catalog.state.cellSize)
    local list = catalog.state.cells[key]
    if list == nil then list = {}; catalog.state.cells[key] = list end
    list[#list + 1] = target.entityId
    target.cellKey = key
    target.cellPosition = #list
end

local function _normalizeCapabilities(value)
    local result = {}
    if type(value) ~= "table" then return result end
    for key, child in pairs(value) do
        if type(key) == "number" then result[tostring(child)] = true elseif child == true then result[tostring(key)] = true end
    end
    return result
end

local function _normalizeTarget(target)
    return {
        entityId = _safeString(target.entityId),
        generation = math.max(1, math.floor(_safeNumber(target.generation, catalog.state.generation))),
        position = _vector(target.position),
        velocity = _vector(target.velocity),
        radius = math.max(0.0, _safeNumber(target.radius, 0.0)),
        faction = _safeString(target.faction),
        targetType = _safeString(target.targetType or target.type),
        capabilities = _normalizeCapabilities(target.capabilities),
        tags = _normalizeCapabilities(target.tags),
        enabled = target.enabled ~= false,
        cellKey = nil,
        cellPosition = nil,
    }
end

local function _hasFilterCapability(target, required)
    if required == nil then return true end
    if type(required) ~= "table" then return target.capabilities[tostring(required)] == true end
    for key, child in pairs(required) do
        local capability = type(key) == "number" and tostring(child) or tostring(key)
        if (type(key) == "number" or child == true) and target.capabilities[capability] ~= true then return false end
    end
    return true
end

local function _matchesFilter(target, filter)
    local resolved = type(filter) == "table" and filter or {}
    if resolved.excludeEntityId ~= nil and target.entityId == tostring(resolved.excludeEntityId) then return false end
    if resolved.faction ~= nil and target.faction ~= tostring(resolved.faction) then return false end
    if type(resolved.factions) == "table" and #resolved.factions > 0 then
        local factionFound = false
        for _, faction in ipairs(resolved.factions) do if target.faction == tostring(faction) then factionFound = true; break end end
        if not factionFound then return false end
    end
    if resolved.targetType ~= nil and target.targetType ~= tostring(resolved.targetType) then return false end
    if type(resolved.targetTypes) == "table" and #resolved.targetTypes > 0 then
        local typeFound = false
        for _, targetType in ipairs(resolved.targetTypes) do if target.targetType == tostring(targetType) then typeFound = true; break end end
        if not typeFound then return false end
    end
    if not _hasFilterCapability(target, resolved.capabilities) then return false end
    return true
end

local function _sortById(left, right)
    return tostring(left.entityId) < tostring(right.entityId)
end

local function _sortByDistance(left, right)
    if left.distanceSquared ~= right.distanceSquared then return left.distanceSquared < right.distanceSquared end
    return tostring(left.entityId) < tostring(right.entityId)
end

local function _refreshSnapshot(reason)
    local state = catalog.state
    local entries = {}
    local cells = {}
    for _, target in pairs(state.targets) do
        if target.enabled then
            local entry = _clone(target)
            entry.cellKey = nil
            entry.cellPosition = nil
            entries[#entries + 1] = entry
            local list = cells[target.cellKey]
            if list == nil then list = {}; cells[target.cellKey] = list end
            list[#list + 1] = entry
        else
            state.metrics.disabledSkipped = state.metrics.disabledSkipped + 1
        end
    end
    table.sort(entries, _sortById)
    for _, list in pairs(cells) do table.sort(list, _sortById) end
    state.revision = state.revision + 1
    state.snapshot = {
        protocolVersion = catalog.protocolVersion,
        sceneId = state.sceneId,
        generation = state.generation,
        revision = state.revision,
        stable = true,
        cellSize = state.cellSize,
        refreshHz = state.refreshHz,
        reason = reason or "scheduled",
        entries = entries,
        cells = cells,
    }
    state.dirty = false
    state.metrics.refreshes = state.metrics.refreshes + 1
    if reason == "dirty" then state.metrics.dirtyRefreshes = state.metrics.dirtyRefreshes + 1 else state.metrics.timedRefreshes = state.metrics.timedRefreshes + 1 end
    return state.snapshot
end

function catalog.serverInit(generation, sceneId, options)
    local state = catalog.state
    if state.initialized then return catalog.getDiagnostics() end
    local resolvedOptions = type(options) == "table" and options or {}
    local cellSize = math.max(catalog.minCellSize, math.min(catalog.maxCellSize, _safeNumber(resolvedOptions.cellSize, catalog.defaultCellSize)))
    local refreshHz = math.max(catalog.minRefreshHz, math.min(catalog.maxRefreshHz, _safeNumber(resolvedOptions.refreshHz, catalog.defaultRefreshHz)))
    state.initialized = true
    state.sceneId = _safeString(sceneId)
    if state.sceneId == "" then state.sceneId = "content-scene-1" end
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.revision = 0
    state.cellSize = cellSize
    state.refreshHz = refreshHz
    state.refreshPeriod = 1.0 / refreshHz
    state.accumulator = 0.0
    state.dirty = true
    state.targets = {}
    state.cells = {}
    state.snapshot = nil
    state.clientSnapshot = nil
    state.metrics = {
        registers = 0, updates = 0, moves = 0, disables = 0, removes = 0,
        refreshes = 0, dirtyRefreshes = 0, timedRefreshes = 0, queryCount = 0,
        candidateChecks = 0, queryResults = 0, queryBudgetRejected = 0,
        staleRejected = 0, disabledSkipped = 0, queryCostSamples = 0,
        queryCostTotalMs = 0.0, queryCostP95Ms = 0.0, maxQueryCandidates = 0,
        maxSnapshotAge = 0.0,
    }
    return catalog.getDiagnostics()
end

function catalog.setCellSize(cellSize)
    local state = catalog.state
    if not state.initialized then return false, "catalog is not initialized" end
    local resolved = math.max(catalog.minCellSize, math.min(catalog.maxCellSize, _safeNumber(cellSize, state.cellSize)))
    if resolved == state.cellSize then return true end
    state.cellSize = resolved
    state.cells = {}
    for _, target in pairs(state.targets) do if target.enabled then _insertCell(target) end end
    state.dirty = true
    return true
end

function catalog.registerTarget(target)
    local state = catalog.state
    if not state.initialized then return false, "catalog is not initialized" end
    if type(target) ~= "table" then return false, "target must be a table" end
    local normalized = _normalizeTarget(target)
    if normalized.entityId == "" then return false, "entityId is required" end
    if state.targets[normalized.entityId] ~= nil then return false, "duplicate target entityId" end
    if normalized.generation ~= state.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return false, "target generation is stale" end
    state.targets[normalized.entityId] = normalized
    if normalized.enabled then _insertCell(normalized) end
    state.metrics.registers = state.metrics.registers + 1
    state.dirty = true
    return true
end

function catalog.updateTarget(entityId, generation, position, velocity)
    local state = catalog.state
    local id = _safeString(entityId)
    local target = state.targets[id]
    if not state.initialized or target == nil then return false, "unknown target" end
    if math.floor(_safeNumber(generation, 0)) ~= target.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return false, "target generation is stale" end
    local oldKey = target.cellKey
    target.position = _vector(position)
    target.velocity = _vector(velocity)
    if target.enabled then
        local newKey = _cellKey(target.position, state.cellSize)
        if oldKey ~= newKey then _removeCell(target); _insertCell(target); state.metrics.moves = state.metrics.moves + 1 end
    end
    state.metrics.updates = state.metrics.updates + 1
    state.dirty = true
    return true
end

function catalog.disableTarget(entityId, generation)
    local state = catalog.state
    local id = _safeString(entityId)
    local target = state.targets[id]
    if not state.initialized or target == nil then return false, "unknown target" end
    if math.floor(_safeNumber(generation, 0)) ~= target.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return false, "target generation is stale" end
    if target.enabled then _removeCell(target); target.enabled = false; state.metrics.disables = state.metrics.disables + 1 end
    state.dirty = true
    return true
end

function catalog.removeTarget(entityId, generation)
    local state = catalog.state
    local id = _safeString(entityId)
    local target = state.targets[id]
    if not state.initialized or target == nil then return false, "unknown target" end
    if math.floor(_safeNumber(generation, 0)) ~= target.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return false, "target generation is stale" end
    _removeCell(target)
    state.targets[id] = nil
    state.metrics.removes = state.metrics.removes + 1
    state.dirty = true
    return true
end

function catalog.refresh(reason)
    if not catalog.state.initialized then return nil, "catalog is not initialized" end
    return _clone(_refreshSnapshot(reason or "manual"))
end

function catalog.tick(dt)
    local state = catalog.state
    if not state.initialized then return false end
    state.accumulator = state.accumulator + math.max(0.0, _safeNumber(dt, 0.0))
    if state.dirty then _refreshSnapshot("dirty"); state.accumulator = 0.0; return true end
    if state.accumulator >= state.refreshPeriod then _refreshSnapshot("scheduled"); state.accumulator = state.accumulator - state.refreshPeriod; return true end
    return false
end

function catalog.query(origin, radius, filter)
    local state = catalog.state
    if not state.initialized then return {}, "catalog is not initialized" end
    if state.snapshot == nil then _refreshSnapshot("query-bootstrap") end
    local center = _vector(origin)
    local range = math.max(0.0, _safeNumber(radius, 0.0))
    local centerX = _cellCoord(center.x, state.cellSize)
    local centerY = _cellCoord(center.y, state.cellSize)
    local centerZ = _cellCoord(center.z, state.cellSize)
    local cellRange = math.ceil(range / state.cellSize)
    local candidates = {}
    for x = centerX - cellRange, centerX + cellRange do
        for y = centerY - cellRange, centerY + cellRange do
            for z = centerZ - cellRange, centerZ + cellRange do
                local list = state.snapshot["cells"][tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)]
                if list ~= nil then
                    for _, entry in ipairs(list) do
                        state.metrics.candidateChecks = state.metrics.candidateChecks + 1
                        local distanceSquared = _distanceSquared(center, entry.position)
                        if distanceSquared <= range * range and _matchesFilter(entry, filter) then
                            local result = _clone(entry)
                            result.distanceSquared = distanceSquared
                            candidates[#candidates + 1] = result
                        end
                    end
                end
            end
        end
    end
    table.sort(candidates, _sortByDistance)
    local maxResults = math.max(1, math.min(catalog.maxQueryResults, math.floor(_safeNumber(type(filter) == "table" and filter.maxResults or nil, catalog.maxQueryResults))))
    if #candidates > maxResults then state.metrics.queryBudgetRejected = state.metrics.queryBudgetRejected + (#candidates - maxResults); while #candidates > maxResults do candidates[#candidates] = nil end end
    state.metrics.queryCount = state.metrics.queryCount + 1
    state.metrics.queryResults = state.metrics.queryResults + #candidates
    if #candidates > state.metrics.maxQueryCandidates then state.metrics.maxQueryCandidates = #candidates end
    return candidates
end

function catalog.recordQueryCost(elapsedMs)
    local state = catalog.state
    local sample = math.max(0.0, _safeNumber(elapsedMs, 0.0))
    state.metrics.queryCostSamples = state.metrics.queryCostSamples + 1
    state.metrics.queryCostTotalMs = state.metrics.queryCostTotalMs + sample
    if sample > state.metrics.queryCostP95Ms then state.metrics.queryCostP95Ms = sample end
    return true
end

function catalog.getSnapshot()
    if catalog.state.snapshot == nil then return nil, "snapshot is not ready" end
    return _clone(catalog.state.snapshot)
end

function catalog.clientInit()
    catalog.state.clientSnapshot = nil
    return true
end

function catalog.clientSetSnapshot(snapshot)
    if type(snapshot) ~= "table" or snapshot.protocolVersion ~= catalog.protocolVersion then return false, "target snapshot version is incompatible" end
    if math.floor(_safeNumber(snapshot.generation, 0)) <= 0 then return false, "target snapshot generation is invalid" end
    catalog.state.clientSnapshot = _clone(snapshot)
    return true
end

function catalog.clientGetSnapshot()
    if catalog.state.clientSnapshot == nil then return nil, "client target snapshot is not ready" end
    return _clone(catalog.state.clientSnapshot)
end

function catalog.getDiagnostics()
    local state = catalog.state
    local targetCount = 0
    local cellCount = 0
    for _ in pairs(state.targets) do targetCount = targetCount + 1 end
    for _ in pairs(state.cells) do cellCount = cellCount + 1 end
    local snapshotEntries = 0
    if state.snapshot ~= nil and type(state.snapshot["entries"]) == "table" then snapshotEntries = #state.snapshot["entries"] end
    return {
        protocolVersion = catalog.protocolVersion,
        initialized = state.initialized,
        sceneId = state.sceneId,
        generation = state.generation,
        revision = state.revision,
        cellSize = state.cellSize,
        refreshHz = state.refreshHz,
        targetCount = targetCount,
        enabledCellCount = cellCount,
        snapshotEntries = snapshotEntries,
        dirty = state.dirty,
        registers = state.metrics.registers,
        updates = state.metrics.updates,
        moves = state.metrics.moves,
        disables = state.metrics.disables,
        removes = state.metrics.removes,
        refreshes = state.metrics.refreshes,
        dirtyRefreshes = state.metrics.dirtyRefreshes,
        timedRefreshes = state.metrics.timedRefreshes,
        queryCount = state.metrics.queryCount,
        candidateChecks = state.metrics.candidateChecks,
        queryResults = state.metrics.queryResults,
        queryBudgetRejected = state.metrics.queryBudgetRejected,
        staleRejected = state.metrics.staleRejected,
        queryCostSamples = state.metrics.queryCostSamples,
        queryCostTotalMs = state.metrics.queryCostTotalMs,
        queryCostP95Ms = state.metrics.queryCostP95Ms,
        maxQueryCandidates = state.metrics.maxQueryCandidates,
        maxSnapshotAge = state.metrics.maxSnapshotAge,
    }
end
