---@diagnostic disable: undefined-global

-- Catalog Authority v1. Generated projections are selected, parity-checked
-- and frozen once per Runtime context. Legacy definition files are accepted
-- only through the init-time import boundary below; Runtime never uses their
-- registries as an authority.
cm2CatalogAuthorityV1 = cm2CatalogAuthorityV1 or {}
local authority = cm2CatalogAuthorityV1

authority.protocolVersion = "cm2.catalog-authority/1"

local function _copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] ~= nil then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[key] = _copy(child, seen) end
    return result
end

local function _count(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

local function _sameNumber(left, right)
    local a = tonumber(left)
    local b = tonumber(right)
    return a ~= nil and b ~= nil and math.abs(a - b) < 0.0001
end

local function _legacyId(canonicalId, prefix)
    local value = tostring(canonicalId or "")
    local expected = tostring(prefix or "")
    if value:sub(1, #expected) ~= expected then return "" end
    return value:sub(#expected + 1)
end

local function _newState()
    return {
        initialized = false,
        frozen = false,
        requestedSource = "candidate-v1",
        source = "uninitialized",
        runtimePolicy = "candidate-required",
        candidateAvailable = false,
        candidateCatalogHash = "",
        rollbackCatalogHash = "",
        fallbackReason = "not-initialized",
        candidateCalls = 0,
        legacyAdapterCalls = 0,
        legacyDefinitionImportCalls = 0,
        legacyDefinitionRegisterCalls = 0,
        legacyDefinitionOverrideCalls = 0,
        rejectedAfterFreeze = 0,
        parityChecks = 0,
        parityPasses = 0,
        parityMismatches = 0,
        effectiveVehicles = {},
        effectiveWeapons = {},
        bootstrapVehicles = {},
        bootstrapWeapons = {},
        bootstrapComponents = {},
        rollbackVehicles = {},
        rollbackWeapons = {},
        rollbackComponents = {},
        candidateVehicles = {},
        candidateWeapons = {},
        effectiveComponents = {},
        rollbackRequested = false,
    }
end

authority.state = authority.state or _newState()

local function _captureDefinition(kind, definitionId, definition)
    local state = authority.state
    if state.initialized or state.frozen then
        return false, "legacy definition import is closed"
    end
    local normalizedKind = tostring(kind or "")
    local id = tostring(definitionId or "")
    local bucket = normalizedKind == "vehicle" and state.bootstrapVehicles
        or normalizedKind == "weapon" and state.bootstrapWeapons
        or normalizedKind == "component" and state.bootstrapComponents
    if bucket == nil or id == "" or type(definition) ~= "table" then
        return false, "invalid legacy definition import"
    end
    if bucket[id] ~= nil then
        return false, "duplicate imported definition " .. id
    end
    bucket[id] = definition
    state.legacyDefinitionImportCalls = state.legacyDefinitionImportCalls + 1
    return true, nil
end

-- Legacy schema functions use this only while the entry closure is being
-- assembled. The table is private to the authority and is copied before the
-- freeze; no Runtime lookup reads these bootstrap buckets.
function authority.captureLegacyDefinition(kind, definitionId, definition)
    return _captureDefinition(kind, definitionId, definition)
end

local function _defaultManifest()
    return {
        schemaVersion = "cm2.generated-catalog-manifest/1",
        generated = true,
        ownership = {
            runtimePolicy = "candidate-active",
            mode = "promoted",
            promotionAllowed = true,
        },
    }
end

local function _validManifest(manifest)
    return type(manifest) == "table"
        and tostring(manifest.schemaVersion or "")
            == "cm2.generated-catalog-manifest/1"
        and manifest.generated == true
        and type(manifest.ownership) == "table"
        and tostring(manifest.ownership.runtimePolicy or "")
            == "candidate-active"
        and tostring(manifest.ownership.mode or "") == "promoted"
        and manifest.ownership.promotionAllowed == true
end

local function _validCatalog(catalog, metadata, schemaVersion, hash)
    return type(catalog) == "table"
        and type(metadata) == "table"
        and metadata.runtimeProjection == true
        and tostring(metadata.schemaVersion or "") == schemaVersion
        and tostring(metadata.catalogSha256 or "") == tostring(hash or "")
        and _count(catalog) > 0
end

local function _candidateVehicleParity(legacy, candidate)
    local health = candidate.health or {}
    return tostring(legacy.controlMode or "") == tostring(candidate.controlMode or "")
        and _sameNumber(legacy.maxShieldHP, candidate.shieldHP)
        and _sameNumber(legacy.maxArmorHP, candidate.armorHP)
        and _sameNumber(legacy.maxBodyHP, candidate.bodyHP)
end

local function _legacyBehaviorMatchesCandidate(legacy, candidate)
    local legacyBehavior = tostring(legacy.behaviorType or "")
    local candidateBehavior = tostring(candidate or "")
    if tostring(legacy.controllerType or "") == "chargedRay" then
        return candidateBehavior == "chargedRay"
            or candidateBehavior == "charged-ray"
            or candidateBehavior == legacyBehavior
    end
    if legacyBehavior == "guidedProjectile" then
        return candidateBehavior == "guided"
            or candidateBehavior == "guidedSalvo"
    end
    if legacyBehavior == "strikeCraft" then
        return candidateBehavior == "strikeCraft"
            or candidateBehavior == "strike-craft"
    end
    if legacyBehavior == "raycast" then
        return candidateBehavior == "raycast" or candidateBehavior == "ray"
    end
    return legacyBehavior == candidateBehavior
end

local function _candidateWeaponParity(legacy, candidate)
    local slot = tostring(candidate.slot or "")
    local slotMatch = false
    for _, legacySlot in ipairs(legacy.slotTypes or {}) do
        if tostring(legacySlot or "") == slot then slotMatch = true break end
    end
    local legacyCooldown = legacy.cooldown
    if legacyCooldown == nil then legacyCooldown = legacy.CD end
    return slotMatch
        and _sameNumber(legacyCooldown, candidate.cooldown)
        and _sameNumber(legacy.maxRange, candidate.maxRange)
        and _legacyBehaviorMatchesCandidate(legacy, candidate.behavior)
end

local function _buildVehicleProjection(legacyDefinitions, candidates, state)
    local result = {}
    for canonicalId, candidate in pairs(candidates or {}) do
        local id = _legacyId(canonicalId, "cm2:vehicle/")
        local legacy = legacyDefinitions[id]
        if legacy == nil then
            return nil, "candidate vehicle has no legacy adapter: " .. tostring(canonicalId)
        end
        state.parityChecks = state.parityChecks + 1
        if not _candidateVehicleParity(legacy, candidate) then
            state.parityMismatches = state.parityMismatches + 1
            return nil, "vehicle parity mismatch: " .. tostring(canonicalId)
        end
        state.parityPasses = state.parityPasses + 1
        local merged = _copy(legacy)
        merged.controlMode = candidate.controlMode
        merged.maxShieldHP = candidate.shieldHP
        merged.maxArmorHP = candidate.armorHP
        merged.maxBodyHP = candidate.bodyHP
        merged.catalogId = canonicalId
        merged.catalogSource = "generated-v1"
        merged.catalogMountSetId = candidate.mountSetId
        merged.catalogTargetFilterId = candidate.targetFilterId
        result[id] = merged
    end
    if _count(result) ~= _count(legacyDefinitions) then
        return nil, "candidate vehicle catalog does not cover the legacy registry"
    end
    return result, nil
end

local function _buildWeaponProjection(legacyDefinitions, candidates, state)
    local result = {}
    for canonicalId, candidate in pairs(candidates or {}) do
        local id = _legacyId(canonicalId, "cm2:weapon/")
        local legacy = legacyDefinitions[id]
        if legacy == nil then
            return nil, "candidate weapon has no legacy adapter: " .. tostring(canonicalId)
        end
        state.parityChecks = state.parityChecks + 1
        if not _candidateWeaponParity(legacy, candidate) then
            state.parityMismatches = state.parityMismatches + 1
            return nil, "weapon parity mismatch: " .. tostring(canonicalId)
        end
        state.parityPasses = state.parityPasses + 1
        local merged = _copy(legacy)
        merged.slotTypes = { tostring(candidate.slot or "") }
        merged.cooldown = candidate.cooldown
        merged.CD = candidate.cooldown
        merged.maxRange = candidate.maxRange
        merged.catalogId = canonicalId
        merged.catalogSource = "generated-v1"
        merged.catalogBehavior = candidate.behavior
        merged.catalogProjectileId = candidate.projectile
        result[id] = merged
    end
    -- A disposable, human-approved AI candidate may be imported before the
    -- freeze for its own scenario. It is still published through this one
    -- frozen projection; it never calls a Runtime definition register.
    for id, definition in pairs(legacyDefinitions or {}) do
        if definition.aiCandidate == true then
            local copied = _copy(definition)
            copied.catalogId = id
            copied.catalogSource = "scenario-v1"
            result[id] = copied
        end
    end
    if _count(result) ~= _count(legacyDefinitions) then
        return nil, "candidate weapon catalog does not cover the legacy registry"
    end
    return result, nil
end

local function _buildComponentProjection(rollbackDefinitions)
    return _copy(rollbackDefinitions or {})
end

local function _activateProjection(state, vehicles, weapons, components)
    state.effectiveVehicles = vehicles
    state.effectiveWeapons = weapons
    state.effectiveComponents = components or {}
    -- Existing Runtime modules resolve these globals dynamically. They now
    -- point at the frozen projection, never at the bootstrap import buckets.
    shipTypeRegistryData = vehicles
    weaponData = weapons
    shipComponentData = state.effectiveComponents
    if weaponCatalogUseRuntimeDefinitions ~= nil then
        weaponCatalogUseRuntimeDefinitions(weapons)
    end
    if shipComponentUseRuntimeDefinitions ~= nil then
        shipComponentUseRuntimeDefinitions(state.effectiveComponents)
    end
end

local function _clearRuntimeProjection(state)
    state.effectiveVehicles = {}
    state.effectiveWeapons = {}
    state.effectiveComponents = {}
    shipTypeRegistryData = {}
    weaponData = {}
    shipComponentData = {}
    if weaponCatalogUseRuntimeDefinitions ~= nil then
        weaponCatalogUseRuntimeDefinitions({})
    end
    if shipComponentUseRuntimeDefinitions ~= nil then
        shipComponentUseRuntimeDefinitions({})
    end
end

function authority.init(requestedSource, manifest, generatedCatalog, rollbackHash)
    local state = authority.state
    if state.initialized then return state end

    state.requestedSource = tostring(requestedSource or "candidate-v1")
    state.rollbackCatalogHash = tostring(rollbackHash or "")
    state.rollbackVehicles = _copy(state.bootstrapVehicles)
    state.rollbackWeapons = _copy(state.bootstrapWeapons)
    state.rollbackComponents = _copy(state.bootstrapComponents)

    local runtimeManifest = manifest or _defaultManifest()
    local candidate = generatedCatalog or {
        vehicles = cm2GeneratedVehicleCatalogV1,
        vehicleMeta = cm2GeneratedVehicleCatalogV1Meta,
        weapons = cm2GeneratedWeaponCatalogV1,
        weaponMeta = cm2GeneratedWeaponCatalogV1Meta,
    }
    state.candidateVehicles = candidate.vehicles or {}
    state.candidateWeapons = candidate.weapons or {}
    local vehicleHash = (candidate.vehicleMeta or {}).catalogSha256 or ""
    local weaponHash = (candidate.weaponMeta or {}).catalogSha256 or ""
    state.candidateAvailable = _validManifest(runtimeManifest)
        and _validCatalog(
            state.candidateVehicles,
            candidate.vehicleMeta,
            "cm2.vehicle-catalog/1",
            vehicleHash
        )
        and _validCatalog(
            state.candidateWeapons,
            candidate.weaponMeta,
            "cm2.weapon-catalog/1",
            weaponHash
        )
    state.candidateCatalogHash = vehicleHash .. ":" .. weaponHash

    local rollbackRequested = state.rollbackRequested
        or state.requestedSource == "legacy"
        or state.requestedSource == "rollback"
    if rollbackRequested then
        _activateProjection(
            state,
            state.rollbackVehicles,
            state.rollbackWeapons,
            _buildComponentProjection(state.rollbackComponents)
        )
        state.source = "rollback"
        state.runtimePolicy = "rollback-only"
        state.fallbackReason = "explicit-init-rollback"
    elseif state.requestedSource == "candidate-v1" and state.candidateAvailable then
        local vehicles, vehicleError = _buildVehicleProjection(
            state.rollbackVehicles,
            state.candidateVehicles,
            state
        )
        local weapons, weaponError = _buildWeaponProjection(
            state.rollbackWeapons,
            state.candidateWeapons,
            state
        )
        if vehicles ~= nil and weapons ~= nil then
            _activateProjection(
                state,
                vehicles,
                weapons,
                _buildComponentProjection(state.rollbackComponents)
            )
            state.source = "candidate-v1"
            state.runtimePolicy = "candidate-active"
            state.fallbackReason = ""
        else
            _clearRuntimeProjection(state)
            state.source = "blocked"
            state.runtimePolicy = "candidate-required"
            state.fallbackReason = vehicleError or weaponError or "candidate parity failed"
        end
    else
        _clearRuntimeProjection(state)
        state.source = "blocked"
        state.runtimePolicy = "candidate-required"
        state.fallbackReason = "candidate-manifest-or-artifact-invalid"
    end

    state.bootstrapVehicles = {}
    state.bootstrapWeapons = {}
    state.bootstrapComponents = {}
    state.frozen = true
    state.initialized = true
    return state
end

function authority.isFrozen()
    return authority.state.frozen == true
end

function authority.source()
    return tostring(authority.state.source or "uninitialized")
end

function authority.lookup(catalog, definitionId)
    local state = authority.state
    if not state.initialized then return nil, "catalog authority is not initialized" end
    local id = tostring(definitionId or "")
    if type(catalog) ~= "table" or catalog[id] == nil then
        return nil, "definition is not in the frozen generated catalog"
    end
    state.candidateCalls = state.candidateCalls + 1
    return catalog[id], nil
end

function authority.lookupDefinition(kind, definitionId)
    local state = authority.state
    if not state.initialized then return nil, "catalog authority is not initialized" end
    local id = tostring(definitionId or "")
    local normalizedKind = tostring(kind or "")
    local catalog = normalizedKind == "weapon" and state.effectiveWeapons
        or normalizedKind == "component" and state.effectiveComponents
        or state.effectiveVehicles
    local value = catalog[id]
    if value == nil then return nil, "definition is not in the frozen projection" end
    state.candidateCalls = state.candidateCalls + 1
    return value, nil
end

function authority.registerLegacyDefinition(definitionId)
    local state = authority.state
    state.legacyDefinitionRegisterCalls = state.legacyDefinitionRegisterCalls + 1
    if state.frozen then
        state.rejectedAfterFreeze = state.rejectedAfterFreeze + 1
        return false, "legacy definition registration is frozen"
    end
    state.legacyAdapterCalls = state.legacyAdapterCalls + 1
    return false, "legacy definition registration is init-only import"
end

function authority.overrideDefinition(definitionId)
    local state = authority.state
    state.legacyDefinitionOverrideCalls = state.legacyDefinitionOverrideCalls + 1
    if state.frozen then
        state.rejectedAfterFreeze = state.rejectedAfterFreeze + 1
        return false, "definition override is frozen"
    end
    state.legacyAdapterCalls = state.legacyAdapterCalls + 1
    return false, "definition override is init-only import"
end

function authority.rollbackAtInit()
    if authority.state.initialized then
        return false, "rollback requires a new context initialization"
    end
    authority.state.rollbackRequested = true
    authority.state.source = "rollback"
    authority.state.runtimePolicy = "rollback-only"
    authority.state.fallbackReason = "explicit-rollback"
    return true, nil
end

function authority.getReport()
    local state = authority.state
    return {
        protocolVersion = authority.protocolVersion,
        initialized = state.initialized,
        frozen = state.frozen,
        requestedSource = state.requestedSource,
        source = state.source,
        runtimePolicy = state.runtimePolicy,
        candidateAvailable = state.candidateAvailable,
        candidateCatalogHash = state.candidateCatalogHash,
        rollbackCatalogHash = state.rollbackCatalogHash,
        fallbackReason = state.fallbackReason,
        candidateCalls = state.candidateCalls,
        legacyAdapterCalls = state.legacyAdapterCalls,
        legacyDefinitionImportCalls = state.legacyDefinitionImportCalls,
        legacyDefinitionRegisterCalls = state.legacyDefinitionRegisterCalls,
        legacyDefinitionOverrideCalls = state.legacyDefinitionOverrideCalls,
        rejectedAfterFreeze = state.rejectedAfterFreeze,
        parityChecks = state.parityChecks,
        parityPasses = state.parityPasses,
        parityMismatches = state.parityMismatches,
        vehicleCount = _count(state.candidateVehicles),
        weaponCount = _count(state.candidateWeapons),
        componentCount = _count(state.effectiveComponents),
        runtimeAuthority = state.source,
        bootstrapCleared = _count(state.bootstrapVehicles) == 0
            and _count(state.bootstrapWeapons) == 0
            and _count(state.bootstrapComponents) == 0,
    }
end

return authority
