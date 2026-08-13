---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

-- Candidate data model for the VOX/Anchor/Mount/Turret 3D Editor.
-- Storage is always parent-local.  World/local display, gizmos, mirror and
-- snapping produce source patches; generated Runtime artifacts are read-only.
-- Gizmo channels include position, rotation, forward, up, muzzle, engine and camera.
-- Mirror/symmetry/snap and deterministic multi-muzzle order are source operations.

cm2AnchorTurretEditorV1 = cm2AnchorTurretEditorV1 or {}
local editor = cm2AnchorTurretEditorV1

editor.protocolVersion = "cm2.anchor-turret-editor/1"
editor.storageSpace = "parent-local"
editor.viewSpaces = { "local", "world" }
editor.modes = { "fixed", "logical", "visual", "joint" }

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
    for key, child in pairs(value) do copy[_clone(key, seen)] = _clone(child, seen) end
    return copy
end

local function _vec(value, fallback)
    local source = type(value) == "table" and value or {}
    local base = fallback or { 0.0, 0.0, 0.0 }
    return { _safeNumber(source[1] or source.x, base[1]), _safeNumber(source[2] or source.y, base[2]), _safeNumber(source[3] or source.z, base[3]) }
end

local function _recordPatch(state, operation, payload)
    state.patches[#state.patches + 1] = { index = #state.patches + 1, operation = operation, storageSpace = editor.storageSpace, payload = _clone(payload or {}) }
    state.metrics.patchCount = #state.patches
end

local function _newState()
    return {
        initialized = false, disposed = false, sourceRevision = 0, viewSpace = "local", activeMode = "logical",
        assetManifest = nil, graph = nil, parts = {}, anchors = {}, mounts = {}, turrets = {}, muzzleOrder = {},
        budgets = {}, budgetLimits = {}, patches = {}, initialSnapshot = nil, metrics = { edits = 0, patchCount = 0, validationErrors = 0, budgetRejects = 0, staleRejects = 0 },
    }
end

editor.state = editor.state or _newState()

local function _graphValid(sourceGraph)
    local graph = type(sourceGraph) == "table" and sourceGraph or editor.state.graph
    local byId = {}
    local roots = 0
    for _, node in ipairs(graph.nodes or {}) do
        local id = _safeString(node.partId or node.nodeId)
        if id == "" or byId[id] ~= nil then return false, "duplicate-id" end
        byId[id] = node
        if _safeString(node.parentId) == "" then roots = roots + 1 end
    end
    if roots ~= 1 then return false, "root-count" end
    local colors = {}
    local function visit(id)
        if colors[id] == 1 then return false, "cycle" end
        if colors[id] == 2 then return true end
        colors[id] = 1
        local parent = _safeString(byId[id].parentId)
        if parent ~= "" then
            if byId[parent] == nil then return false, "missing-parent" end
            local valid, errorText = visit(parent)
            if not valid then return false, errorText end
        end
        colors[id] = 2
        return true
    end
    for id in pairs(byId) do
        local valid, errorText = visit(id)
        if not valid then return false, errorText end
    end
    return true
end

function editor.init(assetManifest, graph, options)
    local manifest = type(assetManifest) == "table" and assetManifest or {}
    local sourceGraph = type(graph) == "table" and graph or {}
    if manifest.readOnly ~= true then return false, "AssetManifest must be read-only" end
    if _safeString(manifest.sourceToVox) == "" or _safeString(manifest.voxToTeardown) == "" then return false, "VOX coordinate mapping is required" end
    if type(sourceGraph.nodes) ~= "table" then return false, "EntityGraph nodes are required" end
    local graphValid, graphError = _graphValid(sourceGraph)
    if not graphValid then return false, graphError end
    local state = _newState()
    state.initialized = true
    state.assetManifest = _clone(manifest)
    state.graph = _clone(sourceGraph)
    state.sourceRevision = math.max(1, math.floor(_safeNumber(options and options.sourceRevision, 1)))
    state.viewSpace = _safeString(options and options.viewSpace, "local") == "world" and "world" or "local"
    state.activeMode = _safeString(options and options.mode, "logical")
    state.budgets = _clone(options and options.budgets or {})
    state.budgetLimits = _clone(options and options.budgetLimits or {})
    editor.state = state
    _recordPatch(state, "init", { assetManifest = manifest.manifestHash, vox = manifest.voxPath, viewSpace = state.viewSpace })
    state.initialSnapshot = _clone(state)
    return true, editor.snapshot()
end

local function _ready()
    return editor.state.initialized and not editor.state.disposed
end

local function _partExists(id)
    for _, node in ipairs(editor.state.graph.nodes or {}) do if _safeString(node.partId or node.nodeId) == id then return true end end
    return false
end

function editor.setViewSpace(space)
    if not _ready() then return false, "editor is not initialized" end
    local requested = _safeString(space, "local")
    if requested ~= "local" and requested ~= "world" then return false, "unsupported view space" end
    editor.state.viewSpace = requested
    _recordPatch(editor.state, "view-space", { space = requested })
    return true
end

function editor.setMode(mode)
    if not _ready() then return false, "editor is not initialized" end
    local requested = _safeString(mode, "logical")
    if requested ~= "fixed" and requested ~= "logical" and requested ~= "visual" and requested ~= "joint" then return false, "unsupported mount mode" end
    editor.state.activeMode = requested
    _recordPatch(editor.state, "mode", { mode = requested })
    return true
end

function editor.addAnchor(anchor)
    if not _ready() then return false, "editor is not initialized" end
    local source = type(anchor) == "table" and anchor or {}
    local id = _safeString(source.id or source.anchorId)
    local parent = _safeString(source.parentPartId)
    if id == "" then return false, "anchor id is required" end
    if editor.state.anchors[id] ~= nil then return false, "duplicate-id" end
    if not _partExists(parent) then return false, "missing-parent" end
    editor.state.anchors[id] = { id = id, parentPartId = parent, kind = _safeString(source.kind, "anchor"), localTransform = _clone(source["local"] or source.localTransform or {}) }
    editor.state.metrics.edits = editor.state.metrics.edits + 1
    _recordPatch(editor.state, "add-anchor", editor.state.anchors[id])
    return true
end

function editor.moveAnchor(anchorId, localTransform)
    if not _ready() then return false, "editor is not initialized" end
    local state = editor.state
    local anchor = state.anchors[_safeString(anchorId)]
    if anchor == nil then return false, "anchor is missing" end
    anchor.localTransform = _clone(localTransform or {})
    state.metrics.edits = state.metrics.edits + 1
    _recordPatch(state, "move-anchor", { id = anchor.id, localTransform = anchor.localTransform })
    return true
end

function editor.mirrorAnchor(anchorId, axis)
    if not _ready() then return false, "editor is not initialized" end
    local state = editor.state
    local anchor = state.anchors[_safeString(anchorId)]
    if anchor == nil then return false, "anchor is missing" end
    local vector = _vec(anchor.localTransform.position or anchor.localTransform.pos)
    local axisName = _safeString(axis, "X")
    local index = axisName == "Y" and 2 or (axisName == "Z" and 3 or 1)
    vector[index] = -vector[index]
    anchor.localTransform.position = vector
    anchor.mirrorOf = anchor.mirrorOf or anchor.id
    state.metrics.edits = state.metrics.edits + 1
    _recordPatch(state, "mirror-anchor", { id = anchor.id, axis = axisName, localPosition = vector })
    return true
end

function editor.snapAnchor(anchorId, gridMeters, gridDegrees)
    if not _ready() then return false, "editor is not initialized" end
    local state = editor.state
    local anchor = state.anchors[_safeString(anchorId)]
    if anchor == nil then return false, "anchor is missing" end
    local grid = math.max(0.0001, _safeNumber(gridMeters, 0.1))
    local vector = _vec(anchor.localTransform.position or anchor.localTransform.pos)
    for index = 1, 3 do vector[index] = math.floor(vector[index] / grid + 0.5) * grid end
    anchor.localTransform.position = vector
    state.metrics.edits = state.metrics.edits + 1
    _recordPatch(state, "snap-anchor", { id = anchor.id, gridMeters = grid, gridDegrees = _safeNumber(gridDegrees, 5), localPosition = vector })
    return true
end

function editor.addMount(mount)
    if not _ready() then return false, "editor is not initialized" end
    local source = type(mount) == "table" and mount or {}
    local id = _safeString(source.id)
    if id == "" then return false, "mount id is required" end
    if editor.state.mounts[id] ~= nil then return false, "duplicate-id" end
    if not _partExists(_safeString(source.parentPartId)) then return false, "missing-parent" end
    editor.state.mounts[id] = _clone(source)
    _recordPatch(editor.state, "add-mount", editor.state.mounts[id])
    return true
end

function editor.addTurret(turret)
    if not _ready() then return false, "editor is not initialized" end
    local source = type(turret) == "table" and turret or {}
    local id = _safeString(source.id)
    if id == "" then return false, "turret id is required" end
    if editor.state.turrets[id] ~= nil then return false, "duplicate-id" end
    if not _partExists(_safeString(source.basePartId)) then return false, "missing-parent" end
    if editor.state.anchors[_safeString(source.baseAnchorId)] == nil then return false, "missing-base-anchor" end
    editor.state.turrets[id] = _clone(source)
    _recordPatch(editor.state, "add-turret", editor.state.turrets[id])
    return true
end

function editor.orderMuzzles(groupId, orderedIds)
    if not _ready() then return false, "editor is not initialized" end
    local list = type(orderedIds) == "table" and orderedIds or {}
    local seen = {}
    for _, id in ipairs(list) do
        if seen[id] then return false, "duplicate-muzzle-order" end
        if editor.state.anchors[_safeString(id)] == nil then return false, "missing-muzzle-anchor" end
        seen[id] = true
    end
    editor.state.muzzleOrder[_safeString(groupId)] = _clone(list)
    _recordPatch(editor.state, "muzzle-order", { groupId = groupId, ordered = list })
    return true
end

function editor.previewArc(turretId)
    if not _ready() then return nil, "editor is not initialized" end
    local turret = editor.state.turrets[_safeString(turretId)]
    if turret == nil then return nil, "turret is missing" end
    local arc = turret.arcPreview or {}
    local samples = math.max(2, math.floor(_safeNumber(arc.samples, 7)))
    local step = _safeNumber(arc.stepDeg, 20)
    local points = {}
    for index = 0, samples - 1 do points[#points + 1] = { yaw = (index - math.floor((samples - 1) / 2)) * step, pitch = 0.0 } end
    _recordPatch(editor.state, "arc-preview", { turretId = turretId, samples = samples })
    return points
end

function editor.getBudget(mode)
    local requested = _safeString(mode, editor.state.activeMode)
    return _clone(editor.state.budgets[requested] or { body = 0, shape = 0, joint = 0 })
end

function editor.validate()
    if not _ready() then return false, { "editor is not initialized" } end
    local valid, errorText = _graphValid(editor.state.graph)
    if not valid then editor.state.metrics.validationErrors = editor.state.metrics.validationErrors + 1; return false, { errorText } end
    local errors = {}
    for id, anchor in pairs(editor.state.anchors) do if not _partExists(anchor.parentPartId) then errors[#errors + 1] = "missing-parent:" .. id end end
    for _, mode in ipairs(editor.modes) do
        local budget = editor.getBudget(mode)
        if budget.joint == nil then errors[#errors + 1] = "budget:" .. mode end
        for _, kind in ipairs({ "body", "shape", "joint" }) do
            local limit = tonumber(editor.state.budgetLimits[kind])
            local cost = tonumber(budget[kind])
            if limit ~= nil and cost ~= nil and cost > limit then
                errors[#errors + 1] = "budget:" .. mode .. ":" .. kind
                editor.state.metrics.budgetRejects = editor.state.metrics.budgetRejects + 1
            end
        end
    end
    return #errors == 0, errors
end

function editor.sourcePatch()
    local state = editor.state
    state.metrics.patchCount = #state.patches
    return { protocolVersion = editor.protocolVersion, sourceRevision = state.sourceRevision, storageSpace = editor.storageSpace, patches = _clone(state.patches), generatedArtifactMutation = false }
end

function editor.snapshot()
    local state = editor.state
    return { protocolVersion = editor.protocolVersion, sourceRevision = state.sourceRevision, viewSpace = state.viewSpace, activeMode = state.activeMode, assetManifest = _clone(state.assetManifest), graph = _clone(state.graph), anchors = _clone(state.anchors), mounts = _clone(state.mounts), turrets = _clone(state.turrets), muzzleOrder = _clone(state.muzzleOrder), patches = #state.patches }
end

function editor.rollback()
    if editor.state.initialSnapshot == nil then return false, "no editor snapshot" end
    local initial = _clone(editor.state.initialSnapshot)
    initial.initialSnapshot = _clone(editor.state.initialSnapshot)
    editor.state = initial
    return true
end

function editor.dispose()
    if not editor.state.initialized or editor.state.disposed then return false end
    editor.state.disposed = true
    return true
end
