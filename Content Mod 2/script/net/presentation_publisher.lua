---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Narrow server-side publication boundary for presentation facts.
-- Weapon behaviour supplies a semantic kind and payload; this module owns the
-- legacy callback names and the event-v1 transport switch.
server = server or {}

server.presentationPublisherState = server.presentationPublisherState or {
    initialized = false,
    mode = "legacy",
    sequence = 0,
    sourceSequenceById = {},
    published = 0,
    legacyAdapterCalls = 0,
    eventV1Calls = 0,
    rejected = 0,
    byKind = {},
    sliceMode = {},
    bySlice = {},
}

local _sliceByWeapon = {
    flakArtillery = "ray-beam",
    gigaCannon = "logical-projectile",
    swarmerMissile = "guided-missile",
    tachyonLance = "tachyon-charge-beam",
    perditionBeam = "tachyon-charge-beam",
}

local _routes = {
    ["ray.shieldImpact"] = { channel = "weapon.impact", callback = "client.playProjectileShieldImpactFx" },
    ["weapon.sound"] = { channel = "weapon.sound", callback = "client.playWeaponSound" },
    ["ray.effect"] = { channel = "weapon.beam", callback = "client.spawnGenericRaycastWeaponFx" },
    ["tSlot.render"] = { channel = "weapon.beam", callback = "client.receiveTSlotRenderEvent" },
    ["xSlot.render"] = { channel = "weapon.beam", callback = "client.receiveXSlotRenderEvent" },
    ["projectile.fireSound"] = { channel = "weapon.sound", callback = "client.playKineticArtilleryFireSound" },
    ["projectile.hitSound"] = { channel = "weapon.sound", callback = "client.playKineticArtilleryHitSound" },
    ["projectile.shieldImpact"] = { channel = "weapon.impact", callback = "client.playProjectileShieldImpactFx" },
    ["projectile.spawn"] = { channel = "weapon.projectile", callback = "client.spawnProjectileVisual" },
    ["projectile.finish"] = { channel = "weapon.impact", callback = "client.finishProjectileVisual" },
    ["missile.finish"] = { channel = "missile.finish", callback = "client.finishMissileVisual" },
    ["missile.spawn"] = { channel = "missile.spawn", callback = "client.spawnMissileVisual" },
    ["missile.fireSound"] = { channel = "weapon.fireFx", callback = "client.playMissileFireSound" },
    ["missile.impactSound"] = { channel = "weapon.hitFx", callback = "client.playMissileImpactSound" },
    ["missile.impactFx"] = { channel = "weapon.hitFx", callback = "client.playMissileImpactFx" },
    ["missile.muzzle"] = { channel = "weapon.fireFx", callback = "client.spawnWeaponMuzzleFx" },
    ["craft.launch"] = { channel = "weapon.fireFx", callback = "client.spawnHSlotLaunchFx" },
    ["craft.register"] = { channel = "weapon.fireFx", callback = "client.registerHSlotCraftFx" },
    ["craft.recover"] = { channel = "weapon.fireFx", callback = "client.spawnHSlotRecoverFx" },
}

local function _unpack(values)
    if type(values) ~= "table" then return end
    local unpackFunction = table.unpack or unpack
    return unpackFunction(values)
end

local function _nextSequence()
    local state = server.presentationPublisherState
    state.sequence = math.floor(state.sequence or 0) + 1
    if state.sequence > 2000000000 then state.sequence = 1 end
    return state.sequence
end

local function _nextSourceSequence(sourceId)
    local state = server.presentationPublisherState
    local key = tostring(sourceId or "world")
    local nextValue = math.floor((state.sourceSequenceById[key] or 0) + 1)
    if nextValue > 2000000000 then nextValue = 1 end
    state.sourceSequenceById[key] = nextValue
    return nextValue
end

local function _sliceFor(data)
    local weapon = tostring((data or {}).weaponType or (data or {}).weaponId or "")
    return _sliceByWeapon[weapon] or tostring((data or {}).slice or "")
end

local function _position(value)
    if type(value) ~= "table" then return nil end
    return {
        tonumber(value[1] or value.x) or 0.0,
        tonumber(value[2] or value.y) or 0.0,
        tonumber(value[3] or value.z) or 0.0,
    }
end

local function _buildEvent(kind, data, sequence, sourceSequence)
    data = data or {}
    local sourceId = tostring(data.sourceId or data.sourceBodyId or "world")
    local weaponId = data.weaponId or data.weaponType
    local source = cm2PresentationEventV1.newEntityRef(sourceId, math.floor(tonumber(data.generation) or 0))
    local result = {
        protocolVersion = cm2PresentationEventV1.protocolVersion,
        sequence = sequence,
        kind = tostring(kind or "sound"),
        source = source,
        seed = math.max(0, math.floor(tonumber(data.seed) or sequence)),
        priority = tonumber(data.priority) or 0,
        serverTime = (GetTime ~= nil and GetTime()) or 0.0,
        payload = data.payload or {},
        extensions = { sourceSequence = sourceSequence },
    }
    if weaponId ~= nil and tostring(weaponId) ~= "" then
        result.weapon = cm2PresentationEventV1.newDefinitionRef(
            "cm2:weapon/" .. tostring(weaponId),
            "cm2.weapon/1"
        )
    end
    if data.effectId ~= nil and tostring(data.effectId) ~= "" then
        result.effect = cm2PresentationEventV1.newDefinitionRef(
            "cm2:effect/" .. tostring(data.effectId),
            "cm2.effect/1"
        )
    end
    local position = _position(data.position)
    if position ~= nil then result.transform = { position = position } end
    if data.targetId ~= nil then
        result.target = cm2PresentationEventV1.newEntityRef(
            tostring(data.targetId),
            math.floor(tonumber(data.targetGeneration) or 0)
        )
    end
    if data.hit ~= nil then result.hit = data.hit end
    return result
end

function server.presentationPublisherInit()
    local state = server.presentationPublisherState
    if state.initialized then return state end
    local authorityMode = (cm2EffectRuntimeAuthority ~= nil and cm2EffectRuntimeAuthority.init().mode) or "legacy"
    local requestedParam = (GetStringParam ~= nil and GetStringParam("presentationRuntime", "")) or ""
    if tostring(requestedParam or "") == "" and GetString ~= nil then
        requestedParam = GetString("StellarisShips/testing/scenario/presentationRuntime")
    end
    local requested = tostring(requestedParam or "")
    if requested == "" then requested = authorityMode end
    requested = tostring(requested or "legacy")
    if requested ~= "legacy" and requested ~= "event-v1" then requested = "legacy" end
    state.mode = requested
    state.sequence = 0
    state.sourceSequenceById = {}
    state.published = 0
    state.legacyAdapterCalls = 0
    state.eventV1Calls = 0
    state.rejected = 0
    state.byKind = {}
    state.sliceMode = {}
    state.bySlice = {}
    for _, slice in ipairs({ "ray-beam", "logical-projectile", "guided-missile", "tachyon-charge-beam" }) do
        local parameterName = "presentationRuntime_" .. slice:gsub("-", "_")
        local selected = (GetStringParam ~= nil and GetStringParam(parameterName, "")) or ""
        if selected ~= "legacy" and selected ~= "event-v1" then selected = requested end
        state.sliceMode[slice] = selected
        state.bySlice[slice] = { published = 0, legacyAdapterCalls = 0, eventV1Calls = 0, rejected = 0 }
    end
    state.initialized = true
    return state
end

function server.presentationPublisherSetSliceMode(slice, mode)
    local key = tostring(slice or "")
    if server.presentationPublisherState.sliceMode[key] == nil then return false, "unknown slice" end
    if mode ~= "legacy" and mode ~= "event-v1" then return false, "unsupported presentation mode" end
    -- This API is intended for init/configuration only; callers must set it
    -- before the first publish and cannot change a running slice.
    if server.presentationPublisherState.published > 0 then return false, "slice mode is frozen after first publish" end
    server.presentationPublisherState.sliceMode[key] = mode
    return true
end

function server.presentationPublisherGetMode()
    return tostring((server.presentationPublisherState or {}).mode or "legacy")
end

function server.presentationPublisherGetDiagnostics()
    local state = server.presentationPublisherState
    return {
        mode = state.mode,
        sequence = state.sequence,
        published = state.published,
        legacyAdapterCalls = state.legacyAdapterCalls,
        eventV1Calls = state.eventV1Calls,
        rejected = state.rejected,
        byKind = state.byKind,
    }
end

function server.presentationPublisherPublish(kind, data)
    local state = server.presentationPublisherState
    if not state.initialized then server.presentationPublisherInit() end
    data = data or {}
    local kindName = tostring(kind or "sound")
    local slice = _sliceFor(data)
    local selectedMode = server.presentationPublisherState.sliceMode[slice]
        or server.presentationPublisherState.mode
    local sequence = _nextSequence()
    local sourceId = tostring(data.sourceId or data.sourceBodyId or "world")
    local sourceSequence = _nextSourceSequence(sourceId)
    local eventValue = _buildEvent(kindName, data, sequence, sourceSequence)
    local encoded, encodeError = cm2PresentationEventV1.encode(eventValue)
    if encoded == nil then
        state.rejected = state.rejected + 1
        return false, encodeError
    end
    state.published = state.published + 1
    if server.cm2TelemetryRecord ~= nil then
        server.cm2TelemetryRecord("presentation_event", {
            kind = kindName,
            route = tostring(data.route or ""),
            source_body_id = math.floor(tonumber(data.sourceBodyId) or 0),
            target_body_id = math.floor(tonumber(data.targetId) or 0),
            weapon_type = tostring(data.weaponType or data.weaponId or ""),
            effect_id = tostring(data.effectId or ""),
            presentation_sequence = sequence,
            source_sequence = sourceSequence,
            event_type = tostring((data.payload or {}).eventType or ""),
        })
    end
    state.byKind[kindName] = math.floor(state.byKind[kindName] or 0) + 1
    local sliceStats = state.bySlice[slice]
    if sliceStats == nil then
        sliceStats = { published = 0, legacyAdapterCalls = 0, eventV1Calls = 0, rejected = 0 }
        state.bySlice[slice] = sliceStats
    end
    sliceStats.published = sliceStats.published + 1
    if server.netDebugCount ~= nil then server.netDebugCount("presentation.publish", 1) end

    if selectedMode == "event-v1" then
        local playerId = math.floor(tonumber(data.playerId) or 0)
        server.netClientCall(
            "presentation.event-v1",
            playerId,
            "client.receiveWeaponPresentationEventV1",
            encoded
        )
        state.eventV1Calls = state.eventV1Calls + 1
        sliceStats.eventV1Calls = sliceStats.eventV1Calls + 1
        return true, encoded
    end

    local route = _routes[tostring(data.route or "")]
    if route == nil then
        state.rejected = state.rejected + 1
        sliceStats.rejected = sliceStats.rejected + 1
        return false, "unknown legacy presentation route: " .. tostring(data.route)
    end
    local args = data.routeArgs or {}
    server.netClientCall(route.channel, math.floor(tonumber(data.playerId) or 0), route.callback, _unpack(args))
    state.legacyAdapterCalls = state.legacyAdapterCalls + 1
    sliceStats.legacyAdapterCalls = sliceStats.legacyAdapterCalls + 1
    return true, encoded
end
