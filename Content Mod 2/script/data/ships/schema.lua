---@diagnostic disable: undefined-global

shipTypeRegistryData = shipTypeRegistryData or {}

local _playerDefinitionFields = {
    shipType = true,
    displayName = true,
    englishName = true,
    controlMode = true,
    maxShieldHP = true,
    maxArmorHP = true,
    maxBodyHP = true,
    shieldRadius = true,
    flightProfile = true,
    engineFx = true,
    engineSound = true,
    hudProfile = true,
    cameraProfile = true,
    regen = true,
    componentProfile = true,
    externalDamage = true,
    weaponMountProfiles = true,
    defaultSlotConfigurationId = true,
    slotConfigurations = true,
}

local _aiDefinitionFields = {
    shipType = true,
    displayName = true,
    englishName = true,
    controlMode = true,
    interceptorClass = true,
    maxShieldHP = true,
    maxArmorHP = true,
    maxBodyHP = true,
    shieldRadius = true,
    externalDamage = true,
}

local _aiRequiredFields = {
    shipType = true,
    displayName = true,
    englishName = true,
    controlMode = true,
    interceptorClass = true,
    maxShieldHP = true,
    maxArmorHP = true,
    maxBodyHP = true,
    shieldRadius = true,
}

local _flightFields = {
    gravityCompensation = true,
    disableLiftVoxelRatio = true,
    forwardAcceleration = true,
    backwardAcceleration = true,
    maxCombatSpeed = true,
    maxReverseSpeed = true,
    quadraticDamping = true,
    dampingMinSpeed = true,
    attitude = true,
    roll = true,
}

local _attitudeFields = {
    yawDeadzone = true,
    pitchDeadzone = true,
    yawSoftZone = true,
    pitchSoftZone = true,
    yawForceGain = true,
    pitchForceGain = true,
    yawForceMax = true,
    pitchForceMax = true,
    yawDamping = true,
    pitchDamping = true,
    yawRateDeadzone = true,
    pitchRateDeadzone = true,
    yawLeverArm = true,
    pitchLeverArm = true,
}

local _rollFields = {
    deadzone = true,
    forceGain = true,
    forceMax = true,
    damping = true,
    rateDeadzone = true,
    leverArm = true,
    sign = true,
}

local _engineFxFields = {
    speedForFullTrail = true,
    throttleResponse = true,
    particleRate = true,
    maxParticleBurstsPerFrame = true,
    particleNearDistance = true,
    particleCutoffDistance = true,
    renderCutoffDistance = true,
    idleParticleRateScale = true,
    farParticleRateScale = true,
    profiles = true,
}

local _engineSoundFields = { idleLoopPath = true, volume = true }
local _hudFields = { targetMarkerSize = true }
local _cameraFields = {
    distance = true,
    distanceMin = true,
    distanceMax = true,
    pitchLimit = true,
    rearYawMin = true,
    rearYawMax = true,
    mouseSensitivity = true,
    glideStrength = true,
    zoomSpeed = true,
    switchDuration = true,
    frontOffset = true,
    frontPitchLimit = true,
    frontYawMin = true,
    frontYawMax = true,
    rearDefaultPitch = true,
    freelookTurnYawError = true,
    freelookTurnPitchError = true,
    rmbLongPressSeconds = true,
    fov = true,
}
local _regenFields = {
    tickInterval = true,
    shieldPerSecond = true,
    shieldNoDamageDelay = true,
    armorNoDamageDelay = true,
    bodyNoDamageDelay = true,
}
local _componentProfileFields = {
    baseArmorRegenPercent = true,
    baseHullRegenPercent = true,
}
local _externalDamageFields = {
    bulletDamage = true,
    explosionMinStrength = true,
    explosionMaxDistance = true,
    explosionDamageScale = true,
}

local function _requireTable(definition, fieldName)
    local value = definition[fieldName]
    if type(value) ~= "table" then
        error("ship " .. tostring(definition.shipType or "")
            .. " is missing table " .. fieldName)
    end
    return value
end

local function _validateFields(value, allowed, context, required)
    for key, _ in pairs(value) do
        if allowed[key] ~= true then
            error(context .. " has unsupported field " .. tostring(key))
        end
    end
    for key, _ in pairs(required or allowed) do
        if value[key] == nil then
            error(context .. " is missing field " .. tostring(key))
        end
    end
end

local function _validatePlayerDefinition(definition)
    _validateFields(definition, _playerDefinitionFields,
        "player ship " .. tostring(definition.shipType or ""))
    _validateFields(_requireTable(definition, "flightProfile"), _flightFields,
        "flightProfile")
    _validateFields(_requireTable(definition.flightProfile, "attitude"),
        _attitudeFields, "flightProfile.attitude")
    _validateFields(_requireTable(definition.flightProfile, "roll"),
        _rollFields, "flightProfile.roll")
    _validateFields(_requireTable(definition, "engineFx"), _engineFxFields,
        "engineFx", {
            speedForFullTrail = true,
            throttleResponse = true,
            particleRate = true,
            maxParticleBurstsPerFrame = true,
            particleNearDistance = true,
            particleCutoffDistance = true,
            renderCutoffDistance = true,
            idleParticleRateScale = true,
            farParticleRateScale = true,
        })
    _validateFields(_requireTable(definition, "engineSound"), _engineSoundFields,
        "engineSound")
    _validateFields(_requireTable(definition, "hudProfile"), _hudFields,
        "hudProfile")
    _validateFields(_requireTable(definition, "cameraProfile"), _cameraFields,
        "cameraProfile")
    _validateFields(_requireTable(definition, "regen"), _regenFields,
        "regen")
    _validateFields(_requireTable(definition, "componentProfile"),
        _componentProfileFields, "componentProfile")
    _validateFields(_requireTable(definition, "externalDamage"),
        _externalDamageFields, "externalDamage")
    if type(definition.weaponMountProfiles) ~= "table" then
        error("player ship " .. tostring(definition.shipType or "")
            .. " is missing weaponMountProfiles")
    end
    if type(definition.slotConfigurations) ~= "table"
        or #definition.slotConfigurations == 0 then
        error("player ship " .. tostring(definition.shipType or "")
            .. " must have slotConfigurations")
    end
end

local function _validateAiDefinition(definition)
    _validateFields(definition, _aiDefinitionFields,
        "AI ship " .. tostring(definition.shipType or ""), _aiRequiredFields)
    local class = tostring(definition.interceptorClass or "")
    if class ~= "strike_craft" and class ~= "missile" and class ~= "torpedo" then
        error("AI ship " .. tostring(definition.shipType or "")
            .. " has invalid interceptorClass " .. class)
    end
    if class == "strike_craft" then
        _validateFields(_requireTable(definition, "externalDamage"),
            _externalDamageFields, "externalDamage")
    elseif definition.externalDamage ~= nil then
        error("AI ship " .. tostring(definition.shipType or "")
            .. " must not define externalDamage")
    end
end

function shipDefinitionIsPlayerControlled(definition)
    return tostring((definition or {}).controlMode or "") == "player"
end

function shipDefinitionIsAiControlled(definition)
    return tostring((definition or {}).controlMode or "") == "ai"
end

function shipDefinitionIsPlayerConfigurable(definition)
    return shipDefinitionIsPlayerControlled(definition)
end

function shipDefinitionIsPlayerLockable(definition)
    return shipDefinitionIsPlayerControlled(definition)
end

function shipDefinitionRegister(definition)
    if type(definition) ~= "table" then error("ship definition must be a table") end
    local shipType = tostring(definition.shipType or "")
    if shipType == "" then error("ship definition is missing shipType") end
    if tostring(definition.displayName or "") == ""
        or tostring(definition.englishName or "") == "" then
        error("ship " .. shipType .. " is missing localized names")
    end
    local controlMode = tostring(definition.controlMode or "")
    if controlMode == "player" then
        _validatePlayerDefinition(definition)
    elseif controlMode == "ai" then
        _validateAiDefinition(definition)
    else
        error("ship " .. shipType .. " has invalid controlMode " .. controlMode)
    end
    if shipTypeRegistryData[shipType] ~= nil then
        error("duplicate ship definition " .. shipType)
    end
    shipTypeRegistryData[shipType] = definition
    return definition
end

function shipDefinitionGet(shipType, fallbackType)
    local requested = tostring(shipType or "")
    local fallback = tostring(fallbackType or "")
    return shipTypeRegistryData[requested]
        or shipTypeRegistryData[fallback]
        or {}
end

function shipDefinitionFindConfiguration(definition, configurationId)
    local requested = tostring(configurationId or "")
    local fallback = nil
    for _, configuration in ipairs((definition or {}).slotConfigurations or {}) do
        fallback = fallback or configuration
        if tostring(configuration.configurationId or "") == requested then
            return configuration
        end
        for _, alias in ipairs(configuration.legacyConfigurationIds or {}) do
            if tostring(alias or "") == requested then return configuration end
        end
    end
    return fallback
end

-- Slot groups are identified by their groupId.  A numbered group such as
-- lSlot2 uses the same weapon family as lSlot, but resolves to its own mount
-- collection and numbered mount profile.  Keeping this rule here prevents
-- loadout validation and runtime resolution from drifting apart.
function shipDefinitionGetGroupMountCollection(groupId, slotType)
    local requestedGroup = tostring(groupId or "")
    local normalizedGroup = string.lower(requestedGroup)
    local requestedType = string.lower(tostring(slotType or ""))
    local base, index = normalizedGroup:match("^(.-)slot(%d*)$")
    if base ~= nil and base ~= "" and requestedType ~= "" then
        if index == "" then
            return requestedType .. "Slots"
        end
        return requestedType .. "Slot" .. index .. "Slots"
    end
    return string.lower(requestedGroup) .. "Slots"
end

function shipDefinitionGetGroupMountProfileName(groupId, baseProfileName)
    local profileName = tostring(baseProfileName or "")
    if profileName == "" then return "" end

    local normalizedGroup = string.lower(tostring(groupId or ""))
    local _, index = normalizedGroup:match("^(.-)slot(%d*)$")
    if index ~= nil and index ~= "" then
        return profileName .. index
    end
    return profileName
end

-- Configuration snapshots use slot keys (L2), while runtime definitions use
-- group ids (lSlot2). Resolve that translation once at the data boundary.
function shipDefinitionGetGroupLoadoutKey(groupId, slotType)
    local normalizedGroup = string.lower(tostring(groupId or ""))
    local requestedType = string.upper(tostring(slotType or ""))
    local _, index = normalizedGroup:match("^(.-)slot(%d*)$")
    if index ~= nil and index ~= "" then
        return requestedType .. index
    end
    return requestedType
end

-- Slot configuration values are normalized once at the ship-data boundary.
-- Runtime weapon scheduling consumes this canonical integer and does not
-- reinterpret raw configuration values.
function shipDefinitionNormalizeSalvoGroupSize(value, count)
    if value == nil then return nil, nil end

    local numeric = tonumber(value)
    if numeric == nil or numeric ~= numeric then
        return nil, "salvoGroupSize must be numeric"
    end

    local normalized = math.floor(numeric)
    local limit = math.max(0, math.floor(tonumber(count) or 0))
    if normalized < 1 or normalized > limit then
        return nil, "salvoGroupSize must be between 1 and " .. tostring(limit)
    end
    return normalized, nil
end

function shipDefinitionFindSlotGroup(configuration, groupId)
    local requested = tostring(groupId or "")
    for _, group in ipairs((configuration or {}).slotGroups or {}) do
        if tostring(group.groupId or "") == requested then return group end
    end
    return nil
end

-- Keep catalog eligibility and physical mount eligibility in one shared rule so
-- the configurator never offers a weapon the runtime cannot construct.
function shipDefinitionWeaponFitsGroup(definition, configuration, group, weaponType)
    local ship = definition or {}
    local slotGroup = group or {}
    local slotType = string.upper(tostring(slotGroup.slotType or ""))
    local typeId = tostring(weaponType or "")
    local weapon = (weaponData or {})[typeId]
    if slotType == "" or typeId == "" or weapon == nil then
        return false, "weapon or slot group is missing"
    end

    local inCatalogPool = false
    for _, candidate in ipairs(weaponCatalogGetSlotPool(slotType)) do
        if tostring(candidate) == typeId then
            inCatalogPool = true
            break
        end
    end
    if not inCatalogPool then return false, "weapon is not available for slot type" end
    if weaponBehaviorProfiles == nil
        or weaponBehaviorProfiles[tostring(weapon.behaviorType or "")] ~= true then
        return false, "weapon behavior is not registered"
    end

    local count = math.max(0, math.floor(tonumber(slotGroup.count) or 0))
    local profileName = shipDefinitionGetGroupMountProfileName(
        slotGroup.groupId,
        weapon.mountProfile
    )
    local profile = ((ship.weaponMountProfiles or {})[profileName]) or {}
    if count <= 0 or profileName == "" or #profile < count then
        return false, "mount profile does not cover slot group"
    end

    local _, salvoError = shipDefinitionNormalizeSalvoGroupSize(
        slotGroup.salvoGroupSize,
        count
    )
    if salvoError ~= nil then return false, salvoError end
    return true, nil
end

function shipDefinitionResolveMounts(
    shipType,
    configurationId,
    groupId,
    weaponType
)
    local definition = shipDefinitionGet(shipType, shipType)
    local configuration = shipDefinitionFindConfiguration(
        definition,
        configurationId or definition.defaultSlotConfigurationId
    )
    local requestedGroup = tostring(groupId or "")
    local group = shipDefinitionFindSlotGroup(configuration, requestedGroup)
    if group == nil then return {} end

    local typeId = tostring(weaponType or "")
    if typeId == "" then
        local defaults = (configuration or {}).defaultLoadout or {}
        local loadoutKey = shipDefinitionGetGroupLoadoutKey(
            requestedGroup,
            group.slotType
        )
        typeId = tostring(defaults[requestedGroup]
            or defaults[loadoutKey]
            or defaults[tostring(group.slotType or "")] or "")
    end
    local weapon = (weaponData or {})[typeId] or {}
    local profileName = shipDefinitionGetGroupMountProfileName(
        requestedGroup,
        weapon.mountProfile
    )
    local profile = ((definition.weaponMountProfiles or {})[profileName]) or {}
    local count = math.max(0, math.floor(tonumber(group.count) or 0))
    local mounts = {}
    for i = 1, math.min(count, #profile) do
        local source = profile[i] or {}
        local mount = {}
        for key, value in pairs(source) do mount[key] = value end
        mount.weaponType = typeId
        mounts[i] = mount
    end
    return mounts
end
