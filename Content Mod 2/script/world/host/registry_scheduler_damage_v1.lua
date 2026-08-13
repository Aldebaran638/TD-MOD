-- Host-side Registry Snapshot, Scheduler and Damage Inbox data plane.
-- A service cycle freezes one DTO snapshot; adapters consume only their own
-- inbox. This module performs no engine/physics reads and leaves final damage
-- application to the existing server authority.

cm2RegistrySchedulerDamageV1 = cm2RegistrySchedulerDamageV1 or {}
local dataPlane = cm2RegistrySchedulerDamageV1

dataPlane.protocolVersion = "cm2.world.services/1"
dataPlane.snapshotSchema = "cm2.entity-snapshot/1"
dataPlane.damageSchema = "cm2.damage-inbox/1"
dataPlane.maxTasks = 64
dataPlane.maxDamageInbox = 256

local function _newState()
    return {
        initialized = false,
        generation = 0,
        revision = 0,
        cycle = 0,
        snapshotFrozen = false,
        entities = {},
        snapshot = nil,
        tasks = {},
        taskOrder = {},
        inbox = {},
        seenDamage = {},
        metrics = {
            registryReadPasses = 0,
            entityTransformReads = 0,
            globalDamageReads = 0,
            damageEnqueued = 0,
            damageDuplicateRejected = 0,
            damageStaleRejected = 0,
            damageApplied = 0,
            schedulerTicks = 0,
            schedulerRuns = 0,
            schedulerBudgetRejected = 0,
            snapshotRejects = 0,
            maxQueueDepth = 0,
        },
    }
end

dataPlane.state = dataPlane.state or _newState()

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback end
    return value
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

local function _sortBySequence(left, right)
    local leftSequence = math.floor(_safeNumber(left.sequence, 0))
    local rightSequence = math.floor(_safeNumber(right.sequence, 0))
    if leftSequence ~= rightSequence then return leftSequence < rightSequence end
    return tostring(left.eventId or "") < tostring(right.eventId or "")
end

local function _sortTask(left, right)
    local leftPriority = math.floor(_safeNumber(left.priority, 0))
    local rightPriority = math.floor(_safeNumber(right.priority, 0))
    if leftPriority ~= rightPriority then return leftPriority > rightPriority end
    return tostring(left.taskId) < tostring(right.taskId)
end

function dataPlane.serverInit(generation)
    local state = dataPlane.state
    if state.initialized then return dataPlane.getDiagnostics() end
    state.initialized = true
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.revision = 0
    state.cycle = 0
    state.snapshotFrozen = false
    state.entities = {}
    state.snapshot = nil
    state.tasks = {}
    state.taskOrder = {}
    state.inbox = {}
    state.seenDamage = {}
    state.metrics = {
        registryReadPasses = 0,
        entityTransformReads = 0,
        globalDamageReads = 0,
        damageEnqueued = 0,
        damageDuplicateRejected = 0,
        damageStaleRejected = 0,
        damageApplied = 0,
        schedulerTicks = 0,
        schedulerRuns = 0,
        schedulerBudgetRejected = 0,
        snapshotRejects = 0,
        maxQueueDepth = 0,
    }
    return dataPlane.getDiagnostics()
end

function dataPlane.beginSnapshotCycle(generation)
    local state = dataPlane.state
    if not state.initialized then return false, "data plane is not initialized" end
    local requestedGeneration = math.floor(_safeNumber(generation, state.generation))
    if requestedGeneration ~= state.generation then state.metrics.snapshotRejects = state.metrics.snapshotRejects + 1; return false, "snapshot generation mismatch" end
    state.cycle = state.cycle + 1
    state.revision = state.revision + 1
    state.snapshotFrozen = false
    state.entities = {}
    state.snapshot = nil
    state.metrics.registryReadPasses = state.metrics.registryReadPasses + 1
    return true
end

function dataPlane.addEntity(entity)
    local state = dataPlane.state
    if not state.initialized or state.snapshotFrozen then state.metrics.snapshotRejects = state.metrics.snapshotRejects + 1; return false, "snapshot is frozen" end
    if type(entity) ~= "table" or _safeString(entity.entityId, "") == "" then state.metrics.snapshotRejects = state.metrics.snapshotRejects + 1; return false, "entityId is required" end
    if entity.generation ~= nil and math.floor(_safeNumber(entity.generation, 0)) ~= state.generation then state.metrics.snapshotRejects = state.metrics.snapshotRejects + 1; return false, "entity generation is stale" end
    state.entities[#state.entities + 1] = _clone(entity)
    return true
end

function dataPlane.freezeSnapshot()
    local state = dataPlane.state
    if not state.initialized then return nil, "data plane is not initialized" end
    state.snapshot = {
        protocolVersion = dataPlane.protocolVersion,
        schema = dataPlane.snapshotSchema,
        generation = state.generation,
        revision = state.revision,
        cycle = state.cycle,
        entities = _clone(state.entities),
    }
    state.snapshotFrozen = true
    return _clone(state.snapshot)
end

function dataPlane.getSnapshot()
    if dataPlane.state.snapshot == nil then return nil, "snapshot is not frozen" end
    return _clone(dataPlane.state.snapshot)
end

function dataPlane.registerTask(taskId, ownerId, frequencyHz, priority, budget, stagger)
    local state = dataPlane.state
    if not state.initialized then return false, "data plane is not initialized" end
    local id = _safeString(taskId, "")
    if id == "" or _safeString(ownerId, "") == "" then return false, "task identity is required" end
    if state.tasks[id] ~= nil then return false, "duplicate scheduler task" end
    local taskCount = 0
    for _key in pairs(state.tasks) do taskCount = taskCount + 1 end
    if taskCount >= dataPlane.maxTasks then return false, "scheduler task capacity exhausted" end
    local hz = math.max(0.1, _safeNumber(frequencyHz, 1.0))
    local item = { taskId = id, ownerId = ownerId, frequencyHz = hz, period = 1.0 / hz, priority = math.floor(_safeNumber(priority, 0)), budget = math.max(1, math.floor(_safeNumber(budget, 1))), stagger = math.max(0.0, _safeNumber(stagger, 0.0)), accumulator = math.max(0.0, _safeNumber(stagger, 0.0)), runs = 0, rejected = 0 }
    state.tasks[id] = item
    state.taskOrder[#state.taskOrder + 1] = item
    table.sort(state.taskOrder, _sortTask)
    return true
end

function dataPlane.unregisterTask(taskId, ownerId)
    local state = dataPlane.state
    local id = _safeString(taskId, "")
    local task = state.tasks[id]
    if task == nil then return false, "unknown scheduler task" end
    if task.ownerId ~= ownerId then return false, "scheduler owner mismatch" end
    state.tasks[id] = nil
    for index, item in ipairs(state.taskOrder) do
        if item.taskId == id then table.remove(state.taskOrder, index); break end
    end
    return true
end

function dataPlane.tickScheduler(dt)
    local state = dataPlane.state
    if not state.initialized then return 0 end
    local delta = math.max(0.0, _safeNumber(dt, 0.0))
    state.metrics.schedulerTicks = state.metrics.schedulerTicks + 1
    local runs = 0
    for _, task in ipairs(state.taskOrder) do
        task.accumulator = task.accumulator + delta
        if task.accumulator >= task.period then
            task.accumulator = task.accumulator - task.period
            local allowed = task.budget
            if allowed > 0 then
                task.runs = task.runs + 1
                state.metrics.schedulerRuns = state.metrics.schedulerRuns + 1
                runs = runs + 1
            else
                task.rejected = task.rejected + 1
                state.metrics.schedulerBudgetRejected = state.metrics.schedulerBudgetRejected + 1
            end
        end
    end
    return runs
end

function dataPlane.ingestGlobalDamage(event)
    local state = dataPlane.state
    if not state.initialized then return false, "data plane is not initialized" end
    state.metrics.globalDamageReads = state.metrics.globalDamageReads + 1
    if type(event) ~= "table" then return false, "damage event must be a table" end
    local eventId = _safeString(event.eventId, "")
    local ownerId = _safeString(event.ownerId, "")
    local bodyId = _safeString(event.bodyId, "")
    local sequence = math.floor(_safeNumber(event.sequence, 0))
    if eventId == "" or ownerId == "" or bodyId == "" or sequence < 1 then return false, "damage identity is incomplete" end
    if state.seenDamage[eventId] then state.metrics.damageDuplicateRejected = state.metrics.damageDuplicateRejected + 1; return false, "duplicate damage event" end
    if event.generation ~= nil and math.floor(_safeNumber(event.generation, 0)) ~= state.generation then state.metrics.damageStaleRejected = state.metrics.damageStaleRejected + 1; return false, "stale damage generation" end
    state.seenDamage[eventId] = true
    local inbox = state.inbox[ownerId]
    if inbox == nil then inbox = {}; state.inbox[ownerId] = inbox end
    if #inbox >= dataPlane.maxDamageInbox then return false, "damage inbox capacity exhausted" end
    inbox[#inbox + 1] = {
        schema = dataPlane.damageSchema,
        eventId = eventId,
        ownerId = ownerId,
        bodyId = bodyId,
        cellId = _safeString(event.cellId, ""),
        sequence = sequence,
        generation = state.generation,
        amount = math.max(0.0, _safeNumber(event.amount, 0.0)),
    }
    table.sort(inbox, _sortBySequence)
    state.metrics.damageEnqueued = state.metrics.damageEnqueued + 1
    state.metrics.maxQueueDepth = math.max(state.metrics.maxQueueDepth, #inbox)
    return true
end

function dataPlane.consumeDamage(ownerId, maxEvents)
    local state = dataPlane.state
    local id = _safeString(ownerId, "")
    local inbox = state.inbox[id] or {}
    local limit = math.max(0, math.floor(_safeNumber(maxEvents, #inbox)))
    local result = {}
    while #result < limit and #inbox > 0 do
        result[#result + 1] = table.remove(inbox, 1)
        state.metrics.damageApplied = state.metrics.damageApplied + 1
    end
    state.inbox[id] = inbox
    return result
end

function dataPlane.getDiagnostics()
    local state = dataPlane.state
    local snapshotEntities = 0
    if type(state.snapshot) == "table" and type(state.snapshot["entities"]) == "table" then snapshotEntities = #state.snapshot["entities"] end
    return {
        protocolVersion = dataPlane.protocolVersion,
        snapshotSchema = dataPlane.snapshotSchema,
        damageSchema = dataPlane.damageSchema,
        initialized = state.initialized,
        generation = state.generation,
        revision = state.revision,
        cycle = state.cycle,
        snapshotFrozen = state.snapshotFrozen,
        snapshotEntities = snapshotEntities,
        registryReadPasses = state.metrics.registryReadPasses,
        entityTransformReads = state.metrics.entityTransformReads,
        globalDamageReads = state.metrics.globalDamageReads,
        damageEnqueued = state.metrics.damageEnqueued,
        damageDuplicateRejected = state.metrics.damageDuplicateRejected,
        damageStaleRejected = state.metrics.damageStaleRejected,
        damageApplied = state.metrics.damageApplied,
        schedulerTicks = state.metrics.schedulerTicks,
        schedulerRuns = state.metrics.schedulerRuns,
        schedulerBudgetRejected = state.metrics.schedulerBudgetRejected,
        maxQueueDepth = state.metrics.maxQueueDepth,
    }
end
