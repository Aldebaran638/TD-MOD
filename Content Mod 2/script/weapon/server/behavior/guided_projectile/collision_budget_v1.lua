-- Budgeted Guided Collision planner v1.
-- Normal operation reserves one continuous sweep; closest-point is reserved for
-- spawn/overlap confirmation. Legacy mode remains available for rollback.

cm2GuidedCollisionBudgetV1 = cm2GuidedCollisionBudgetV1 or {}
local budget = cm2GuidedCollisionBudgetV1

budget.protocolVersion = "cm2.guided-collision-budget/1"
budget.defaultAverageBudget = 3000
budget.defaultHardBudget = 6000
budget.defaultSweepHz = 30.0
budget.defaultClosestHz = 20.0
budget.defaultCriticalDistance = 40.0
budget.defaultCriticalTime = 0.25
budget.defaultMaxSpeed = 240.0

local function _newState()
    return {
        initialized = false,
        generation = 0,
        mode = "legacy",
        averageBudget = budget.defaultAverageBudget,
        hardBudget = budget.defaultHardBudget,
        sweepHz = budget.defaultSweepHz,
        closestHz = budget.defaultClosestHz,
        criticalDistance = budget.defaultCriticalDistance,
        criticalTime = budget.defaultCriticalTime,
        maxSpeed = budget.defaultMaxSpeed,
        windowStart = 0.0,
        windowUsed = 0,
        projectiles = {},
        metrics = {
            plans = 0,
            queryGranted = 0,
            queryRejected = 0,
            degraded = 0,
            sweepQueries = 0,
            closestQueries = 0,
            legacyQueries = 0,
            criticalElevations = 0,
            hits = 0,
            potentialMisses = 0,
            maxWindowQueries = 0,
            phaseSpreadSamples = 0,
        },
    }
end

budget.state = budget.state or _newState()

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _safeString(value)
    if type(value) ~= "string" or value == "" then return "" end
    return value
end

local function _phase(seed, projectileId)
    local numericSeed = math.floor(_safeNumber(seed, 0))
    if numericSeed == 0 then numericSeed = #tostring(projectileId or "") * 37 end
    return (math.abs(numericSeed) % 997) / 997.0
end

local function _newProjectile(projectileId, seed)
    return {
        projectileId = _safeString(projectileId),
        phase = _phase(seed, projectileId),
        age = 0.0,
        sweepAccumulator = 1.0 / budget.state.sweepHz,
        closestAccumulator = 1.0 / budget.state.closestHz,
        firstContactPending = true,
        lastTick = -1,
    }
end

local function _resetWindow(now)
    local state = budget.state
    local current = _safeNumber(now, state.windowStart)
    if current - state.windowStart >= 1.0 then state.windowStart = current; state.windowUsed = 0 end
end

function budget.serverInit(generation, options)
    local state = budget.state
    if state.initialized then return budget.getDiagnostics() end
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.mode = "legacy"
    state.averageBudget = math.max(1, math.floor(_safeNumber(resolved.averageBudget, budget.defaultAverageBudget)))
    state.hardBudget = math.max(state.averageBudget, math.floor(_safeNumber(resolved.hardBudget, budget.defaultHardBudget)))
    state.sweepHz = math.max(1.0, _safeNumber(resolved.sweepHz, budget.defaultSweepHz))
    state.closestHz = math.max(1.0, _safeNumber(resolved.closestHz, budget.defaultClosestHz))
    state.criticalDistance = math.max(0.0, _safeNumber(resolved.criticalDistance, budget.defaultCriticalDistance))
    state.criticalTime = math.max(0.0, _safeNumber(resolved.criticalTime, budget.defaultCriticalTime))
    state.maxSpeed = math.max(1.0, _safeNumber(resolved.maxSpeed, budget.defaultMaxSpeed))
    state.windowStart = 0.0
    state.windowUsed = 0
    state.projectiles = {}
    state.metrics = {
        plans = 0, queryGranted = 0, queryRejected = 0, degraded = 0,
        sweepQueries = 0, closestQueries = 0, legacyQueries = 0,
        criticalElevations = 0, hits = 0, potentialMisses = 0,
        maxWindowQueries = 0, phaseSpreadSamples = 0,
    }
    return budget.getDiagnostics()
end

function budget.setMode(mode)
    local resolved = _safeString(mode)
    if resolved ~= "legacy" and resolved ~= "budgeted" then return false, "unknown guided collision mode" end
    budget.state.mode = resolved
    return true
end

function budget.plan(projectileId, seed, dt, now, distanceToTarget, timeToImpact, speed, turning, firstContact)
    local state = budget.state
    if not state.initialized then return nil, "guided collision budget is not initialized" end
    local id = _safeString(projectileId)
    if id == "" then return nil, "projectileId is required" end
    local projectile = state.projectiles[id]
    if projectile == nil then projectile = _newProjectile(id, seed); state.projectiles[id] = projectile; state.metrics.phaseSpreadSamples = state.metrics.phaseSpreadSamples + 1 end
    local delta = math.max(0.0, _safeNumber(dt, 0.0))
    local currentTime = _safeNumber(now, state.windowStart)
    _resetWindow(currentTime)
    projectile.age = projectile.age + delta
    projectile.sweepAccumulator = projectile.sweepAccumulator + delta
    projectile.closestAccumulator = projectile.closestAccumulator + delta
    state.metrics.plans = state.metrics.plans + 1
    if state.mode == "legacy" then
        state.metrics.legacyQueries = state.metrics.legacyQueries + 5
        return { mode = "legacy", doSweep = true, doClosestPoint = true, queryCost = 5, budgetGranted = true, critical = true }
    end
    local critical = _safeNumber(distanceToTarget, math.huge) <= state.criticalDistance
        or _safeNumber(timeToImpact, math.huge) <= state.criticalTime
        or _safeNumber(speed, 0.0) >= state.maxSpeed
        or turning == true
    if critical then state.metrics.criticalElevations = state.metrics.criticalElevations + 1 end
    local sweepPeriod = 1.0 / state.sweepHz
    local closestPeriod = 1.0 / state.closestHz
    local dueSweep = projectile.sweepAccumulator >= sweepPeriod or critical
    local dueClosest = (firstContact == true or projectile.firstContactPending) and (projectile.closestAccumulator >= closestPeriod or critical)
    local cost = 0
    if dueSweep then cost = cost + 1 end
    if dueClosest then cost = cost + 1 end
    if cost == 0 then return { mode = "budgeted", doSweep = false, doClosestPoint = false, queryCost = 0, budgetGranted = true, critical = critical } end
    if state.windowUsed + cost > state.hardBudget then
        if critical and state.windowUsed < state.hardBudget then
            cost = state.hardBudget - state.windowUsed
            if cost <= 0 then state.metrics.queryRejected = state.metrics.queryRejected + 1; return { mode = "budgeted", doSweep = false, doClosestPoint = false, queryCost = 0, budgetGranted = false, critical = true } end
        else
            state.metrics.queryRejected = state.metrics.queryRejected + 1
            state.metrics.degraded = state.metrics.degraded + 1
            return { mode = "budgeted", doSweep = false, doClosestPoint = false, queryCost = 0, budgetGranted = false, degraded = true, critical = critical }
        end
    elseif state.windowUsed + cost > state.averageBudget then
        if not critical then
            state.metrics.degraded = state.metrics.degraded + 1
            return { mode = "budgeted", doSweep = false, doClosestPoint = false, queryCost = 0, budgetGranted = false, degraded = true, critical = false }
        end
    end
    state.windowUsed = state.windowUsed + cost
    if state.windowUsed > state.metrics.maxWindowQueries then state.metrics.maxWindowQueries = state.windowUsed end
    state.metrics.queryGranted = state.metrics.queryGranted + cost
    if dueSweep then projectile.sweepAccumulator = projectile.sweepAccumulator - sweepPeriod; state.metrics.sweepQueries = state.metrics.sweepQueries + 1 end
    if dueClosest then projectile.closestAccumulator = projectile.closestAccumulator - closestPeriod; projectile.firstContactPending = false; state.metrics.closestQueries = state.metrics.closestQueries + 1 end
    return { mode = "budgeted", doSweep = dueSweep, doClosestPoint = dueClosest, queryCost = cost, budgetGranted = true, critical = critical }
end

function budget.recordHit(projectileId)
    local _ = projectileId
    budget.state.metrics.hits = budget.state.metrics.hits + 1
    return true
end

function budget.recordPotentialMiss(projectileId)
    local _ = projectileId
    budget.state.metrics.potentialMisses = budget.state.metrics.potentialMisses + 1
    return true
end

function budget.clear(projectileId)
    budget.state.projectiles[_safeString(projectileId)] = nil
    return true
end

function budget.getDiagnostics()
    local state = budget.state
    return {
        protocolVersion = budget.protocolVersion,
        initialized = state.initialized,
        generation = state.generation,
        mode = state.mode,
        averageBudget = state.averageBudget,
        hardBudget = state.hardBudget,
        sweepHz = state.sweepHz,
        closestHz = state.closestHz,
        plans = state.metrics.plans,
        queryGranted = state.metrics.queryGranted,
        queryRejected = state.metrics.queryRejected,
        degraded = state.metrics.degraded,
        sweepQueries = state.metrics.sweepQueries,
        closestQueries = state.metrics.closestQueries,
        legacyQueries = state.metrics.legacyQueries,
        criticalElevations = state.metrics.criticalElevations,
        hits = state.metrics.hits,
        potentialMisses = state.metrics.potentialMisses,
        maxWindowQueries = state.metrics.maxWindowQueries,
        phaseSpreadSamples = state.metrics.phaseSpreadSamples,
    }
end
