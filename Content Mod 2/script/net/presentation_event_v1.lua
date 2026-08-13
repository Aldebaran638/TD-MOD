-- Versioned, transport-neutral WeaponPresentationEvent DTO.
-- This module is intentionally side-band: legacy ClientCall paths remain active.

cm2PresentationEventV1 = cm2PresentationEventV1 or {}
local event = cm2PresentationEventV1

event.protocolVersion = "cm2.presentation-event/1"
event.kinds = {
    charge = true,
    muzzle = true,
    beam = true,
    projectile = true,
    impact = true,
    sound = true,
    shake = true,
    craft_launch = true,
    craft_recover = true,
}

local function _isInteger(value)
    return type(value) == "number" and value == math.floor(value)
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

local function _checkString(value, name)
    if type(value) ~= "string" or value == "" then return false, name .. " must be a non-empty string" end
    return true
end

local function _checkDefinitionRef(value, name)
    if type(value) ~= "table" then return false, name .. " must be DefinitionRef" end
    local ok, errorText = _checkString(value.id, name .. ".id")
    if not ok then return false, errorText end
    ok, errorText = _checkString(value.schemaVersion, name .. ".schemaVersion")
    if not ok then return false, errorText end
    return true
end

local function _checkEntityRef(value, name)
    if type(value) ~= "table" then return false, name .. " must be EntityRef" end
    local ok, errorText = _checkString(value.id, name .. ".id")
    if not ok then return false, errorText end
    if not _isInteger(value.generation) or value.generation < 0 then return false, name .. ".generation must be a non-negative integer" end
    return true
end

local function _checkAnchorRef(value, name)
    if type(value) ~= "table" then return false, name .. " must be AnchorRef" end
    local ok, errorText = _checkString(value.entityId, name .. ".entityId")
    if not ok then return false, errorText end
    ok, errorText = _checkString(value.anchorId, name .. ".anchorId")
    if not ok then return false, errorText end
    return true
end

local function _checkEffectInstanceRef(value, name)
    if type(value) ~= "table" then return false, name .. " must be EffectInstanceRef" end
    local ok, errorText = _checkString(value.id, name .. ".id")
    if not ok then return false, errorText end
    if not _isInteger(value.generation) or value.generation < 0 then return false, name .. ".generation must be a non-negative integer" end
    return true
end

local function _checkTransform(value, name)
    if type(value) ~= "table" then return false, name .. " must be a transform object" end
    if value.position ~= nil and type(value.position) ~= "table" then return false, name .. ".position must be a vector" end
    if value.rotation ~= nil and type(value.rotation) ~= "table" then return false, name .. ".rotation must be a quaternion" end
    return true
end

local function _checkHit(value, name)
    if type(value) ~= "table" then return false, name .. " must be a hit object" end
    if value.position ~= nil and type(value.position) ~= "table" then return false, name .. ".position must be a vector" end
    if value.normal ~= nil and type(value.normal) ~= "table" then return false, name .. ".normal must be a vector" end
    return true
end

function event.newDefinitionRef(id, schemaVersion)
    return { id = id, schemaVersion = schemaVersion }
end

function event.newEntityRef(id, generation)
    return { id = id, generation = generation }
end

function event.newAnchorRef(entityId, anchorId)
    return { entityId = entityId, anchorId = anchorId }
end

function event.newEffectInstanceRef(id, generation)
    return { id = id, generation = generation }
end

function event.validate(value, previousSequence)
    if type(value) ~= "table" then return false, "event must be a table" end
    if value.protocolVersion ~= event.protocolVersion then return false, "protocolVersion is unknown or unsupported" end
    if not _isInteger(value.sequence) or value.sequence < 1 then return false, "sequence must be a positive integer" end
    if previousSequence ~= nil and (not _isInteger(previousSequence) or value.sequence <= previousSequence) then return false, "sequence is duplicate or stale" end
    if not event.kinds[value.kind] then return false, "kind is not supported by protocol v1" end
    local ok, errorText = _checkEntityRef(value.source, "source")
    if not ok then return false, errorText end
    if value.weapon ~= nil then ok, errorText = _checkDefinitionRef(value.weapon, "weapon"); if not ok then return false, errorText end end
    if value.effect ~= nil then ok, errorText = _checkDefinitionRef(value.effect, "effect"); if not ok then return false, errorText end end
    if value.anchor ~= nil then ok, errorText = _checkAnchorRef(value.anchor, "anchor"); if not ok then return false, errorText end end
    if value.effectInstance ~= nil then ok, errorText = _checkEffectInstanceRef(value.effectInstance, "effectInstance"); if not ok then return false, errorText end end
    if value.transform ~= nil then ok, errorText = _checkTransform(value.transform, "transform"); if not ok then return false, errorText end end
    if value.target ~= nil then ok, errorText = _checkEntityRef(value.target, "target"); if not ok then return false, errorText end end
    if value.hit ~= nil then ok, errorText = _checkHit(value.hit, "hit"); if not ok then return false, errorText end end
    if not _isInteger(value.seed) or value.seed < 0 then return false, "seed must be a non-negative integer" end
    if type(value.priority) ~= "number" then return false, "priority must be a number" end
    if type(value.serverTime) ~= "number" then return false, "serverTime must be a number" end
    if value.payload ~= nil and type(value.payload) ~= "table" then return false, "payload must be a table" end
    if value.extensions ~= nil and type(value.extensions) ~= "table" then return false, "extensions must be a table" end
    for key, child in pairs(value) do
        if key == "callback" or key == "functionName" or key == "engineHandle" or key == "sharedTable" then return false, "event contains forbidden runtime reference: " .. tostring(key) end
        if type(child) == "function" or type(child) == "userdata" or type(child) == "thread" then return false, "event contains an unserializable value" end
    end
    return true
end

-- encode/decode are transport-neutral table projections. A future transport can
-- serialize this validated wire table without exposing callbacks or engine IDs.
function event.encode(value)
    local ok, errorText = event.validate(value)
    if not ok then return nil, errorText end
    return _clone(value)
end

function event.decode(value, previousSequence)
    local ok, errorText = event.validate(value, previousSequence)
    if not ok then return nil, errorText end
    return _clone(value)
end

function event.semanticEqual(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not event.semanticEqual(value, right[key]) then return false end end
    for key, value in pairs(right) do if not event.semanticEqual(value, left[key]) then return false end end
    return true
end

