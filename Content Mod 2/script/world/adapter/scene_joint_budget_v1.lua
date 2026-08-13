---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Scene-wide physical turret Joint budget.  This is a fixture-safe DTO policy:
-- it ranks requests, keeps the hard cap, and chooses logical/visual fallback
-- without touching Teardown physics APIs.  A future engine adapter may consume
-- the accepted decisions, but it must not bypass this owner.

cm2SceneJointBudgetV1 = cm2SceneJointBudgetV1 or {}
local budget = cm2SceneJointBudgetV1

budget.protocolVersion = "cm2.scene-joint-budget/1"
budget.fixtureOnly = true
budget.defaultHardCap = 16
budget.defaultSoftCap = 12
budget.defaultRecoveryMargin = 2

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        frame = 0,
        hardCap = budget.defaultHardCap,
        softCap = budget.defaultSoftCap,
        recoveryMargin = budget.defaultRecoveryMargin,
        requests = {},
        replay = {},
        sceneMetrics = { physicsBodies = 0, physicsShapes = 0, networkMessages = 0, fxRequests = 0 },
        metrics = {
            requestCount = 0,
            requested = 0,
            granted = 0,
            downgraded = 0,
            grantedTotal = 0,
            downgradedTotal = 0,
            rejected = 0,
            duplicateRejects = 0,
            staleRejects = 0,
            ownerRejects = 0,
            invalidRejects = 0,
            activeJointCost = 0,
            activePhysicsBodies = 0,
            activePhysicsShapes = 0,
            activeNetworkCost = 0,
            activeFxCost = 0,
            degradedNetworkCost = 0,
            degradedFxCost = 0,
            evaluations = 0,
            decisionEvents = 0,
            degradeTransitions = 0,
            recoveries = 0,
            hysteresisHolds = 0,
            ownerDisposals = 0,
            sceneMetricUpdates = 0,
        },
    }
end

budget.state = budget.state or _newState()

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

local function _emit(kind, payload)
    local state = budget.state
    state.metrics.decisionEvents = state.metrics.decisionEvents + 1
    local event = { sequence = #state.replay + 1, frame = state.frame, kind = kind }
    if type(payload) == "table" then
        for key, value in pairs(payload) do event[key] = _clone(value) end
    end
    state.replay[#state.replay + 1] = event
end

local function _validHandle(handle)
    local state = budget.state
    if type(handle) ~= "table" then
        state.metrics.staleRejects = state.metrics.staleRejects + 1
        return false, "scene budget handle is required"
    end
    if _safeString(handle.identity) ~= state.identity then
        state.metrics.staleRejects = state.metrics.staleRejects + 1
        return false, "scene budget identity mismatch"
    end
    if _safeString(handle.ownerId) ~= state.ownerId then
        state.metrics.ownerRejects = state.metrics.ownerRejects + 1
        return false, "scene budget owner mismatch"
    end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then
        state.metrics.staleRejects = state.metrics.staleRejects + 1
        return false, "scene budget generation is stale"
    end
    return true
end

local function _priorityWeight(priority)
    local weights = { critical = 1000, high = 700, normal = 400, low = 100 }
    return weights[_safeString(priority, "normal")]
end

local function _normalizeRequest(descriptor)
    if type(descriptor) ~= "table" then return nil, "joint request descriptor is required" end
    local id = _safeString(descriptor.id)
    local ownerId = _safeString(descriptor.ownerId)
    if id == "" then return nil, "joint request id is required" end
    if ownerId == "" then return nil, "joint request ownerId is required" end
    local requestedMode = _safeString(descriptor.requestedMode, "joint")
    if requestedMode ~= "joint" and requestedMode ~= "logical" and requestedMode ~= "visual" then
        return nil, "joint request mode is invalid"
    end
    local fallback = _safeString(descriptor.fallbackMode, "visual-only")
    if fallback ~= "visual-only" and fallback ~= "logical-only" then
        return nil, "joint fallback mode is invalid"
    end
    local priority = _safeString(descriptor.priority, "normal")
    if _priorityWeight(priority) == nil then return nil, "joint request priority is invalid" end
    local cost = math.max(1, math.floor(_safeNumber(descriptor.jointCost, 1)))
    local physicsBodies = math.max(0, math.floor(_safeNumber(descriptor.physicsBodies, 1)))
    local physicsShapes = math.max(0, math.floor(_safeNumber(descriptor.physicsShapes, physicsBodies)))
    local networkCost = math.max(0, _safeNumber(descriptor.networkCost, 0))
    local fxCost = math.max(0, _safeNumber(descriptor.fxCost, 0))
    return {
        id = id,
        ownerId = ownerId,
        requestedMode = requestedMode,
        fallbackMode = fallback,
        priority = priority,
        distance = math.max(0, _safeNumber(descriptor.distance, 0)),
        screenRelevance = math.max(0, math.min(1, _safeNumber(descriptor.screenRelevance, 0))),
        playerInteractive = descriptor.playerInteractive == true,
        destructionRequired = descriptor.destructionRequired == true,
        jointCost = cost,
        physicsBodies = physicsBodies,
        physicsShapes = physicsShapes,
        networkCost = networkCost,
        fxCost = fxCost,
        mode = "new",
        lastReason = "not-evaluated",
        lastFrame = 0,
    }
end

local function _score(request)
    local distanceBonus = math.max(0, 100 - math.min(100, request.distance)) * 2
    local screenBonus = request.screenRelevance * 100
    local interactiveBonus = request.playerInteractive and 250 or 0
    local destructionBonus = request.destructionRequired and 150 or 0
    return _priorityWeight(request.priority) + distanceBonus + screenBonus + interactiveBonus + destructionBonus
end

local function _protected(request)
    return request.priority == "critical" or request.priority == "high" or request.playerInteractive or request.destructionRequired
end

local function _sortedRequests()
    local list = {}
    for _, request in pairs(budget.state.requests) do list[#list + 1] = request end
    table.sort(list, function(left, right)
        local leftScore = _score(left)
        local rightScore = _score(right)
        if leftScore ~= rightScore then return leftScore > rightScore end
        return left.id < right.id
    end)
    return list
end

function budget.serverInit(generation, options)
    local state = budget.state
    if state.initialized then return budget.getDiagnostics() end
    local resolved = type(options) == "table" and options or {}
    local hardCap = math.max(1, math.floor(_safeNumber(resolved.hardCap, budget.defaultHardCap)))
    local softCap = math.max(1, math.min(hardCap, math.floor(_safeNumber(resolved.softCap, budget.defaultSoftCap))))
    state.initialized = true
    state.identity = _safeString(resolved.identity, "scene-joint-budget")
    state.ownerId = _safeString(resolved.ownerId, "scene-owner")
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.hardCap = hardCap
    state.softCap = softCap
    state.recoveryMargin = math.max(0, math.floor(_safeNumber(resolved.recoveryMargin, budget.defaultRecoveryMargin)))
    state.frame = 0
    state.requests = {}
    state.replay = {}
    state.sceneMetrics = { physicsBodies = 0, physicsShapes = 0, networkMessages = 0, fxRequests = 0 }
    state.metrics = {
        requestCount = 0, requested = 0, granted = 0, downgraded = 0, grantedTotal = 0, downgradedTotal = 0, rejected = 0,
        duplicateRejects = 0, staleRejects = 0, ownerRejects = 0, invalidRejects = 0,
        activeJointCost = 0, activePhysicsBodies = 0, activePhysicsShapes = 0,
        activeNetworkCost = 0, activeFxCost = 0, degradedNetworkCost = 0, degradedFxCost = 0,
        evaluations = 0, decisionEvents = 0, degradeTransitions = 0, recoveries = 0,
        hysteresisHolds = 0, ownerDisposals = 0, sceneMetricUpdates = 0,
    }
    _emit("budget-init", { hardCap = hardCap, softCap = softCap, recoveryMargin = state.recoveryMargin })
    return budget.getDiagnostics()
end

function budget.handle(operation, handle, payload)
    local valid = _validHandle(handle)
    if not valid then return false, "invalid scene budget handle" end
    local op = _safeString(operation)
    if op == "request" then return budget.requestJoint(handle, payload)
    elseif op == "evaluate" then return budget.evaluate(handle)
    elseif op == "release" then return budget.release(handle, _safeString(payload))
    elseif op == "metrics" then return budget.recordSceneMetrics(handle, payload)
    elseif op == "disposeOwner" then return budget.disposeOwner(handle, _safeString(payload))
    elseif op == "snapshot" then return budget.snapshot(handle)
    end
    budget.state.metrics.invalidRejects = budget.state.metrics.invalidRejects + 1
    return false, "unknown scene budget operation"
end

function budget.requestJoint(handle, descriptor)
    local valid = _validHandle(handle)
    if not valid then return false, "invalid scene budget handle" end
    local request, reason = _normalizeRequest(descriptor)
    if request == nil then
        budget.state.metrics.rejected = budget.state.metrics.rejected + 1
        budget.state.metrics.invalidRejects = budget.state.metrics.invalidRejects + 1
        _emit("request-rejected", { reason = reason })
        return false, reason
    end
    if budget.state.requests[request.id] ~= nil then
        budget.state.metrics.rejected = budget.state.metrics.rejected + 1
        budget.state.metrics.duplicateRejects = budget.state.metrics.duplicateRejects + 1
        _emit("request-rejected", { requestId = request.id, reason = "duplicate-id" })
        return false, "duplicate joint request id"
    end
    budget.state.requests[request.id] = request
    budget.state.metrics.requestCount = budget.state.metrics.requestCount + 1
    budget.state.metrics.requested = budget.state.metrics.requested + 1
    _emit("request", { requestId = request.id, ownerId = request.ownerId, jointCost = request.jointCost })
    return true, _clone(request)
end

function budget.evaluate(handle)
    local valid = _validHandle(handle)
    if not valid then return false, "invalid scene budget handle" end
    local state = budget.state
    state.frame = state.frame + 1
    state.metrics.evaluations = state.metrics.evaluations + 1
    state.metrics.granted = 0
    state.metrics.downgraded = 0
    state.metrics.activeJointCost = 0
    state.metrics.activePhysicsBodies = 0
    state.metrics.activePhysicsShapes = 0
    state.metrics.activeNetworkCost = 0
    state.metrics.activeFxCost = 0
    state.metrics.degradedNetworkCost = 0
    state.metrics.degradedFxCost = 0
    local used = 0
    local decisions = {}
    for _, request in ipairs(_sortedRequests()) do
        local previous = request.mode
        local targetMode = request.requestedMode == "joint" and "joint" or (request.requestedMode == "logical" and "logical-only" or "visual-only")
        local reason = "requested-mode"
        if request.requestedMode == "joint" then
            local fitsHard = used + request.jointCost <= state.hardCap
            local fitsSoft = used + request.jointCost <= state.softCap
            local protected = _protected(request)
            local candidate = fitsHard and (protected or fitsSoft)
            if candidate and previous ~= "new" and previous ~= "joint" then
                local remaining = state.hardCap - (used + request.jointCost)
                if remaining < state.recoveryMargin then
                    candidate = false
                    state.metrics.hysteresisHolds = state.metrics.hysteresisHolds + 1
                    reason = "hysteresis-hold"
                else
                    reason = "recovered"
                end
            elseif not fitsHard then
                reason = "hard-cap"
            elseif not fitsSoft and not protected then
                reason = "soft-cap-low-priority"
            else
                reason = "granted"
            end
            if candidate then
                targetMode = "joint"
                used = used + request.jointCost
                state.metrics.granted = state.metrics.granted + 1
                state.metrics.grantedTotal = state.metrics.grantedTotal + 1
                state.metrics.activeJointCost = state.metrics.activeJointCost + request.jointCost
                state.metrics.activePhysicsBodies = state.metrics.activePhysicsBodies + request.physicsBodies
                state.metrics.activePhysicsShapes = state.metrics.activePhysicsShapes + request.physicsShapes
                state.metrics.activeNetworkCost = state.metrics.activeNetworkCost + request.networkCost
                state.metrics.activeFxCost = state.metrics.activeFxCost + request.fxCost
            else
                targetMode = request.fallbackMode
                state.metrics.downgraded = state.metrics.downgraded + 1
                state.metrics.downgradedTotal = state.metrics.downgradedTotal + 1
                state.metrics.degradedNetworkCost = state.metrics.degradedNetworkCost + request.networkCost
                state.metrics.degradedFxCost = state.metrics.degradedFxCost + request.fxCost
            end
        else
            state.metrics.downgraded = state.metrics.downgraded + 1
            state.metrics.downgradedTotal = state.metrics.downgradedTotal + 1
        end
        if previous == "joint" and targetMode ~= "joint" then state.metrics.degradeTransitions = state.metrics.degradeTransitions + 1 end
        if previous ~= "new" and previous ~= "joint" and targetMode == "joint" then state.metrics.recoveries = state.metrics.recoveries + 1 end
        request.mode = targetMode
        request.lastReason = reason
        request.lastFrame = state.frame
        local decision = { requestId = request.id, ownerId = request.ownerId, mode = targetMode, previousMode = previous, reason = reason, jointCost = request.jointCost, score = _score(request) }
        decisions[#decisions + 1] = decision
        _emit("decision", decision)
    end
    return true, _clone({ frame = state.frame, activeJointCost = used, decisions = decisions })
end

function budget.release(handle, requestId)
    local valid = _validHandle(handle)
    if not valid then return false, "invalid scene budget handle" end
    local id = _safeString(requestId)
    if id == "" or budget.state.requests[id] == nil then return false, "joint request not found" end
    budget.state.requests[id] = nil
    _emit("release", { requestId = id })
    return true
end

function budget.recordSceneMetrics(handle, metrics)
    local valid = _validHandle(handle)
    if not valid then return false, "invalid scene budget handle" end
    local source = type(metrics) == "table" and metrics or {}
    budget.state.sceneMetrics = {
        physicsBodies = math.max(0, math.floor(_safeNumber(source.physicsBodies, 0))),
        physicsShapes = math.max(0, math.floor(_safeNumber(source.physicsShapes, 0))),
        networkMessages = math.max(0, math.floor(_safeNumber(source.networkMessages, 0))),
        fxRequests = math.max(0, math.floor(_safeNumber(source.fxRequests, 0))),
    }
    budget.state.metrics.sceneMetricUpdates = budget.state.metrics.sceneMetricUpdates + 1
    _emit("scene-metrics", budget.state.sceneMetrics)
    return true, _clone(budget.state.sceneMetrics)
end

function budget.disposeOwner(handle, requestOwnerId)
    local valid = _validHandle(handle)
    if not valid then return false, "invalid scene budget handle" end
    local owner = _safeString(requestOwnerId)
    if owner == "" then return false, "joint request owner is required" end
    local removed = 0
    for id, request in pairs(budget.state.requests) do
        if request.ownerId == owner then budget.state.requests[id] = nil; removed = removed + 1 end
    end
    budget.state.metrics.ownerDisposals = budget.state.metrics.ownerDisposals + 1
    _emit("owner-dispose", { ownerId = owner, removed = removed })
    return true, removed
end

function budget.snapshot(handle)
    local valid = _validHandle(handle)
    if not valid then return nil, "invalid scene budget handle" end
    local requests = {}
    for id, request in pairs(budget.state.requests) do requests[id] = _clone(request) end
    return {
        protocolVersion = budget.protocolVersion,
        identity = budget.state.identity,
        ownerId = budget.state.ownerId,
        generation = budget.state.generation,
        frame = budget.state.frame,
        hardCap = budget.state.hardCap,
        softCap = budget.state.softCap,
        recoveryMargin = budget.state.recoveryMargin,
        requests = requests,
        sceneMetrics = _clone(budget.state.sceneMetrics),
        metrics = _clone(budget.state.metrics),
        replayLength = #budget.state.replay,
        fixtureOnly = budget.fixtureOnly,
    }
end

function budget.getReplay(handle)
    local valid = _validHandle(handle)
    if not valid then return nil, "invalid scene budget handle" end
    return _clone(budget.state.replay)
end

function budget.getDiagnostics()
    local state = budget.state
    return {
        protocolVersion = budget.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        frame = state.frame,
        hardCap = state.hardCap,
        softCap = state.softCap,
        recoveryMargin = state.recoveryMargin,
        requestCount = state.metrics.requestCount,
        requested = state.metrics.requested,
        granted = state.metrics.granted,
        downgraded = state.metrics.downgraded,
        grantedTotal = state.metrics.grantedTotal,
        downgradedTotal = state.metrics.downgradedTotal,
        rejected = state.metrics.rejected,
        duplicateRejects = state.metrics.duplicateRejects,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
        invalidRejects = state.metrics.invalidRejects,
        activeJointCost = state.metrics.activeJointCost,
        activePhysicsBodies = state.metrics.activePhysicsBodies,
        activePhysicsShapes = state.metrics.activePhysicsShapes,
        activeNetworkCost = state.metrics.activeNetworkCost,
        activeFxCost = state.metrics.activeFxCost,
        degradedNetworkCost = state.metrics.degradedNetworkCost,
        degradedFxCost = state.metrics.degradedFxCost,
        evaluations = state.metrics.evaluations,
        decisionEvents = state.metrics.decisionEvents,
        degradeTransitions = state.metrics.degradeTransitions,
        recoveries = state.metrics.recoveries,
        hysteresisHolds = state.metrics.hysteresisHolds,
        ownerDisposals = state.metrics.ownerDisposals,
        sceneMetricUpdates = state.metrics.sceneMetricUpdates,
        sceneMetrics = _clone(state.sceneMetrics),
        replayLength = #state.replay,
        fixtureOnly = budget.fixtureOnly,
    }
end
