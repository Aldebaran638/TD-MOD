---@diagnostic disable: undefined-global

-- Catalog Authority v1.  The generated catalog is immutable once a context
-- starts; legacy registration is only a migration/import concern.  The
-- current build selects legacy because the Gate 3 manifest is shadow-only.
cm2CatalogAuthorityV1 = cm2CatalogAuthorityV1 or {}
local authority = cm2CatalogAuthorityV1

authority.state = authority.state or {
    initialized = false,
    frozen = false,
    source = "legacy",
    candidateAvailable = false,
    generatedCatalogHash = "",
    rollbackCatalogHash = "",
    legacyDefinitionRegisterCalls = 0,
    legacyOverrideAttempts = 0,
    rejectedAfterFreeze = 0,
    fallbackReason = "not-initialized",
}

local function _validManifest(manifest)
    return type(manifest) == "table"
        and tostring(manifest.schemaVersion or "") == "cm2.generated-catalog-manifest/1"
        and manifest.generated == true
        and type(manifest.catalogs) == "table"
        and type(manifest.ownership) == "table"
        and tostring(manifest.ownership.mode or "") == "shadow"
        and tostring(manifest.ownership.runtimePolicy or "") == "legacy-active"
end

function authority.init(requestedSource, manifest, generatedCatalog, rollbackHash)
    local state = authority.state
    if state.initialized then return state end
    local requested = tostring(requestedSource or "legacy")
    state.rollbackCatalogHash = tostring(rollbackHash or "")
    state.candidateAvailable = _validManifest(manifest)
        and type(generatedCatalog) == "table"
    if requested == "candidate-v1"
        and state.candidateAvailable
        and manifest.ownership.promotionAllowed == true then
        state.source = "candidate-v1"
        state.generatedCatalogHash = tostring(
            manifest.buildOutput and manifest.buildOutput.outputHash or ""
        )
        state.fallbackReason = "candidate-promoted-at-init"
    else
        state.source = "legacy"
        state.generatedCatalogHash = ""
        if requested == "candidate-v1" and not state.candidateAvailable then
            state.fallbackReason = "candidate-manifest-invalid"
        elseif requested == "candidate-v1" then
            state.fallbackReason = "promotion-not-approved"
        else
            state.fallbackReason = "legacy-default"
        end
    end
    state.frozen = true
    state.initialized = true
    return state
end

function authority.isFrozen()
    return authority.state.frozen == true
end

function authority.source()
    return tostring(authority.state.source or "legacy")
end

function authority.registerLegacyDefinition(definitionId)
    local state = authority.state
    if state.frozen then
        state.rejectedAfterFreeze = state.rejectedAfterFreeze + 1
        return false, "legacy definition registration is frozen"
    end
    state.legacyDefinitionRegisterCalls = state.legacyDefinitionRegisterCalls + 1
    return tostring(definitionId or "") ~= "", nil
end

function authority.overrideDefinition(definitionId)
    local state = authority.state
    state.legacyOverrideAttempts = state.legacyOverrideAttempts + 1
    if state.frozen then
        state.rejectedAfterFreeze = state.rejectedAfterFreeze + 1
        return false, "definition override is frozen"
    end
    return tostring(definitionId or "") ~= "", nil
end

function authority.lookup(catalog, definitionId)
    local state = authority.state
    if not state.initialized then return nil, "catalog authority is not initialized" end
    local id = tostring(definitionId or "")
    if type(catalog) ~= "table" then return nil, "catalog is unavailable" end
    if catalog[id] == nil then return nil, "definition is not in the frozen catalog" end
    return catalog[id], nil
end

function authority.rollbackAtInit()
    if authority.state.initialized then
        return false, "rollback requires a new context initialization"
    end
    authority.state.source = "legacy"
    authority.state.fallbackReason = "explicit-rollback"
    return true, nil
end

function authority.getReport()
    local state = authority.state
    return {
        initialized = state.initialized,
        frozen = state.frozen,
        source = state.source,
        candidateAvailable = state.candidateAvailable,
        generatedCatalogHash = state.generatedCatalogHash,
        rollbackCatalogHash = state.rollbackCatalogHash,
        legacyDefinitionRegisterCalls = state.legacyDefinitionRegisterCalls,
        legacyOverrideAttempts = state.legacyOverrideAttempts,
        rejectedAfterFreeze = state.rejectedAfterFreeze,
        fallbackReason = state.fallbackReason,
    }
end

return authority
