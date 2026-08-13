---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Transform/Anchor v1 is the single coordinate contract for ships.  It accepts
-- DTOs from EntityGraph and never reads a Teardown Body/Shape directly.  Every
-- result carries identity, owner, generation and source revision so callers
-- cannot accidentally use a transform from a disposed/reloaded instance.

cm2TransformAnchorV1 = cm2TransformAnchorV1 or {}
local transform = cm2TransformAnchorV1

transform.protocolVersion = "cm2.transform-anchor/1"
transform.units = "meters"
transform.frame = "right-handed-y-up"

local function _newState()
    return {
        initialized = false,
        identity = "",
        ownerId = "",
        generation = 0,
        sourceRevision = 0,
        units = transform.units,
        frame = transform.frame,
        parts = {},
        anchors = {},
        partCache = {},
        anchorCache = {},
        invalidationReason = "init",
        metrics = {
            initCount = 0,
            binds = 0,
            bindRejects = 0,
            partLookups = 0,
            partHits = 0,
            partMisses = 0,
            anchorLookups = 0,
            anchorHits = 0,
            anchorMisses = 0,
            staleRejects = 0,
            ownerRejects = 0,
            invalidHandleRejects = 0,
            invalidTransformRejects = 0,
            invalidations = 0,
            basisLookups = 0,
            velocityLookups = 0,
            scaleLookups = 0,
            mirrorLookups = 0,
        },
    }
end

transform.state = transform.state or _newState()

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback or "" end
    return value
end

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _component(value, key, index, fallback)
    if type(value) ~= "table" then return fallback end
    local named = tonumber(value[key])
    if named ~= nil then return named end
    local indexed = tonumber(value[index])
    if indexed ~= nil then return indexed end
    return fallback
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

local function _vec(value, fallback)
    local base = fallback or { x = 0.0, y = 0.0, z = 0.0 }
    return {
        x = _component(value, "x", 1, base.x),
        y = _component(value, "y", 2, base.y),
        z = _component(value, "z", 3, base.z),
    }
end

local function _quat(value)
    return {
        x = _component(value, "x", 1, 0.0),
        y = _component(value, "y", 2, 0.0),
        z = _component(value, "z", 3, 0.0),
        w = _component(value, "w", 4, 1.0),
    }
end

local function _vecAdd(a, b)
    return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

local function _vecSub(a, b)
    return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

local function _vecMul(a, b)
    return { x = a.x * b.x, y = a.y * b.y, z = a.z * b.z }
end

local function _vecDiv(a, b)
    local function divide(value, divisor)
        if math.abs(divisor) < 0.000001 then return 0.0 end
        return value / divisor
    end
    return { x = divide(a.x, b.x), y = divide(a.y, b.y), z = divide(a.z, b.z) }
end

local function _vecScale(a, value)
    return { x = a.x * value, y = a.y * value, z = a.z * value }
end

local function _vecLength(a)
    return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end

local function _normalize(a, fallback)
    local length = _vecLength(a)
    if length < 0.000001 then return _clone(fallback) end
    return _vecScale(a, 1.0 / length)
end

local function _quatNormalize(value)
    local q = _quat(value)
    local length = math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
    if length < 0.000001 then return { x = 0.0, y = 0.0, z = 0.0, w = 1.0 } end
    return { x = q.x / length, y = q.y / length, z = q.z / length, w = q.w / length }
end

local function _quatConjugate(value)
    local q = _quat(value)
    return { x = -q.x, y = -q.y, z = -q.z, w = q.w }
end

local function _quatMul(left, right)
    local a = _quat(left)
    local b = _quat(right)
    return {
        x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
    }
end

local function _quatRotate(rotation, value)
    local q = _quatNormalize(rotation)
    local vectorQuaternion = { x = value.x, y = value.y, z = value.z, w = 0.0 }
    local rotated = _quatMul(_quatMul(q, vectorQuaternion), _quatConjugate(q))
    return { x = rotated.x, y = rotated.y, z = rotated.z }
end

local function _sign(value)
    if value < 0.0 then return -1.0 end
    return 1.0
end

local function _normalizeMirror(value)
    local mirror = _vec(value, { x = 1.0, y = 1.0, z = 1.0 })
    return { x = _sign(mirror.x), y = _sign(mirror.y), z = _sign(mirror.z) }
end

local function _normalizeScale(value)
    local scale = _vec(value, { x = 1.0, y = 1.0, z = 1.0 })
    return { x = math.abs(scale.x), y = math.abs(scale.y), z = math.abs(scale.z) }
end

local function _normalizeTransform(value)
    local source = type(value) == "table" and value or {}
    return {
        position = _vec(source.position or source.pos or source.translation),
        rotation = _quatNormalize(source.rotation or source.rot),
        scale = _normalizeScale(source.scale),
        mirror = _normalizeMirror(source.mirror),
    }
end

local function _effectiveScale(value)
    return _vecMul(value.scale, value.mirror)
end

local function _compose(parent, localTransform)
    local parentScale = _effectiveScale(parent)
    local scaledLocal = _vecMul(localTransform.position, parentScale)
    return {
        position = _vecAdd(parent.position, _quatRotate(parent.rotation, scaledLocal)),
        rotation = _quatNormalize(_quatMul(parent.rotation, localTransform.rotation)),
        scale = _vecMul(parent.scale, localTransform.scale),
        mirror = _normalizeMirror(_vecMul(parent.mirror, localTransform.mirror)),
    }
end

local function _inverseCompose(parent, world)
    local parentScale = _effectiveScale(parent)
    local position = _quatRotate(_quatConjugate(parent.rotation), _vecSub(world.position, parent.position))
    return {
        position = _vecDiv(position, parentScale),
        rotation = _quatNormalize(_quatMul(_quatConjugate(parent.rotation), world.rotation)),
        scale = _vecDiv(world.scale, parent.scale),
        mirror = _normalizeMirror(_vecDiv(world.mirror, parent.mirror)),
    }
end

local function _basis(rotation)
    local forward = _normalize(_quatRotate(rotation, { x = 0.0, y = 0.0, z = -1.0 }), { x = 0.0, y = 0.0, z = -1.0 })
    local up = _normalize(_quatRotate(rotation, { x = 0.0, y = 1.0, z = 0.0 }), { x = 0.0, y = 1.0, z = 0.0 })
    local right = _normalize(_quatRotate(rotation, { x = 1.0, y = 0.0, z = 0.0 }), { x = 1.0, y = 0.0, z = 0.0 })
    return { forward = forward, up = up, right = right }
end

local function _cacheKey(kind, id, space)
    return kind .. ":" .. tostring(transform.state.sourceRevision) .. ":" .. id .. ":" .. space
end

local function _clearCaches()
    _clear(transform.state.partCache)
    _clear(transform.state.anchorCache)
end

local function _validHandle(handle)
    local state = transform.state
    if type(handle) ~= "table" then
        state.metrics.invalidHandleRejects = state.metrics.invalidHandleRejects + 1
        return false, "transform handle is required"
    end
    if _safeString(handle.protocolVersion) ~= "" and _safeString(handle.protocolVersion) ~= transform.protocolVersion then
        state.metrics.invalidHandleRejects = state.metrics.invalidHandleRejects + 1
        return false, "transform protocol mismatch"
    end
    if _safeString(handle.identity) ~= state.identity then
        state.metrics.staleRejects = state.metrics.staleRejects + 1
        return false, "transform identity mismatch"
    end
    if _safeString(handle.ownerId) ~= state.ownerId then
        state.metrics.ownerRejects = state.metrics.ownerRejects + 1
        return false, "transform owner mismatch"
    end
    if math.floor(_safeNumber(handle.generation, 0)) ~= state.generation then
        state.metrics.staleRejects = state.metrics.staleRejects + 1
        return false, "transform generation is stale"
    end
    if handle.sourceRevision ~= nil and math.floor(_safeNumber(handle.sourceRevision, -1)) ~= state.sourceRevision then
        state.metrics.staleRejects = state.metrics.staleRejects + 1
        return false, "transform source revision is stale"
    end
    return true
end

local function _recordTransform(source)
    local record = type(source) == "table" and source or {}
    local localValue = record.localTransform or record["local"] or record.transform
    local normalized = _normalizeTransform(localValue)
    if record.scale ~= nil then normalized.scale = _normalizeScale(record.scale) end
    if record.mirror ~= nil then normalized.mirror = _normalizeMirror(record.mirror) end
    return {
        partId = _safeString(record.partId or record.id),
        nodeId = _safeString(record.nodeId),
        parentPartId = _safeString(record.parentPartId or record.parentId),
        localTransform = normalized,
        velocity = _vec(record.velocity),
        velocitySpace = _safeString(record.velocitySpace, "world"),
    }
end

local function _findPart(id)
    local state = transform.state
    local record = state.parts[id]
    if record ~= nil then return record end
    if cm2EntityGraphV1 ~= nil and cm2EntityGraphV1.resolvePart ~= nil then
        local resolved = cm2EntityGraphV1.resolvePart(id)
        if type(resolved) == "table" then
            local fallback = _recordTransform({
                partId = id,
                nodeId = resolved.nodeId,
                transform = resolved.transform,
            })
            state.parts[id] = fallback
            return fallback
        end
    end
    return nil
end

local function _worldForPart(partId, stack)
    stack = stack or {}
    if stack[partId] then return nil, "transform parent cycle" end
    stack[partId] = true
    local record = _findPart(partId)
    if record == nil then stack[partId] = nil; return nil, "part transform is missing" end
    local localTransform = _clone(record.localTransform)
    if record.parentPartId == "" then
        stack[partId] = nil
        return localTransform
    end
    local parentWorld, errorText = _worldForPart(record.parentPartId, stack)
    if parentWorld == nil then stack[partId] = nil; return nil, errorText end
    stack[partId] = nil
    return _compose(parentWorld, localTransform)
end

local function _parentWorldForPart(partId)
    local record = _findPart(partId)
    if record == nil or record.parentPartId == "" then return _normalizeTransform(nil) end
    return _worldForPart(record.parentPartId)
end

local function _partIdForNode(nodeId)
    local state = transform.state
    for partId, record in pairs(state.parts) do
        if record.nodeId == nodeId then return partId end
    end
    if cm2EntityGraphV1 ~= nil and cm2EntityGraphV1.snapshot ~= nil then
        local snapshot = cm2EntityGraphV1.snapshot()
        for partId, mappedNode in pairs(snapshot.parts or {}) do
            if mappedNode == nodeId then return partId end
        end
    end
    return ""
end

local function _makeResult(id, space, localValue, parentValue, worldValue, record)
    local state = transform.state
    local value = worldValue
    if space == "local" then value = localValue elseif space == "parent" then value = parentValue end
    return {
        protocolVersion = transform.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        sourceRevision = state.sourceRevision,
        units = state.units,
        frame = state.frame,
        partId = id,
        nodeId = record.nodeId,
        parentPartId = record.parentPartId,
        space = space,
        transform = _clone(value),
        localTransform = _clone(localValue),
        parentTransform = _clone(parentValue),
        worldTransform = _clone(worldValue),
        velocity = _clone(record.velocity),
        velocitySpace = record.velocitySpace,
        scale = _clone(value.scale),
        mirror = _clone(value.mirror),
    }
end

function transform.serverInit(generation, identity, ownerId, options)
    local state = transform.state
    local resolved = type(options) == "table" and options or {}
    state.initialized = true
    state.identity = _safeString(identity, "transform-entity")
    state.ownerId = _safeString(ownerId, state.identity)
    state.generation = math.max(1, math.floor(_safeNumber(generation, 1)))
    state.sourceRevision = math.max(0, math.floor(_safeNumber(resolved.sourceRevision, 0)))
    state.units = _safeString(resolved.units, transform.units)
    state.frame = _safeString(resolved.frame, transform.frame)
    state.parts = {}
    state.anchors = {}
    _clearCaches()
    state.invalidationReason = "init"
    state.metrics = {
        initCount = (state.metrics.initCount or 0) + 1,
        binds = 0, bindRejects = 0, partLookups = 0, partHits = 0,
        partMisses = 0, anchorLookups = 0, anchorHits = 0, anchorMisses = 0,
        staleRejects = 0, ownerRejects = 0, invalidHandleRejects = 0,
        invalidTransformRejects = 0, invalidations = 0, basisLookups = 0,
        velocityLookups = 0, scaleLookups = 0, mirrorLookups = 0,
    }
    return transform.handle()
end

function transform.handle()
    local state = transform.state
    return {
        protocolVersion = transform.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        sourceRevision = state.sourceRevision,
    }
end

function transform.bind(handle, source)
    local state = transform.state
    local valid, errorText = _validHandle(handle)
    if not valid then state.metrics.bindRejects = state.metrics.bindRejects + 1; return false, errorText end
    local value = type(source) == "table" and source or {}
    local requestedGeneration = math.floor(_safeNumber(value.generation, state.generation))
    local requestedOwner = _safeString(value.ownerId, state.ownerId)
    if requestedGeneration ~= state.generation then state.metrics.bindRejects = state.metrics.bindRejects + 1; state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "transform source generation is stale" end
    if requestedOwner ~= state.ownerId then state.metrics.bindRejects = state.metrics.bindRejects + 1; state.metrics.ownerRejects = state.metrics.ownerRejects + 1; return false, "transform source owner mismatch" end
    local parts = {}
    for key, rawRecord in pairs(value.parts or {}) do
        local record = _recordTransform(rawRecord)
        if record.partId == "" then record.partId = _safeString(key) end
        if record.partId == "" or parts[record.partId] ~= nil then state.metrics.bindRejects = state.metrics.bindRejects + 1; return false, "duplicate or missing transform part" end
        parts[record.partId] = record
    end
    local visiting = {}
    local function validatePart(id)
        if visiting[id] == 1 then return false, "transform parent cycle" end
        if visiting[id] == 2 then return true end
        visiting[id] = 1
        local record = parts[id]
        if record == nil then return false, "transform parent is missing" end
        if record.parentPartId ~= "" then
            if parts[record.parentPartId] == nil then return false, "transform parent is missing: " .. record.parentPartId end
            local validParent, parentError = validatePart(record.parentPartId)
            if not validParent then return false, parentError end
        end
        visiting[id] = 2
        return true
    end
    for id in pairs(parts) do
        local validPart, partError = validatePart(id)
        if not validPart then state.metrics.bindRejects = state.metrics.bindRejects + 1; return false, partError end
    end
    local anchors = {}
    for key, rawAnchor in pairs(value.anchors or {}) do
        local anchor = type(rawAnchor) == "table" and rawAnchor or {}
        local anchorId = _safeString(anchor.anchorId or anchor.id or key)
        local partId = _safeString(anchor.partId)
        if partId == "" then partId = _partIdForNode(_safeString(anchor.nodeId)) end
        if anchorId == "" or anchors[anchorId] ~= nil or partId == "" then state.metrics.bindRejects = state.metrics.bindRejects + 1; return false, "duplicate or missing transform anchor" end
        anchors[anchorId] = { anchorId = anchorId, partId = partId, localTransform = _normalizeTransform(anchor.localTransform or anchor.transform) }
    end
    local requestedRevision = math.floor(_safeNumber(value.revision or value.sourceRevision, state.sourceRevision + 1))
    if requestedRevision < state.sourceRevision then state.metrics.bindRejects = state.metrics.bindRejects + 1; state.metrics.staleRejects = state.metrics.staleRejects + 1; return false, "transform source revision is stale" end
    state.parts = parts
    state.anchors = anchors
    state.sourceRevision = requestedRevision
    state.invalidationReason = "bind"
    _clearCaches()
    state.metrics.binds = state.metrics.binds + 1
    return true, transform.snapshot()
end

function transform.invalidate(handle, reason)
    local state = transform.state
    local valid, errorText = _validHandle(handle)
    if not valid then return false, errorText end
    state.sourceRevision = state.sourceRevision + 1
    state.invalidationReason = _safeString(reason, "source-changed")
    _clearCaches()
    state.metrics.invalidations = state.metrics.invalidations + 1
    return true, transform.handle()
end

function transform.resolvePart(handle, partId, space)
    local state = transform.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    local id = _safeString(partId)
    local requestedSpace = _safeString(space, "world")
    if requestedSpace ~= "local" and requestedSpace ~= "parent" and requestedSpace ~= "world" then state.metrics.invalidTransformRejects = state.metrics.invalidTransformRejects + 1; return nil, "unsupported transform space" end
    state.metrics.partLookups = state.metrics.partLookups + 1
    local key = _cacheKey("part", id, requestedSpace)
    if state.partCache[key] ~= nil then state.metrics.partHits = state.metrics.partHits + 1; return _clone(state.partCache[key]) end
    local record = _findPart(id)
    if record == nil then state.metrics.partMisses = state.metrics.partMisses + 1; return nil, "part transform is missing" end
    local worldValue, worldError = _worldForPart(id)
    if worldValue == nil then state.metrics.partMisses = state.metrics.partMisses + 1; return nil, worldError end
    local parentValue = _parentWorldForPart(id)
    local result = _makeResult(id, requestedSpace, record.localTransform, parentValue, worldValue, record)
    state.partCache[key] = result
    state.metrics.partHits = state.metrics.partHits + 1
    return _clone(result)
end

function transform.resolveAnchor(handle, anchorId, space)
    local state = transform.state
    local valid, errorText = _validHandle(handle)
    if not valid then return nil, errorText end
    local id = _safeString(anchorId)
    local requestedSpace = _safeString(space, "world")
    if requestedSpace ~= "local" and requestedSpace ~= "parent" and requestedSpace ~= "world" then state.metrics.invalidTransformRejects = state.metrics.invalidTransformRejects + 1; return nil, "unsupported anchor space" end
    state.metrics.anchorLookups = state.metrics.anchorLookups + 1
    local key = _cacheKey("anchor", id, requestedSpace)
    if state.anchorCache[key] ~= nil then state.metrics.anchorHits = state.metrics.anchorHits + 1; return _clone(state.anchorCache[key]) end
    local anchor = state.anchors[id]
    if anchor == nil and cm2EntityGraphV1 ~= nil and cm2EntityGraphV1.resolveAnchor ~= nil then
        local graphAnchor = cm2EntityGraphV1.resolveAnchor(id)
        if type(graphAnchor) == "table" then
            local partId = _partIdForNode(_safeString(graphAnchor.nodeId))
            if partId ~= "" then anchor = { anchorId = id, partId = partId, localTransform = _normalizeTransform(graphAnchor.localTransform) } end
        end
    end
    if anchor == nil then state.metrics.anchorMisses = state.metrics.anchorMisses + 1; return nil, "anchor transform is missing" end
    local partResult, partError = transform.resolvePart(handle, anchor.partId, "world")
    if partResult == nil then state.metrics.anchorMisses = state.metrics.anchorMisses + 1; return nil, partError end
    local worldValue = _compose(partResult.worldTransform, anchor.localTransform)
    local localValue = _clone(anchor.localTransform)
    local parentValue = partResult.worldTransform
    local value = worldValue
    if requestedSpace == "local" then value = localValue elseif requestedSpace == "parent" then value = parentValue end
    local result = {
        protocolVersion = transform.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        sourceRevision = state.sourceRevision,
        units = state.units,
        frame = state.frame,
        anchorId = id,
        partId = anchor.partId,
        space = requestedSpace,
        transform = _clone(value),
        localTransform = localValue,
        parentTransform = _clone(parentValue),
        worldTransform = _clone(worldValue),
        scale = _clone(value.scale),
        mirror = _clone(value.mirror),
    }
    state.anchorCache[key] = result
    state.metrics.anchorHits = state.metrics.anchorHits + 1
    return _clone(result)
end

function transform.getBasis(handle, partId, space)
    local state = transform.state
    state.metrics.basisLookups = state.metrics.basisLookups + 1
    local result, errorText = transform.resolvePart(handle, partId, space or "world")
    if result == nil then return nil, errorText end
    result.basis = _basis(result.transform.rotation)
    return result
end

function transform.getVelocity(handle, partId, space)
    local state = transform.state
    state.metrics.velocityLookups = state.metrics.velocityLookups + 1
    local requestedSpace = _safeString(space, "world")
    local result, errorText = transform.resolvePart(handle, partId, requestedSpace)
    if result == nil then return nil, errorText end
    local velocity = _vec(result.velocity)
    if result.velocitySpace == "local" and requestedSpace == "world" then velocity = _quatRotate(result.worldTransform.rotation, velocity) end
    if result.velocitySpace == "world" and requestedSpace == "local" then velocity = _quatRotate(_quatConjugate(result.worldTransform.rotation), velocity) end
    result.velocity = velocity
    result.velocitySpace = requestedSpace
    return result
end

function transform.getScale(handle, partId, space)
    local state = transform.state
    state.metrics.scaleLookups = state.metrics.scaleLookups + 1
    local result, errorText = transform.resolvePart(handle, partId, space or "world")
    if result == nil then return nil, errorText end
    return { protocolVersion = result.protocolVersion, identity = result.identity, ownerId = result.ownerId, generation = result.generation, sourceRevision = result.sourceRevision, partId = result.partId, space = result.space, scale = _clone(result.scale) }
end

function transform.getMirror(handle, partId, space)
    local state = transform.state
    state.metrics.mirrorLookups = state.metrics.mirrorLookups + 1
    local result, errorText = transform.resolvePart(handle, partId, space or "world")
    if result == nil then return nil, errorText end
    return { protocolVersion = result.protocolVersion, identity = result.identity, ownerId = result.ownerId, generation = result.generation, sourceRevision = result.sourceRevision, partId = result.partId, space = result.space, mirror = _clone(result.mirror) }
end

function transform.snapshot()
    local state = transform.state
    return {
        protocolVersion = transform.protocolVersion,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        sourceRevision = state.sourceRevision,
        units = state.units,
        frame = state.frame,
        invalidationReason = state.invalidationReason,
        parts = _clone(state.parts),
        anchors = _clone(state.anchors),
    }
end

function transform.getDiagnostics()
    local state = transform.state
    local function count(value)
        local total = 0
        for _ in pairs(value) do total = total + 1 end
        return total
    end
    return {
        protocolVersion = transform.protocolVersion,
        initialized = state.initialized,
        identity = state.identity,
        ownerId = state.ownerId,
        generation = state.generation,
        sourceRevision = state.sourceRevision,
        units = state.units,
        frame = state.frame,
        invalidationReason = state.invalidationReason,
        partCount = count(state.parts),
        anchorCount = count(state.anchors),
        cachedPartCount = count(state.partCache),
        cachedAnchorCount = count(state.anchorCache),
        initCount = state.metrics.initCount,
        binds = state.metrics.binds,
        bindRejects = state.metrics.bindRejects,
        partLookups = state.metrics.partLookups,
        partHits = state.metrics.partHits,
        partMisses = state.metrics.partMisses,
        anchorLookups = state.metrics.anchorLookups,
        anchorHits = state.metrics.anchorHits,
        anchorMisses = state.metrics.anchorMisses,
        staleRejects = state.metrics.staleRejects,
        ownerRejects = state.metrics.ownerRejects,
        invalidHandleRejects = state.metrics.invalidHandleRejects,
        invalidTransformRejects = state.metrics.invalidTransformRejects,
        invalidations = state.metrics.invalidations,
        basisLookups = state.metrics.basisLookups,
        velocityLookups = state.metrics.velocityLookups,
        scaleLookups = state.metrics.scaleLookups,
        mirrorLookups = state.metrics.mirrorLookups,
    }
end
