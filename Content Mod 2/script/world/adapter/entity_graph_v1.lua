---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Stable EntityGraph/Part/Anchor resolver v1. Definition and runtime graph
-- records are DTOs; engine handles remain behind the adapter boundary.

cm2EntityGraphV1 = cm2EntityGraphV1 or {}
local graph = cm2EntityGraphV1

graph.protocolVersion = "cm2.entity-graph/1"

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        definitionId = "",
        definitionNodes = {},
        parts = {},
        anchors = {},
        runtimeNodes = {},
        partCache = {},
        anchorCache = {},
        definitionRevision = 0,
        runtimeRevision = 0,
        metrics = {
            definitionLoads = 0,
            definitionRejects = 0,
            runtimeBinds = 0,
            runtimeRejects = 0,
            cyclesRejected = 0,
            missingRejected = 0,
            duplicateRejected = 0,
            partLookups = 0,
            partHits = 0,
            partMisses = 0,
            anchorLookups = 0,
            anchorHits = 0,
            anchorMisses = 0,
            staleRejected = 0,
            ownerRejected = 0,
        },
    }
end

graph.state = graph.state or _newState()

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

local function _count(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function _nodeId(source)
    return _safeString(source.nodeId or source.id)
end

local function _partId(source, fallback)
    return _safeString(source.partId or source.part or fallback)
end

local function _anchorId(source)
    return _safeString(source.anchorId or source.id)
end

local function _resetCaches()
    _clear(graph.state.partCache)
    _clear(graph.state.anchorCache)
end

local function _validateAcyclic(nodes)
    local colors = {}
    local function visit(id)
        if colors[id] == 1 then return false end
        if colors[id] == 2 then return true end
        colors[id] = 1
        local parentId = _safeString(nodes[id].parentId)
        if parentId ~= "" and not nodes[parentId] then return nil, "missing parent: " .. parentId end
        if parentId ~= "" then
            local valid, errorText = visit(parentId)
            if valid == false then return false end
            if valid == nil then return nil, errorText end
        end
        colors[id] = 2
        return true
    end
    for id in pairs(nodes) do
        local valid, errorText = visit(id)
        if valid == false then return false, "cycle detected at " .. id end
        if valid == nil then return nil, errorText end
    end
    return true
end

function graph.serverInit(generation, identity, ownerId, options)
    local state = graph.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.identity = _safeString(identity, "entity-graph")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.definitionId = _safeString(resolved.definitionId, "")
    state.definitionNodes = {}
    state.parts = {}
    state.anchors = {}
    state.runtimeNodes = {}
    state.partCache = {}
    state.anchorCache = {}
    state.definitionRevision = 0
    state.runtimeRevision = 0
    state.metrics = {
        definitionLoads = 0, definitionRejects = 0, runtimeBinds = 0,
        runtimeRejects = 0, cyclesRejected = 0, missingRejected = 0,
        duplicateRejected = 0, partLookups = 0, partHits = 0,
        partMisses = 0, anchorLookups = 0, anchorHits = 0,
        anchorMisses = 0, staleRejected = 0, ownerRejected = 0,
    }
    local rootBodyId = math.floor(_safeNumber(resolved.rootBodyId, 0))
    if rootBodyId ~= 0 then
        local loaded, loadError = graph.loadDefinition({
            definitionId = state.definitionId,
            nodes = { { nodeId = "root", partId = "root", kind = "body", parentId = "", anchors = {} } },
        })
        if not loaded then return nil, loadError end
        local bound, bindError = graph.bindRuntime({
            generation = state.generation,
            ownerId = state.ownerId,
            nodes = { { nodeId = "root", generation = state.generation, ownerId = state.ownerId, bodyId = rootBodyId } },
        })
        if not bound then return nil, bindError end
    end
    return graph.getDiagnostics()
end

function graph.loadDefinition(definition)
    local state = graph.state
    if not state.initialized then return false, "entity graph is not initialized" end
    local source = type(definition) == "table" and definition or {}
    local nodes = {}
    local parts = {}
    local anchors = {}
    local rootCount = 0
    for _, rawNode in ipairs(source.nodes or {}) do
        local id = _nodeId(rawNode)
        if id == "" or nodes[id] ~= nil then
            state.metrics.duplicateRejected = state.metrics.duplicateRejected + 1
            state.metrics.definitionRejects = state.metrics.definitionRejects + 1
            return false, "duplicate or missing node id"
        end
        local node = {
            nodeId = id,
            parentId = _safeString(rawNode.parentId),
            partId = _partId(rawNode, id),
            kind = _safeString(rawNode.kind, "part"),
            anchors = {},
        }
        if node.parentId == "" then rootCount = rootCount + 1 end
        if parts[node.partId] ~= nil then
            state.metrics.duplicateRejected = state.metrics.duplicateRejected + 1
            state.metrics.definitionRejects = state.metrics.definitionRejects + 1
            return false, "duplicate part id: " .. node.partId
        end
        parts[node.partId] = id
        for _, rawAnchor in ipairs(rawNode.anchors or {}) do
            local idValue = _anchorId(rawAnchor)
            if idValue == "" or anchors[idValue] ~= nil then
                state.metrics.duplicateRejected = state.metrics.duplicateRejected + 1
                state.metrics.definitionRejects = state.metrics.definitionRejects + 1
                return false, "duplicate or missing anchor id"
            end
            local anchor = {
                anchorId = idValue,
                nodeId = id,
                localTransform = _clone(rawAnchor.localTransform or rawAnchor.transform or {}),
            }
            node.anchors[#node.anchors + 1] = anchor
            anchors[idValue] = anchor
        end
        nodes[id] = node
    end
    if rootCount ~= 1 then state.metrics.missingRejected = state.metrics.missingRejected + 1; state.metrics.definitionRejects = state.metrics.definitionRejects + 1; return false, "entity graph requires exactly one root" end
    local acyclic, errorText = _validateAcyclic(nodes)
    if acyclic ~= true then
        if errorText ~= nil and string.find(errorText, "cycle", 1, true) ~= nil then state.metrics.cyclesRejected = state.metrics.cyclesRejected + 1 else state.metrics.missingRejected = state.metrics.missingRejected + 1 end
        state.metrics.definitionRejects = state.metrics.definitionRejects + 1
        return false, errorText or "invalid entity graph"
    end
    state.definitionId = _safeString(source.definitionId, state.definitionId)
    state.definitionNodes = nodes
    state.parts = parts
    state.anchors = anchors
    state.definitionRevision = state.definitionRevision + 1
    _resetCaches()
    state.metrics.definitionLoads = state.metrics.definitionLoads + 1
    return true
end

function graph.bindRuntime(runtimeGraph)
    local state = graph.state
    local source = type(runtimeGraph) == "table" and runtimeGraph or {}
    local requestedGeneration = math.floor(_safeNumber(source.generation, state.generation))
    if requestedGeneration ~= state.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; state.metrics.runtimeRejects = state.metrics.runtimeRejects + 1; return false, "runtime generation is stale" end
    if _safeString(source.ownerId, state.ownerId) ~= state.ownerId then state.metrics.ownerRejected = state.metrics.ownerRejected + 1; state.metrics.runtimeRejects = state.metrics.runtimeRejects + 1; return false, "runtime owner mismatch" end
    local runtimeNodes = {}
    for _, rawNode in ipairs(source.nodes or {}) do
        local id = _nodeId(rawNode)
        if id == "" or state.definitionNodes[id] == nil or runtimeNodes[id] ~= nil then state.metrics.runtimeRejects = state.metrics.runtimeRejects + 1; return false, "runtime node missing or duplicate" end
        local generationValue = math.floor(_safeNumber(rawNode.generation, state.generation))
        if generationValue ~= state.generation then state.metrics.staleRejected = state.metrics.staleRejected + 1; state.metrics.runtimeRejects = state.metrics.runtimeRejects + 1; return false, "runtime node generation is stale" end
        if _safeString(rawNode.ownerId, state.ownerId) ~= state.ownerId then state.metrics.ownerRejected = state.metrics.ownerRejected + 1; state.metrics.runtimeRejects = state.metrics.runtimeRejects + 1; return false, "runtime node owner mismatch" end
        runtimeNodes[id] = {
            nodeId = id,
            generation = generationValue,
            ownerId = state.ownerId,
            bodyId = math.floor(_safeNumber(rawNode.bodyId, 0)),
            shapeId = math.floor(_safeNumber(rawNode.shapeId, 0)),
            jointId = math.floor(_safeNumber(rawNode.jointId, 0)),
            transform = _clone(rawNode.transform or {}),
        }
    end
    state.runtimeNodes = runtimeNodes
    state.runtimeRevision = state.runtimeRevision + 1
    _resetCaches()
    state.metrics.runtimeBinds = state.metrics.runtimeBinds + 1
    return true
end

function graph.resolvePart(partId)
    local state = graph.state
    local id = _safeString(partId)
    state.metrics.partLookups = state.metrics.partLookups + 1
    if state.partCache[id] ~= nil then state.metrics.partHits = state.metrics.partHits + 1; return _clone(state.partCache[id]) end
    local nodeId = state.parts[id]
    local definitionNode = nodeId ~= nil and state.definitionNodes[nodeId] or nil
    local runtimeNode = nodeId ~= nil and state.runtimeNodes[nodeId] or nil
    if definitionNode == nil or runtimeNode == nil then state.metrics.partMisses = state.metrics.partMisses + 1; return nil, "part is missing or unbound" end
    local result = {
        protocolVersion = graph.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        partId = id,
        nodeId = nodeId,
        kind = definitionNode.kind,
        bodyId = runtimeNode.bodyId,
        shapeId = runtimeNode.shapeId,
        jointId = runtimeNode.jointId,
        transform = _clone(runtimeNode.transform),
        definitionRevision = state.definitionRevision,
        runtimeRevision = state.runtimeRevision,
    }
    state.partCache[id] = result
    state.metrics.partHits = state.metrics.partHits + 1
    return _clone(result)
end

function graph.resolveAnchor(anchorId)
    local state = graph.state
    local id = _safeString(anchorId)
    state.metrics.anchorLookups = state.metrics.anchorLookups + 1
    if state.anchorCache[id] ~= nil then state.metrics.anchorHits = state.metrics.anchorHits + 1; return _clone(state.anchorCache[id]) end
    local definitionAnchor = state.anchors[id]
    local runtimeNode = definitionAnchor ~= nil and state.runtimeNodes[definitionAnchor.nodeId] or nil
    if definitionAnchor == nil or runtimeNode == nil then state.metrics.anchorMisses = state.metrics.anchorMisses + 1; return nil, "anchor is missing or unbound" end
    local result = {
        protocolVersion = graph.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        anchorId = id,
        nodeId = definitionAnchor.nodeId,
        bodyId = runtimeNode.bodyId,
        shapeId = runtimeNode.shapeId,
        localTransform = _clone(definitionAnchor.localTransform),
        worldTransform = _clone(runtimeNode.transform),
        definitionRevision = state.definitionRevision,
        runtimeRevision = state.runtimeRevision,
    }
    state.anchorCache[id] = result
    state.metrics.anchorHits = state.metrics.anchorHits + 1
    return _clone(result)
end

function graph.snapshot()
    return {
        protocolVersion = graph.protocolVersion,
        identity = graph.state.identity,
        ownerId = graph.state.ownerId,
        generation = graph.state.generation,
        definitionId = graph.state.definitionId,
        definitionRevision = graph.state.definitionRevision,
        runtimeRevision = graph.state.runtimeRevision,
        parts = _clone(graph.state.parts),
        anchors = _clone(graph.state.anchors),
        runtimeNodes = _clone(graph.state.runtimeNodes),
    }
end

function graph.getDiagnostics()
    local state = graph.state
    return {
        protocolVersion = graph.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        definitionId = state.definitionId,
        definitionRevision = state.definitionRevision,
        runtimeRevision = state.runtimeRevision,
        nodeCount = _count(state.definitionNodes),
        partCount = _count(state.parts),
        anchorCount = _count(state.anchors),
        runtimeNodeCount = _count(state.runtimeNodes),
        definitionLoads = state.metrics.definitionLoads,
        definitionRejects = state.metrics.definitionRejects,
        runtimeBinds = state.metrics.runtimeBinds,
        runtimeRejects = state.metrics.runtimeRejects,
        cyclesRejected = state.metrics.cyclesRejected,
        missingRejected = state.metrics.missingRejected,
        duplicateRejected = state.metrics.duplicateRejected,
        partLookups = state.metrics.partLookups,
        partHits = state.metrics.partHits,
        partMisses = state.metrics.partMisses,
        anchorLookups = state.metrics.anchorLookups,
        anchorHits = state.metrics.anchorHits,
        anchorMisses = state.metrics.anchorMisses,
        staleRejected = state.metrics.staleRejected,
        ownerRejected = state.metrics.ownerRejected,
    }
end
