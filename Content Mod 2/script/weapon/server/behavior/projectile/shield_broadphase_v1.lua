-- Projectile shield broadphase v1.
-- A stable shield-sphere snapshot and uniform grid reduce P x S scans to local
-- segment candidates (including tangent, inside-start and high-speed paths).
-- The legacy manager remains the default backend.

cm2ProjectileShieldBroadphaseV1 = cm2ProjectileShieldBroadphaseV1 or {}
local broadphase = cm2ProjectileShieldBroadphaseV1

broadphase.protocolVersion = "cm2.projectile.shield-broadphase/1"
broadphase.minCellSize = 100.0
broadphase.maxCellSize = 250.0
broadphase.defaultCellSize = 150.0

local function _newState()
    return {
        initialized = false,
        generation = 0,
        cellSize = broadphase.defaultCellSize,
        revision = 0,
        dirty = true,
        shields = {},
        cells = {},
        snapshot = nil,
        mode = "legacy",
        metrics = {
            registers = 0,
            updates = 0,
            removes = 0,
            refreshes = 0,
            queryCount = 0,
            broadphaseCandidates = 0,
            narrowphaseTests = 0,
            candidateChecks = 0,
            fullRegistryScans = 0,
            hits = 0,
            staleRejected = 0,
            memorySamples = 0,
        },
    }
end

broadphase.state = broadphase.state or _newState()

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

local function _cellKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

local function _insertShieldCells(shield)
    local state = broadphase.state
    local radius = shield.radius
    local minX = _cellCoord(shield.center.x - radius, state.cellSize)
    local maxX = _cellCoord(shield.center.x + radius, state.cellSize)
    local minY = _cellCoord(shield.center.y - radius, state.cellSize)
    local maxY = _cellCoord(shield.center.y + radius, state.cellSize)
    local minZ = _cellCoord(shield.center.z - radius, state.cellSize)
    local maxZ = _cellCoord(shield.center.z + radius, state.cellSize)
    shield.cellKeys = {}
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                local key = _cellKey(x, y, z)
                local list = state.cells[key]
                if list == nil then list = {}; state.cells[key] = list end
                list[#list + 1] = shield.entityId
                shield.cellKeys[#shield.cellKeys + 1] = key
            end
        end
    end
end

local function _removeShieldCells(shield)
    local state = broadphase.state
    for _, key in ipairs(shield.cellKeys or {}) do
        local list = state.cells[key]
        if type(list) == "table" then
            for index = #list, 1, -1 do if list[index] == shield.entityId then table.remove(list, index); break end end
            if #list == 0 then state.cells[key] = nil end
        end
    end
    shield.cellKeys = {}
end

local function _distanceSquared(left, right)
    local dx = left.x - right.x
    local dy = left.y - right.y
    local dz = left.z - right.z
    return dx * dx + dy * dy + dz * dz
end

local function _segmentSphereEntry(startPos, endPos, center, radius)
    local dx = endPos.x - startPos.x
    local dy = endPos.y - startPos.y
    local dz = endPos.z - startPos.z
    local fx = startPos.x - center.x
    local fy = startPos.y - center.y
    local fz = startPos.z - center.z
    if _distanceSquared(startPos, center) <= radius * radius then return 0.0 end
    local aa = dx * dx + dy * dy + dz * dz
    if aa < 0.000001 then return nil end
    local bb = 2.0 * (fx * dx + fy * dy + fz * dz)
    local cc = fx * fx + fy * fy + fz * fz - radius * radius
    local discriminant = bb * bb - 4.0 * aa * cc
    if discriminant < 0.0 then return nil end
    local root = math.sqrt(discriminant)
    local first = (-bb - root) / (2.0 * aa)
    local second = (-bb + root) / (2.0 * aa)
    if first >= 0.0 and first <= 1.0 then return first end
    if second >= 0.0 and second <= 1.0 then return second end
    return nil
end

local function _hitPosition(startPos, endPos, t)
    return {
        x = startPos.x + (endPos.x - startPos.x) * t,
        y = startPos.y + (endPos.y - startPos.y) * t,
        z = startPos.z + (endPos.z - startPos.z) * t,
    }
end

local function _normal(hitPos, center)
    local x = hitPos.x - center.x
    local y = hitPos.y - center.y
    local z = hitPos.z - center.z
    local length = math.sqrt(x * x + y * y + z * z)
    if length < 0.0001 then return { x = 0.0, y = 1.0, z = 0.0 } end
    return { x = x / length, y = y / length, z = z / length }
end

local function _refreshSnapshot(reason)
    local state = broadphase.state
    local entries = {}
    local cells = {}
    local entriesById = {}
    for _, shield in pairs(state.shields) do
        if shield.enabled and shield.shieldHP > 0.0 then
            local entry = _clone(shield)
            entries[#entries + 1] = entry
            entriesById[entry.entityId] = entry
        end
    end
    for _, entry in ipairs(entries) do
        for _, key in ipairs(entry.cellKeys or {}) do
            local list = cells[key]
            if list == nil then list = {}; cells[key] = list end
            list[#list + 1] = entry.entityId
        end
    end
    state.revision = state.revision + 1
    state.snapshot = {
        protocolVersion = broadphase.protocolVersion,
        generation = state.generation,
        revision = state.revision,
        cellSize = state.cellSize,
        reason = reason or "scheduled",
        entries = entries,
        cells = cells,
        entriesById = entriesById,
    }
    state.dirty = false
    state.metrics.refreshes = state.metrics.refreshes + 1
    return state.snapshot
end

function broadphase.serverInit(generation, cellSize)
    local state = broadphase.state
    if state.initialized then return broadphase.getDiagnostics() end
    state.initialized = true
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.cellSize = math.max(broadphase.minCellSize, math.min(broadphase.maxCellSize, _safeNumber(cellSize, broadphase.defaultCellSize)))
    state.revision = 0
    state.dirty = true
    state.shields = {}
    state.cells = {}
    state.snapshot = nil
    state.mode = "legacy"
    state.metrics = {
        registers = 0, updates = 0, removes = 0, refreshes = 0,
        queryCount = 0, broadphaseCandidates = 0, narrowphaseTests = 0,
        candidateChecks = 0, fullRegistryScans = 0, hits = 0,
        staleRejected = 0, memorySamples = 0,
    }
    return broadphase.getDiagnostics()
end

function broadphase.setMode(mode)
    local resolved = _safeString(mode)
    if resolved ~= "legacy" and resolved ~= "grid" then return false, "unknown shield broadphase mode" end
    broadphase.state.mode = resolved
    return true
end

function broadphase.registerShield(entityId, generation, bodyId, center, radius, shieldHP)
    local state = broadphase.state
    local id = _safeString(entityId)
    if not state.initialized then return false, "shield broadphase is not initialized" end
    if id == "" or state.shields[id] ~= nil then return false, "shield identity is invalid or duplicated" end
    local shield = {
        entityId = id,
        generation = math.max(1, math.floor(_safeNumber(generation, 1))),
        bodyId = math.floor(_safeNumber(bodyId, 0)),
        center = _vector(center),
        radius = math.max(0.0, _safeNumber(radius, 0.0)),
        shieldHP = math.max(0.0, _safeNumber(shieldHP, 0.0)),
        enabled = true,
        cellKeys = {},
    }
    state.shields[id] = shield
    _insertShieldCells(shield)
    state.metrics.registers = state.metrics.registers + 1
    state.dirty = true
    return true
end

function broadphase.updateShield(entityId, generation, center, radius, shieldHP)
    local state = broadphase.state
    local id = _safeString(entityId)
    local shield = state.shields[id]
    if shield == nil then return false, "unknown shield" end
    if math.floor(_safeNumber(generation, 0)) ~= shield.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return false, "shield generation is stale" end
    _removeShieldCells(shield)
    shield.center = _vector(center)
    shield.radius = math.max(0.0, _safeNumber(radius, shield.radius))
    shield.shieldHP = math.max(0.0, _safeNumber(shieldHP, shield.shieldHP))
    if shield.shieldHP > 0.0 and shield.enabled then _insertShieldCells(shield) end
    state.metrics.updates = state.metrics.updates + 1
    state.dirty = true
    return true
end

function broadphase.removeShield(entityId, generation)
    local state = broadphase.state
    local id = _safeString(entityId)
    local shield = state.shields[id]
    if shield == nil then return false, "unknown shield" end
    if math.floor(_safeNumber(generation, 0)) ~= shield.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; return false, "shield generation is stale" end
    _removeShieldCells(shield)
    state.shields[id] = nil
    state.metrics.removes = state.metrics.removes + 1
    state.dirty = true
    return true
end

function broadphase.refresh(reason)
    if not broadphase.state.initialized then return nil, "shield broadphase is not initialized" end
    return _clone(_refreshSnapshot(reason or "manual"))
end

function broadphase.tick(dt)
    if not broadphase.state.initialized then return false end
    if broadphase.state.dirty then _refreshSnapshot("dirty"); return true end
    return _safeNumber(dt, 0.0) >= 0.0
end

function broadphase.findEarliest(startPos, endPos, projectileRadius, ownerBodyId)
    local state = broadphase.state
    if not state.initialized then return nil, "shield broadphase is not initialized" end
    if state.snapshot == nil then _refreshSnapshot("query-bootstrap") end
    local start = _vector(startPos)
    local finish = _vector(endPos)
    local radius = math.max(0.0, _safeNumber(projectileRadius, 0.0))
    local minX = math.min(start.x, finish.x) - radius
    local maxX = math.max(start.x, finish.x) + radius
    local minY = math.min(start.y, finish.y) - radius
    local maxY = math.max(start.y, finish.y) + radius
    local minZ = math.min(start.z, finish.z) - radius
    local maxZ = math.max(start.z, finish.z) + radius
    local seen = {}
    local best = nil
    for x = _cellCoord(minX, state.cellSize), _cellCoord(maxX, state.cellSize) do
        for y = _cellCoord(minY, state.cellSize), _cellCoord(maxY, state.cellSize) do
            for z = _cellCoord(minZ, state.cellSize), _cellCoord(maxZ, state.cellSize) do
                local list = state.snapshot["cells"][_cellKey(x, y, z)]
                if list ~= nil then
                    for _, entityId in ipairs(list) do
                        if not seen[entityId] then
                            seen[entityId] = true
                            state.metrics.candidateChecks = state.metrics.candidateChecks + 1
                            state.metrics.broadphaseCandidates = state.metrics.broadphaseCandidates + 1
                            local shield = state.snapshot["entriesById"][entityId]
                            if shield ~= nil and shield.bodyId ~= math.floor(_safeNumber(ownerBodyId, 0)) and shield.enabled and shield.shieldHP > 0.0 then
                                state.metrics.narrowphaseTests = state.metrics.narrowphaseTests + 1
                                local expandedRadius = shield.radius + radius
                                local t = _segmentSphereEntry(start, finish, shield.center, expandedRadius)
                                if t ~= nil and (best == nil or t < best.t) then
                                    local hit = _hitPosition(start, finish, t)
                                    best = {
                                        entityId = shield.entityId,
                                        generation = shield.generation,
                                        bodyId = shield.bodyId,
                                        t = t,
                                        hitPos = hit,
                                        normal = _normal(hit, shield.center),
                                        impactLayer = "shield",
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    state.metrics.queryCount = state.metrics.queryCount + 1
    if best ~= nil then state.metrics.hits = state.metrics.hits + 1 end
    return best
end

function broadphase.recordLegacyScan(count)
    broadphase.state.metrics.fullRegistryScans = broadphase.state.metrics.fullRegistryScans + math.max(0, math.floor(_safeNumber(count, 0)))
    return true
end

function broadphase.getSnapshot()
    if broadphase.state.snapshot == nil then return nil, "shield snapshot is not ready" end
    return _clone(broadphase.state.snapshot)
end

function broadphase.getDiagnostics()
    local state = broadphase.state
    local shieldCount = 0
    for _ in pairs(state.shields) do shieldCount = shieldCount + 1 end
    local snapshotEntries = 0
    if state.snapshot ~= nil and type(state.snapshot["entries"]) == "table" then snapshotEntries = #state.snapshot["entries"] end
    return {
        protocolVersion = broadphase.protocolVersion,
        initialized = state.initialized,
        generation = state.generation,
        mode = state.mode,
        cellSize = state.cellSize,
        revision = state.revision,
        shieldCount = shieldCount,
        snapshotEntries = snapshotEntries,
        dirty = state.dirty,
        registers = state.metrics.registers,
        updates = state.metrics.updates,
        removes = state.metrics.removes,
        refreshes = state.metrics.refreshes,
        queryCount = state.metrics.queryCount,
        broadphaseCandidates = state.metrics.broadphaseCandidates,
        narrowphaseTests = state.metrics.narrowphaseTests,
        candidateChecks = state.metrics.candidateChecks,
        fullRegistryScans = state.metrics.fullRegistryScans,
        hits = state.metrics.hits,
        staleRejected = state.metrics.staleRejected,
        memorySamples = state.metrics.memorySamples,
    }
end
