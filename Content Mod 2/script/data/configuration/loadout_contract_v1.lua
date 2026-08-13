---@diagnostic disable: undefined-global

-- Pure Loadout/Configuration DTO contract.  It deliberately has no Teardown
-- API calls so client UI, server validation, compiler/importer and save code
-- can share the same semantics without creating a second runtime registry.
cm2LoadoutContractV1 = cm2LoadoutContractV1 or {}

local _contract = cm2LoadoutContractV1
_contract.schemaVersion = "cm2.loadout/1"
_contract.currentRevision = 1
_contract.missingPolicy = {
    weapon = "reject",
    mount = "degrade-empty",
    component = "degrade-empty",
    configuration = "fallback-default",
    downgrade = "reject",
}
_contract._frozen = _contract._frozen or false
_contract._configurationAliases = _contract._configurationAliases or {}

local function _clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = _clone(item) end
    return result
end

local function _error(code, path, expected, actual, suggestion)
    return {
        code = tostring(code or "invalid"),
        fieldPath = tostring(path or ""),
        expected = tostring(expected or ""),
        actual = tostring(actual or ""),
        suggestion = tostring(suggestion or ""),
    }
end

local function _canonicalId(value, prefix)
    local text = tostring(value or "")
    if text == "" then return "" end
    if string.sub(text, 1, #prefix) == prefix then return text end
    return prefix .. text
end

local function _isCanonical(value, prefix)
    local text = tostring(value or "")
    return string.sub(text, 1, #prefix) == prefix and #text > #prefix
end

local function _sortedKeys(value)
    local keys = {}
    for key, _ in pairs(value or {}) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    return keys
end

local function _appendUnique(list, value)
    for _, existing in ipairs(list) do
        if existing == value then return end
    end
    list[#list + 1] = value
end

local function _configurationId(vehicleId, requested, defaults, aliases)
    local value = tostring(requested or "")
    local aliasTable = aliases or _contract._configurationAliases[vehicleId] or {}
    if aliasTable[value] ~= nil then
        return tostring(aliasTable[value]), "alias:" .. value
    end
    if value ~= "" then return value, nil end
    local fallback = tostring(defaults or "")
    if fallback ~= "" then return fallback, "default:" .. fallback end
    return "", "missing"
end

local function _normalizeMap(value, prefix, path, errors, warnings, policy)
    local result = {}
    if value == nil then return result end
    if type(value) ~= "table" then
        errors[#errors + 1] = _error("wrong-type", path, "object", type(value), "send a slot/group map")
        return result
    end
    for _, key in ipairs(_sortedKeys(value)) do
        local raw = value[key]
        if raw == nil or tostring(raw) == "" then
            if policy == "reject" then
                errors[#errors + 1] = _error("missing-id", path .. "." .. key, prefix .. "<id>", raw, "choose a compiled definition")
            else
                warnings[#warnings + 1] = path .. "." .. key .. ": empty value degraded"
                result[key] = ""
            end
        else
            local id = _canonicalId(raw, prefix)
            if not _isCanonical(id, prefix) then
                errors[#errors + 1] = _error("invalid-id", path .. "." .. key, prefix .. "<id>", raw, "use the namespaced generated ID")
            else
                result[key] = id
            end
        end
    end
    return result
end

function _contract.registerConfigurationAlias(vehicleId, alias, canonicalId)
    if _contract._frozen then
        return false, _error("registry-frozen", "configurationAliases", "init-time only", "frozen", "register aliases before context initialization")
    end
    local vehicle = tostring(vehicleId or "")
    local oldId = tostring(alias or "")
    local newId = tostring(canonicalId or "")
    if vehicle == "" or oldId == "" or newId == "" then
        return false, _error("missing-field", "configurationAliases", "vehicle/alias/canonicalId", vehicle .. "/" .. oldId, "provide all alias fields")
    end
    _contract._configurationAliases[vehicle] = _contract._configurationAliases[vehicle] or {}
    _contract._configurationAliases[vehicle][oldId] = newId
    return true, nil
end

function _contract.freeze()
    _contract._frozen = true
    return true
end

function _contract.isFrozen()
    return _contract._frozen == true
end

function _contract.validate(snapshot)
    local errors, warnings = {}, {}
    if type(snapshot) ~= "table" then
        return nil, { _error("wrong-type", "snapshot", "object", type(snapshot), "send a LoadoutSnapshot table") }, warnings
    end
    if tostring(snapshot.schemaVersion or "") ~= _contract.schemaVersion then
        errors[#errors + 1] = _error("schema-version", "schemaVersion", _contract.schemaVersion, snapshot.schemaVersion, "migrate v0 or upgrade the DTO")
    end
    local revision = tonumber(snapshot.revision)
    if revision == nil then
        errors[#errors + 1] = _error("missing-field", "revision", "integer >= 1", snapshot.revision, "set revision to the compiled vehicle revision")
    elseif revision < 1 or math.floor(revision) ~= revision then
        errors[#errors + 1] = _error("invalid-range", "revision", "positive integer", revision, "use a non-negative compiled revision")
    end
    if not _isCanonical(snapshot.vehicleId, "cm2:vehicle/") then
        errors[#errors + 1] = _error("invalid-id", "vehicleId", "cm2:vehicle/<id>", snapshot.vehicleId, "use the generated vehicle ID")
    end
    if tostring(snapshot.configurationId or "") == "" then
        errors[#errors + 1] = _error("missing-field", "configurationId", "compiled configuration ID", snapshot.configurationId, "select the default configuration")
    end
    local loadout = _normalizeMap(snapshot.loadout, "cm2:weapon/", "loadout", errors, warnings, _contract.missingPolicy.weapon)
    local componentLoadout = _normalizeMap(snapshot.componentLoadout, "cm2:component/", "componentLoadout", errors, warnings, _contract.missingPolicy.component)
    if snapshot.groups ~= nil and type(snapshot.groups) ~= "table" then
        errors[#errors + 1] = _error("wrong-type", "groups", "array", type(snapshot.groups), "send group IDs as an array")
    end
    if snapshot.mountRevision ~= nil and tonumber(snapshot.mountRevision) == nil then
        errors[#errors + 1] = _error("wrong-type", "mountRevision", "integer", snapshot.mountRevision, "use the compiled mount revision")
    end
    if #errors > 0 then return nil, errors, warnings end
    local normalized = _clone(snapshot)
    normalized.schemaVersion = _contract.schemaVersion
    normalized.revision = math.floor(tonumber(revision) or 0)
    normalized.vehicleId = tostring(snapshot.vehicleId)
    normalized.loadout = loadout
    normalized.componentLoadout = componentLoadout
    normalized.groups = _clone(snapshot.groups or {})
    normalized.migration = nil
    return normalized, errors, warnings
end

function _contract.migrateV0(snapshot, vehicleId, defaultConfigurationId, aliases)
    if type(snapshot) ~= "table" then
        return nil, { _error("wrong-type", "snapshot", "object", type(snapshot), "send the legacy loadout object") }
    end
    if tostring(snapshot.schemaVersion or "") == _contract.schemaVersion then
        local normalized, errors, warnings = _contract.validate(snapshot)
        if normalized ~= nil then
            return normalized, errors, warnings
        end
        return nil, errors, warnings
    end
    local resolvedVehicleId = _canonicalId(vehicleId or snapshot.vehicleId, "cm2:vehicle/")
    if not _isCanonical(resolvedVehicleId, "cm2:vehicle/") then
        return nil, { _error("invalid-id", "vehicleId", "cm2:vehicle/<id>", vehicleId or snapshot.vehicleId, "supply the owning vehicle") }
    end
    local configurationId, aliasNote = _configurationId(
        resolvedVehicleId,
        snapshot.configurationId or snapshot.configuration,
        defaultConfigurationId,
        aliases
    )
    local migrated = {
        schemaVersion = _contract.schemaVersion,
        revision = 1,
        vehicleId = resolvedVehicleId,
        configurationId = configurationId,
        mountRevision = tonumber(snapshot.mountRevision) or 1,
        groups = _clone(snapshot.groups or {}),
        loadout = _clone(snapshot.loadout or {}),
        componentLoadout = _clone(snapshot.componentLoadout or {}),
        migration = {
            fromRevision = 0,
            aliasApplied = aliasNote,
            warnings = {},
        },
    }
    if aliasNote == "missing" then
        migrated.migration.warnings[#migrated.migration.warnings + 1] = "configuration missing; default policy selected"
    elseif string.sub(aliasNote or "", 1, 6) == "alias:" then
        migrated.migration.warnings[#migrated.migration.warnings + 1] = "legacy configuration alias resolved once"
    end
    local normalized, errors, warnings = _contract.validate(migrated)
    if normalized == nil then return nil, errors, warnings end
    normalized.migration = migrated.migration
    for _, warning in ipairs(warnings or {}) do
        _appendUnique(normalized.migration.warnings, warning)
    end
    return normalized, errors, normalized.migration.warnings
end

function _contract.validateAgainstFit(snapshot, fitMatrix)
    local normalized, errors, warnings = _contract.validate(snapshot)
    if normalized == nil then return nil, errors, warnings end
    local fit = fitMatrix or {}
    local allowed = fit.allowedWeapons or {}
    local allowedComponents = fit.allowedComponents or {}
    local allowedMounts = fit.allowedMounts or {}
    for groupId, weaponId in pairs(normalized.loadout or {}) do
        if weaponId ~= "" and allowed[groupId] ~= nil and allowed[groupId][weaponId] ~= true then
            errors[#errors + 1] = _error("fit-rejected", "loadout." .. tostring(groupId), "weapon allowed by compiled fit matrix", weaponId, "choose an ID from the slot group")
        end
    end
    for groupId, componentId in pairs(normalized.componentLoadout or {}) do
        if componentId ~= "" and allowedComponents[groupId] ~= nil and allowedComponents[groupId][componentId] ~= true then
            errors[#errors + 1] = _error("fit-rejected", "componentLoadout." .. tostring(groupId), "component allowed by compiled fit matrix", componentId, "choose an allowed component")
        end
    end
    for _, mountId in ipairs(normalized.mounts or {}) do
        if allowedMounts[mountId] == false then
            errors[#errors + 1] = _error("mount-rejected", "mounts", "mount allowed by compiled fit matrix", mountId, "reload the current vehicle mount revision")
        end
    end
    return normalized, errors, warnings
end

local function _escape(value)
    return (tostring(value or ""):gsub("%%", "%%25"):gsub("|", "%%7C"):gsub("=", "%%3D"):gsub(";", "%%3B"))
end

function _contract.encode(snapshot)
    local normalized, errors, warnings = _contract.validate(snapshot)
    if normalized == nil then return nil, errors, warnings end
    local parts = {
        "cm2.loadout/1", "vehicle=" .. _escape(normalized.vehicleId),
        "revision=" .. tostring(normalized.revision),
        "configuration=" .. _escape(normalized.configurationId),
    }
    local groupParts = {}
    for _, key in ipairs(_sortedKeys(normalized.loadout)) do groupParts[#groupParts + 1] = _escape(key) .. "=" .. _escape(normalized.loadout[key]) end
    parts[#parts + 1] = "weapons=" .. table.concat(groupParts, ";")
    local componentParts = {}
    for _, key in ipairs(_sortedKeys(normalized.componentLoadout)) do componentParts[#componentParts + 1] = _escape(key) .. "=" .. _escape(normalized.componentLoadout[key]) end
    parts[#parts + 1] = "components=" .. table.concat(componentParts, ";")
    return table.concat(parts, "|"), errors, warnings
end

function _contract.snapshotHash(snapshot)
    local encoded, errors, warnings = _contract.encode(snapshot)
    if encoded == nil then return nil, errors, warnings end
    local hash = 2166136261
    for index = 1, #encoded do
        hash = (hash * 16777619 + string.byte(encoded, index)) % 4294967296
    end
    return string.format("%08x", hash), errors, warnings
end

return _contract
