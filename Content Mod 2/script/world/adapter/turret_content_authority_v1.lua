---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: undefined-field

-- Formal Hero turret content boundary.  Mounts are resolved from
-- TurretDefinition + AnchorResolver DTOs; legacy root-Body offsets are rejected
-- for this content.  The module is a fixture candidate and never calls engine
-- Body/Shape/Joint APIs.

cm2TurretContentAuthorityV1 = cm2TurretContentAuthorityV1 or {}
local content = cm2TurretContentAuthorityV1

content.protocolVersion = "cm2.turret-content/1"
content.fixtureOnly = true
content.physicalReady = false

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        mode = "visual",
        definition = nil,
        anchorResolver = {},
        metrics = {
            initCount = 0,
            definitions = 0,
            definitionRejects = 0,
            resolves = 0,
            anchorResolves = 0,
            fallbackResolves = 0,
            missingAnchorRejects = 0,
            legacyFieldRejects = 0,
            modeChanges = 0,
            jointRejects = 0,
            staleRejects = 0,
            ownerRejects = 0,
            previewReads = 0,
        },
    }
end

content.state = content.state or _newState()

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

local function _hasLegacyField(value, seen)
    if type(value) ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    if value.firePosOffset ~= nil or value.fireDirRelative ~= nil then return true end
    for _, child in pairs(value) do
        if _hasLegacyField(child, seen) then return true end
    end
    return false
end

local function _validHandle(handle)
    local state = content.state
    if type(handle) ~= "table" then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "content handle is required" end
    if _safeString(handle.identity) ~= state.identity then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "content identity mismatch" end
    if _safeString(handle.ownerId) ~= state.ownerId then state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "content owner mismatch" end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "content generation is stale" end
    return true
end

local function _validateDefinition(definition)
    if type(definition) ~= "table" then return nil, "formal turret definition is required" end
    if _safeString(definition.schemaVersion) ~= content.protocolVersion then return nil, "formal turret schema mismatch" end
    if _safeString(definition.contentId) == "" or _safeString(definition.turretDefinitionId) == "" then return nil, "formal turret identity is incomplete" end
    for _, field in ipairs({ "entityGraphId", "catalogRef", "editorSchema", "previewProfile", "harnessFixture" }) do
        if _safeString(definition[field]) == "" then return nil, "formal turret reference is missing: " .. field end
    end
    local modes = type(definition.modes) == "table" and definition.modes or {}
    local allowed = {}
    for _, mode in ipairs(modes.allowed or {}) do allowed[_safeString(mode)] = true end
    for _, required in ipairs({ "fixed", "logical", "visual", "joint" }) do
        if not allowed[required] then return nil, "formal turret mode is missing: " .. required end
    end
    local defaultMode = _safeString(modes.default, "visual")
    if not allowed[defaultMode] then return nil, "formal turret default mode is invalid" end
    local anchors = {}
    for key, rawAnchor in pairs(definition.anchors or {}) do
        local anchor = type(rawAnchor) == "table" and rawAnchor or {}
        local anchorId = _safeString(anchor.anchorId or anchor.id or key)
        if anchorId == "" or anchors[anchorId] ~= nil then return nil, "formal turret anchor is duplicate or missing" end
        anchors[anchorId] = _clone(anchor)
        anchors[anchorId].anchorId = anchorId
    end
    local mounts = {}
    local mountIds = {}
    for _, rawMount in ipairs(definition.mounts or {}) do
        local mount = type(rawMount) == "table" and rawMount or {}
        local mountId = _safeString(mount.mountId or mount.id)
        local anchorId = _safeString(mount.fireAnchorId)
        if mountId == "" or mountIds[mountId] then return nil, "formal turret mount is duplicate or missing" end
        if anchorId == "" or anchors[anchorId] == nil then return nil, "formal turret mount anchor is missing: " .. anchorId end
        if _hasLegacyField(mount) then return nil, "formal turret mount contains legacy root-Body offset" end
        mountIds[mountId] = true
        mounts[#mounts + 1] = {
            mountId = mountId,
            fireAnchorId = anchorId,
            weaponGroupId = _safeString(mount.weaponGroupId),
            mirror = _clone(mount.mirror or { x = 1.0, y = 1.0, z = 1.0 }),
            fallbackMode = _safeString(mount.fallbackMode, "visual"),
        }
    end
    if #mounts == 0 then return nil, "formal turret requires at least one mount" end
    return {
        protocolVersion = content.protocolVersion,
        contentId = _safeString(definition.contentId),
        turretDefinitionId = _safeString(definition.turretDefinitionId),
        entityGraphId = _safeString(definition.entityGraphId),
        catalogRef = _safeString(definition.catalogRef),
        editorSchema = _safeString(definition.editorSchema),
        previewProfile = _safeString(definition.previewProfile),
        harnessFixture = _safeString(definition.harnessFixture),
        modes = { default = defaultMode, allowed = _clone(allowed), physicalReady = definition.physicalReady == true },
        anchors = anchors,
        mounts = mounts,
        fixtureOnly = true,
    }
end

function content.serverInit(generation, identity, ownerId, options)
    local state = content.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.identity = _safeString(identity, "turret-content")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.mode = _safeString(resolved.defaultMode, "visual")
    state.definition = nil
    state.anchorResolver = {}
    state.metrics = {
        initCount = (state.metrics.initCount or 0) + 1,
        definitions = 0, definitionRejects = 0, resolves = 0, anchorResolves = 0,
        fallbackResolves = 0, missingAnchorRejects = 0, legacyFieldRejects = 0,
        modeChanges = 0, jointRejects = 0, staleRejects = 0, ownerRejects = 0, previewReads = 0,
    }
    return content.handle()
end

function content.handle()
    local state = content.state
    return { protocolVersion = content.protocolVersion, identity = state.identity, ownerId = state.ownerId, generation = state.generation }
end

function content.registerFormal(handle, definition, anchorResolver)
    local state = content.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local compiled, compileError = _validateDefinition(definition)
    if compiled == nil then state.metrics.definitionRejects = state.metrics.definitionRejects + 1; if string.find(compileError or "", "legacy", 1, true) then state.metrics.legacyFieldRejects = state.metrics.legacyFieldRejects + 1 end; return false, compileError end
    state.definition = compiled
    state.anchorResolver = _clone(type(anchorResolver) == "table" and anchorResolver or {})
    state.mode = compiled.modes.default
    state.metrics.definitions = state.metrics.definitions + 1
    return true, _clone(compiled)
end

function content.setMode(handle, requestedMode)
    local state = content.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    local mode = _safeString(requestedMode)
    if mode ~= "fixed" and mode ~= "logical" and mode ~= "visual" and mode ~= "joint" then return false, "formal turret mode is invalid" end
    if mode == "joint" and not content.physicalReady then state.metrics.jointRejects = state.metrics.jointRejects + 1; return false, "physical joint mode is fixture-disabled" end
    if state.definition ~= nil and not state.definition.modes.allowed[mode] then return false, "formal turret mode is not declared" end
    if state.mode ~= mode then state.metrics.modeChanges = state.metrics.modeChanges + 1 end
    state.mode = mode
    return true, state.mode
end

function content.resolveFireMount(handle, mountId, resolverOverride)
    local state = content.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    if state.definition == nil then return nil, "formal turret is not registered" end
    local id = _safeString(mountId)
    local mount = nil
    for _, candidate in ipairs(state.definition.mounts) do if candidate.mountId == id then mount = candidate; break end end
    if mount == nil then return nil, "formal turret mount is missing" end
    local override = type(resolverOverride) == "table" and resolverOverride or {}
    if _hasLegacyField(override) then state.metrics.legacyFieldRejects = state.metrics.legacyFieldRejects + 1; return nil, "legacy root-Body offset is forbidden" end
    if state.mode == "joint" and not content.physicalReady then state.metrics.jointRejects = state.metrics.jointRejects + 1; return nil, "physical joint mode is fixture-disabled" end
    state.metrics.resolves = state.metrics.resolves + 1
    local anchors = override.anchors or state.anchorResolver.anchors or state.anchorResolver
    local anchor = anchors[mount.fireAnchorId]
    if anchor == nil then
        state.metrics.missingAnchorRejects = state.metrics.missingAnchorRejects + 1
        state.metrics.fallbackResolves = state.metrics.fallbackResolves + 1
        return {
            protocolVersion = content.protocolVersion,
            contentId = state.definition.contentId,
            mountId = mount.mountId,
            anchorId = mount.fireAnchorId,
            mode = state.mode,
            source = mount.fallbackMode .. "-fallback",
            fallback = true,
            reason = "anchor-missing",
        }
    end
    state.metrics.anchorResolves = state.metrics.anchorResolves + 1
    return {
        protocolVersion = content.protocolVersion,
        contentId = state.definition.contentId,
        mountId = mount.mountId,
        anchorId = mount.fireAnchorId,
        mode = state.mode,
        source = "anchor-resolver",
        fallback = false,
        transform = _clone(anchor.transform or anchor.worldTransform or anchor),
        direction = _clone(anchor.direction or { x = 0.0, y = 0.0, z = -1.0 }),
        mirror = _clone(mount.mirror),
    }
end

function content.previewSnapshot(handle)
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    if content.state.definition == nil then return nil, "formal turret is not registered" end
    content.state.metrics.previewReads = content.state.metrics.previewReads + 1
    return {
        protocolVersion = content.protocolVersion,
        contentId = content.state.definition.contentId,
        catalogRef = content.state.definition.catalogRef,
        editorSchema = content.state.definition.editorSchema,
        previewProfile = content.state.definition.previewProfile,
        entityGraphId = content.state.definition.entityGraphId,
        tree = { "base", "yaw", "pitch", "anchors", "mounts" },
        mode = content.state.mode,
        fixtureOnly = content.fixtureOnly,
    }
end

function content.snapshot(handle)
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    return { protocolVersion = content.protocolVersion, identity = content.state.identity, ownerId = content.state.ownerId, generation = content.state.generation, mode = content.state.mode, definition = _clone(content.state.definition) }
end

function content.getDiagnostics()
    local state = content.state
    return {
        protocolVersion = content.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        mode = state.mode,
        fixtureOnly = content.fixtureOnly,
        physicalReady = content.physicalReady,
        registered = state.definition ~= nil,
        definitions = state.metrics.definitions,
        definitionRejects = state.metrics.definitionRejects,
        resolves = state.metrics.resolves,
        anchorResolves = state.metrics.anchorResolves,
        fallbackResolves = state.metrics.fallbackResolves,
        missingAnchorRejects = state.metrics.missingAnchorRejects,
        legacyFieldRejects = state.metrics.legacyFieldRejects,
        modeChanges = state.metrics.modeChanges,
        jointRejects = state.metrics.jointRejects,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
        previewReads = state.metrics.previewReads,
    }
end
