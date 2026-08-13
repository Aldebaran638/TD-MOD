-- Init-only shadow ownership gate for candidate Definition catalogs.
-- It never compares or mutates state from a hot tick.

cm2CandidateCatalogShadow = cm2CandidateCatalogShadow or {}
local shadow = cm2CandidateCatalogShadow

shadow.definitionSource = shadow.definitionSource or "legacy"
shadow.initialized = shadow.initialized or false
shadow.frozen = shadow.frozen or false
shadow.legacySnapshot = shadow.legacySnapshot or nil
shadow.candidateCatalog = shadow.candidateCatalog or nil
shadow.diagnostics = shadow.diagnostics or {}

local function _copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = _copy(child) end
    return result
end

function shadow.init(definitionSource, legacySnapshot, candidateCatalog)
    if shadow.initialized then return false, "candidate shadow is init-only" end
    local source = tostring(definitionSource or "legacy")
    if source ~= "legacy" and source ~= "candidate-v1" then return false, "definitionSource must be legacy or candidate-v1" end
    if type(legacySnapshot) ~= "table" then return false, "legacy snapshot is required" end
    if type(candidateCatalog) ~= "table" then return false, "candidate catalog is required" end
    shadow.definitionSource = source
    shadow.legacySnapshot = _copy(legacySnapshot)
    shadow.candidateCatalog = _copy(candidateCatalog)
    shadow.initialized = true
    shadow.frozen = true
    return true
end

function shadow.getSource()
    return shadow.definitionSource
end

function shadow.isFrozen()
    return shadow.frozen
end

function shadow.recordDifference(sliceName, fieldPath, legacyValue, candidateValue)
    if shadow.frozen == false then return false, "shadow must be initialized before recording differences" end
    shadow.diagnostics[#shadow.diagnostics + 1] = {
        slice = tostring(sliceName or ""),
        fieldPath = tostring(fieldPath or ""),
        legacy = legacyValue,
        candidate = candidateValue,
    }
    return false
end

function shadow.getDiagnostics()
    return _copy(shadow.diagnostics)
end

