---@diagnostic disable: undefined-global

-- Catalog Authority v1. Generated projections are selected, parity-checked
-- and frozen once per Runtime context. Legacy tables remain init-only rollback
-- sources until the later legacy-removal step.
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
        source = "legacy",
        runtimePolicy = "legacy-fallback",
        candidateAvailable = false,
        candidateCatalogHash = "",
        rollbackCatalogHash = "",
        fallbackReason = "not-initialized",
        candidateCalls = 0,
        legacyAdapterCalls = 0,
        rejectedAfterFreeze = 0,
        parityChecks = 0,
        parityPasses = 0,
        parityMismatches = 0,
        effectiveVehicles = {},
        effectiveWeapons = {},
        legacyVehicles = {},
        legacyWeapons = {},
        candidateVehicles = {},
        candidateWeapons = {},
    }
end

authority.state = authority.state or _newState()

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
    if _count(result) ~= _count(legacyDefinitions) then
        return nil, "candidate weapon catalog does not cover the legacy registry"
    end
    return result, nil
end

local function _activateProjection(state, vehicles, weapons)
    state.effectiveVehicles = vehicles
    state.effectiveWeapons = weapons
    -- Existing runtime modules resolve these globals dynamically. They now
    -- point at the frozen generated projection for this context.
    shipTypeRegistryData = vehicles
    weaponData = weapons
    if weaponCatalogUseRuntimeDefinitions ~= nil then
        weaponCatalogUseRuntimeDefinitions(weapons)
    end
end

function authority.init(requestedSource, manifest, generatedCatalog, rollbackHash)
    local state = authority.state
    if state.initialized then return state end

    state.requestedSource = tostring(requestedSource or "candidate-v1")
    state.rollbackCatalogHash = tostring(rollbackHash or "")
    state.legacyVehicles = shipTypeRegistryData or {}
    state.legacyWeapons = weaponData or {}

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

    if state.requestedSource == "candidate-v1" and state.candidateAvailable then
        local vehicles, vehicleError = _buildVehicleProjection(
            state.legacyVehicles,
            state.candidateVehicles,
            state
        )
        local weapons, weaponError = _buildWeaponProjection(
            state.legacyWeapons,
            state.candidateWeapons,
            state
        )
        if vehicles ~= nil and weapons ~= nil then
            _activateProjection(state, vehicles, weapons)
            state.source = "candidate-v1"
            state.runtimePolicy = "candidate-active"
            state.fallbackReason = ""
        else
            state.source = "legacy"
            state.runtimePolicy = "legacy-fallback"
            state.fallbackReason = vehicleError or weaponError or "candidate parity failed"
        end
    else
        state.source = "legacy"
        state.runtimePolicy = "legacy-fallback"
        state.fallbackReason = state.requestedSource == "legacy"
            and "explicit-legacy-source"
            or "candidate-manifest-or-artifact-invalid"
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
    if state.source == "candidate-v1" then
        local catalog = tostring(kind or "") == "weapon"
            and state.effectiveWeapons or state.effectiveVehicles
        local value = catalog[id]
        if value == nil then return nil, "definition is not in the frozen projection" end
        state.candidateCalls = state.candidateCalls + 1
        return value, nil
    end
    return tostring(kind or "") == "weapon"
        and state.legacyWeapons[id] or state.legacyVehicles[id], nil
end

function authority.registerLegacyDefinition(definitionId)
    local state = authority.state
    if state.frozen then
        state.rejectedAfterFreeze = state.rejectedAfterFreeze + 1
        return false, "legacy definition registration is frozen"
    end
    state.legacyAdapterCalls = state.legacyAdapterCalls + 1
    return tostring(definitionId or "") ~= "", nil
end

function authority.overrideDefinition(definitionId)
    local state = authority.state
    if state.frozen then
        state.rejectedAfterFreeze = state.rejectedAfterFreeze + 1
        return false, "definition override is frozen"
    end
    state.legacyAdapterCalls = state.legacyAdapterCalls + 1
    return tostring(definitionId or "") ~= "", nil
end

function authority.rollbackAtInit()
    if authority.state.initialized then
        return false, "rollback requires a new context initialization"
    end
    authority.state.source = "legacy"
    authority.state.runtimePolicy = "legacy-fallback"
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
        rejectedAfterFreeze = state.rejectedAfterFreeze,
        parityChecks = state.parityChecks,
        parityPasses = state.parityPasses,
        parityMismatches = state.parityMismatches,
        vehicleCount = _count(state.candidateVehicles),
        weaponCount = _count(state.candidateWeapons),
    }
end

return authority
