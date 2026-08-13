-- Point Defense candidate allocator v1.
-- One candidate pass is shared by every mount on a ship.  This module is an
-- adapter boundary; the existing engine-backed control remains the rollback
-- backend until live S3 evidence promotes this allocator.

cm2PointDefenseAllocatorV1 = cm2PointDefenseAllocatorV1 or {}
local allocator = cm2PointDefenseAllocatorV1

allocator.protocolVersion = "cm2.point-defense-allocator/1"
allocator.defaultCandidateCapacity = 64
allocator.defaultFireBudget = 4

local function _newState()
    return {
        initialized = false,
        generation = 0,
        ships = {},
        metrics = {
            candidateQueries = 0,
            candidatePasses = 0,
            duplicateTickRejects = 0,
            candidateChecks = 0,
            candidateBudgetRejected = 0,
            mountAllocations = 0,
            assignmentRejects = 0,
            cooldownRejects = 0,
            rangeRejects = 0,
            friendRejects = 0,
            occludedRejects = 0,
            destroyedRejects = 0,
            fireBudgetRejects = 0,
            disposedMounts = 0,
            maxCandidates = 0,
        },
    }
end

allocator.state = allocator.state or _newState()

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

local function _cloneInto(target, value)
    for key in pairs(target) do target[key] = nil end
    if type(value) ~= "table" then return target end
    for key, child in pairs(value) do
        target[key] = type(child) == "table" and _clone(child) or child
    end
    return target
end

local function _sortCandidate(left, right)
    local leftPriority = math.floor(_safeNumber(left.priority, 100))
    local rightPriority = math.floor(_safeNumber(right.priority, 100))
    if leftPriority ~= rightPriority then return leftPriority < rightPriority end
    local leftThreat = _safeNumber(left.threatTime, math.huge)
    local rightThreat = _safeNumber(right.threatTime, math.huge)
    if leftThreat ~= rightThreat then return leftThreat < rightThreat end
    local leftDistance = _safeNumber(left.distance, math.huge)
    local rightDistance = _safeNumber(right.distance, math.huge)
    if leftDistance ~= rightDistance then return leftDistance < rightDistance end
    return tostring(left.entityId) < tostring(right.entityId)
end

local function _ship(shipId)
    return allocator.state.ships[_safeString(shipId)]
end

local function _targetClassAllowed(mount, candidate)
    local allowed = mount.targetClasses
    if type(allowed) ~= "table" or #allowed == 0 then return true end
    local candidateClass = tostring(candidate.targetType or candidate.class or "")
    for _, targetClass in ipairs(allowed) do if candidateClass == tostring(targetClass) then return true end end
    return false
end

local function _newMount(mount, index)
    local source = type(mount) == "table" and mount or {}
    local targetClasses = {}
    for _, targetClass in ipairs(source.targetClasses or source.interceptClasses or {}) do targetClasses[#targetClasses + 1] = tostring(targetClass) end
    return {
        mountId = _safeString(source.mountId or source.id) ~= "" and _safeString(source.mountId or source.id) or ("mount-" .. tostring(index)),
        weaponType = _safeString(source.weaponType),
        role = _safeString(source.role or source.pointDefenseRole) ~= "" and _safeString(source.role or source.pointDefenseRole) or "missile",
        maxRange = math.max(1.0, _safeNumber(source.maxRange, 220.0)),
        cooldown = math.max(0.01, _safeNumber(source.cooldown, 0.5)),
        cooldownRemain = math.max(0.0, _safeNumber(source.cooldownRemain, 0.0)),
        targetClasses = targetClasses,
        targetAssignmentLimit = math.max(1, math.floor(_safeNumber(source.targetAssignmentLimit, 1))),
        enabled = source.enabled ~= false,
    }
end

function allocator.serverInit(generation)
    local state = allocator.state
    if state.initialized then return allocator.getDiagnostics() end
    state.initialized = true
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.ships = {}
    state.metrics = {
        candidateQueries = 0, candidatePasses = 0, duplicateTickRejects = 0,
        candidateChecks = 0, candidateBudgetRejected = 0, mountAllocations = 0,
        assignmentRejects = 0, cooldownRejects = 0, rangeRejects = 0,
        friendRejects = 0, occludedRejects = 0, destroyedRejects = 0,
        fireBudgetRejects = 0, disposedMounts = 0, maxCandidates = 0,
    }
    return allocator.getDiagnostics()
end

function allocator.registerShip(shipId, ownerId, mounts, options)
    local state = allocator.state
    local id = _safeString(shipId)
    if not state.initialized then return false, "allocator is not initialized" end
    if id == "" or _safeString(ownerId) == "" then return false, "ship identity is required" end
    if state.ships[id] ~= nil then return false, "duplicate point-defense ship" end
    local resolvedOptions = type(options) == "table" and options or {}
    local normalizedMounts = {}
    for index, mount in ipairs(mounts or {}) do normalizedMounts[#normalizedMounts + 1] = _newMount(mount, index) end
        state.ships[id] = {
        shipId = id,
        ownerId = _safeString(ownerId),
        mounts = normalizedMounts,
            candidates = {},
            candidateBufferKey = "point-defense/candidates/" .. id,
        candidateRevision = 0,
        lastTickId = nil,
        lastAssignments = {},
        backendMode = _safeString(resolvedOptions.backendMode) ~= "" and _safeString(resolvedOptions.backendMode) or "legacy",
        candidateCapacity = math.max(1, math.floor(_safeNumber(resolvedOptions.candidateCapacity, allocator.defaultCandidateCapacity))),
        fireBudgetPerTick = math.max(0, math.floor(_safeNumber(resolvedOptions.fireBudgetPerTick, allocator.defaultFireBudget))),
        metrics = {
            candidatePasses = 0,
            candidateCount = 0,
            candidateBudgetRejected = 0,
            mountAllocations = 0,
            assignmentRejects = 0,
            cooldownRejects = 0,
            rangeRejects = 0,
            friendRejects = 0,
            occludedRejects = 0,
            destroyedRejects = 0,
            fireBudgetRejects = 0,
            disposedMounts = 0,
        },
    }
    return true
end

function allocator.setBackend(shipId, backendMode)
    local ship = _ship(shipId)
    if ship == nil then return false, "unknown point-defense ship" end
    local mode = _safeString(backendMode)
    if mode ~= "legacy" and mode ~= "catalog" then return false, "unknown point-defense backend" end
    ship.backendMode = mode
    return true
end

function allocator.updateCandidates(shipId, candidates, revision, tickId)
    local state = allocator.state
    local ship = _ship(shipId)
    if ship == nil then return false, "unknown point-defense ship" end
    if type(candidates) ~= "table" then return false, "candidate list is required" end
    local batchKey = "point-defense/update/" .. _safeString(shipId)
    if cm2HotpathBudgetV1 ~= nil and cm2HotpathBudgetV1.beginBatch ~= nil then
        cm2HotpathBudgetV1.beginBatch(batchKey)
    end
    local limited = ship.candidates
    if cm2HotpathBudgetV1 ~= nil and cm2HotpathBudgetV1.acquireBuffer ~= nil then
        limited = cm2HotpathBudgetV1.acquireBuffer(ship.candidateBufferKey, ship.candidateCapacity)
    end
    local writeIndex = 0
    for _, candidate in ipairs(candidates) do
        if writeIndex >= ship.candidateCapacity then
            ship.metrics.candidateBudgetRejected = ship.metrics.candidateBudgetRejected + 1
            state.metrics.candidateBudgetRejected = state.metrics.candidateBudgetRejected + 1
        else
            writeIndex = writeIndex + 1
            local copy = limited[writeIndex] or {}
            _cloneInto(copy, candidate)
            copy.entityId = _safeString(copy.entityId)
            copy.generation = math.max(1, math.floor(_safeNumber(copy.generation, state.generation)))
            copy.distance = math.max(0.0, _safeNumber(copy.distance, math.huge))
            copy.threatTime = math.max(0.0, _safeNumber(copy.threatTime, math.huge))
            copy.priority = math.floor(_safeNumber(copy.priority, 100))
            limited[writeIndex] = copy
        end
    end
    for index = #limited, writeIndex + 1, -1 do limited[index] = nil end
    table.sort(limited, _sortCandidate)
    ship.candidates = limited
    ship.candidateRevision = math.floor(_safeNumber(revision, 0))
    ship.lastTickId = nil
    ship.metrics.candidatePasses = ship.metrics.candidatePasses + 1
    ship.metrics.candidateCount = #limited
    state.metrics.candidateQueries = state.metrics.candidateQueries + 1
    state.metrics.candidatePasses = state.metrics.candidatePasses + 1
    if #limited > state.metrics.maxCandidates then state.metrics.maxCandidates = #limited end
    if cm2HotpathBudgetV1 ~= nil and cm2HotpathBudgetV1.batchOperation ~= nil then
        cm2HotpathBudgetV1.batchOperation(batchKey, #candidates)
    end
    if cm2HotpathBudgetV1 ~= nil and cm2HotpathBudgetV1.endBatch ~= nil then
        cm2HotpathBudgetV1.endBatch(batchKey)
    end
    return true
end

function allocator.buildCandidates(shipId, targetCatalog, origin, radius, filter, revision, tickId)
    if type(targetCatalog) ~= "table" or type(targetCatalog.query) ~= "function" then return false, "target catalog query is unavailable" end
    local candidates, errorText = targetCatalog.query(origin, radius, filter)
    if candidates == nil then return false, errorText or "target catalog query failed" end
    return allocator.updateCandidates(shipId, candidates, revision, tickId)
end

function allocator.allocate(shipId, dt, tickId, shipFaction)
    local state = allocator.state
    local ship = _ship(shipId)
    if ship == nil then return {}, "unknown point-defense ship" end
    local resolvedTick = _safeString(tickId) ~= "" and _safeString(tickId) or tostring(math.floor(_safeNumber(dt, 0.0) * 1000.0))
    if ship.lastTickId == resolvedTick then state.metrics.duplicateTickRejects = state.metrics.duplicateTickRejects + 1; return _clone(ship.lastAssignments), "duplicate tick" end
    ship.lastTickId = resolvedTick
    ship.lastAssignments = {}
    local assignmentsByTarget = {}
    local fireBudget = ship.fireBudgetPerTick
    for _, mount in ipairs(ship.mounts) do
        mount.cooldownRemain = math.max(0.0, mount.cooldownRemain - math.max(0.0, _safeNumber(dt, 0.0)))
        if mount.enabled then
            if mount.cooldownRemain > 0.0 then
                ship.metrics.cooldownRejects = ship.metrics.cooldownRejects + 1
                state.metrics.cooldownRejects = state.metrics.cooldownRejects + 1
            elseif fireBudget <= 0 then
                ship.metrics.fireBudgetRejects = ship.metrics.fireBudgetRejects + 1
                state.metrics.fireBudgetRejects = state.metrics.fireBudgetRejects + 1
            else
                local selected = nil
                for _, candidate in ipairs(ship.candidates) do
                    state.metrics.candidateChecks = state.metrics.candidateChecks + 1
                    if candidate.enabled == false then
                        ship.metrics.destroyedRejects = ship.metrics.destroyedRejects + 1
                        state.metrics.destroyedRejects = state.metrics.destroyedRejects + 1
                    elseif candidate.ownerId ~= nil and tostring(candidate.ownerId) == ship.ownerId then
                        ship.metrics.friendRejects = ship.metrics.friendRejects + 1
                        state.metrics.friendRejects = state.metrics.friendRejects + 1
                    elseif shipFaction ~= nil and candidate.faction ~= nil and tostring(candidate.faction) == tostring(shipFaction) then
                        ship.metrics.friendRejects = ship.metrics.friendRejects + 1
                        state.metrics.friendRejects = state.metrics.friendRejects + 1
                    elseif _safeNumber(candidate.distance, math.huge) > mount.maxRange then
                        ship.metrics.rangeRejects = ship.metrics.rangeRejects + 1
                        state.metrics.rangeRejects = state.metrics.rangeRejects + 1
                    elseif candidate.lineOfSight == false then
                        ship.metrics.occludedRejects = ship.metrics.occludedRejects + 1
                        state.metrics.occludedRejects = state.metrics.occludedRejects + 1
                    elseif not _targetClassAllowed(mount, candidate) then
                        ship.metrics.assignmentRejects = ship.metrics.assignmentRejects + 1
                        state.metrics.assignmentRejects = state.metrics.assignmentRejects + 1
                    elseif (assignmentsByTarget[candidate.entityId] or 0) >= mount.targetAssignmentLimit then
                        ship.metrics.assignmentRejects = ship.metrics.assignmentRejects + 1
                        state.metrics.assignmentRejects = state.metrics.assignmentRejects + 1
                    else
                        selected = candidate
                        break
                    end
                end
                if selected ~= nil then
                    assignmentsByTarget[selected.entityId] = (assignmentsByTarget[selected.entityId] or 0) + 1
                    ship.lastAssignments[#ship.lastAssignments + 1] = {
                        mountId = mount.mountId,
                        weaponType = mount.weaponType,
                        role = mount.role,
                        targetEntityId = selected.entityId,
                        targetGeneration = selected.generation,
                        targetType = selected.targetType or selected.class,
                        distance = selected.distance,
                        threatTime = selected.threatTime,
                    }
                    mount.cooldownRemain = mount.cooldown
                    fireBudget = fireBudget - 1
                    ship.metrics.mountAllocations = ship.metrics.mountAllocations + 1
                    state.metrics.mountAllocations = state.metrics.mountAllocations + 1
                end
            end
        end
    end
    return _clone(ship.lastAssignments)
end

function allocator.disposeMount(shipId, mountId)
    local state = allocator.state
    local ship = _ship(shipId)
    if ship == nil then return false, "unknown point-defense ship" end
    local id = _safeString(mountId)
    for index, mount in ipairs(ship.mounts) do
        if mount.mountId == id then
            table.remove(ship.mounts, index)
            ship.lastAssignments = {}
            ship.metrics.disposedMounts = ship.metrics.disposedMounts + 1
            state.metrics.disposedMounts = state.metrics.disposedMounts + 1
            return true
        end
    end
    return false, "unknown point-defense mount"
end

function allocator.clearShip(shipId)
    local id = _safeString(shipId)
    if allocator.state.ships[id] == nil then return false end
    local ship = allocator.state.ships[id]
    if cm2HotpathBudgetV1 ~= nil and cm2HotpathBudgetV1.releaseBuffer ~= nil then
        cm2HotpathBudgetV1.releaseBuffer(ship.candidateBufferKey)
    end
    allocator.state.ships[id] = nil
    return true
end

function allocator.tick(dt)
    return allocator.state.initialized and _safeNumber(dt, 0.0) >= 0.0
end

function allocator.getDiagnostics()
    local state = allocator.state
    local ships = {}
    for shipId, ship in pairs(state.ships) do
        ships[shipId] = {
            ownerId = ship.ownerId,
            backendMode = ship.backendMode,
            mounts = #ship.mounts,
            candidateRevision = ship.candidateRevision,
            candidateCount = ship.metrics.candidateCount,
            candidatePasses = ship.metrics.candidatePasses,
            candidateBudgetRejected = ship.metrics.candidateBudgetRejected,
            mountAllocations = ship.metrics.mountAllocations,
            assignmentRejects = ship.metrics.assignmentRejects,
            cooldownRejects = ship.metrics.cooldownRejects,
            rangeRejects = ship.metrics.rangeRejects,
            friendRejects = ship.metrics.friendRejects,
            occludedRejects = ship.metrics.occludedRejects,
            destroyedRejects = ship.metrics.destroyedRejects,
            fireBudgetRejects = ship.metrics.fireBudgetRejects,
            disposedMounts = ship.metrics.disposedMounts,
        }
    end
    return {
        protocolVersion = allocator.protocolVersion,
        initialized = state.initialized,
        generation = state.generation,
        candidateQueries = state.metrics.candidateQueries,
        candidatePasses = state.metrics.candidatePasses,
        duplicateTickRejects = state.metrics.duplicateTickRejects,
        candidateChecks = state.metrics.candidateChecks,
        candidateBudgetRejected = state.metrics.candidateBudgetRejected,
        mountAllocations = state.metrics.mountAllocations,
        assignmentRejects = state.metrics.assignmentRejects,
        cooldownRejects = state.metrics.cooldownRejects,
        rangeRejects = state.metrics.rangeRejects,
        friendRejects = state.metrics.friendRejects,
        occludedRejects = state.metrics.occludedRejects,
        destroyedRejects = state.metrics.destroyedRejects,
        fireBudgetRejects = state.metrics.fireBudgetRejects,
        disposedMounts = state.metrics.disposedMounts,
        maxCandidates = state.metrics.maxCandidates,
        ships = ships,
    }
end
