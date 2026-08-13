-- Ship-side adapter for the Gate 4.3 World Host skeleton.
-- It registers identity/capabilities and heartbeats only; existing ship and
-- weapon runtime remains the authority for movement, damage and firing.

cm2ShipInstanceAdapterV1 = cm2ShipInstanceAdapterV1 or {}
local adapter = cm2ShipInstanceAdapterV1

adapter.rootKey = "cm2/world-host/v1"
adapter.heartbeatInterval = 0.5
adapter.state = adapter.state or {
    initialized = false,
    disposed = false,
    mode = "local",
    fallbackReason = "",
    identity = "",
    ownerId = "",
    generation = 0,
    elapsed = 0.0,
    heartbeat = 0,
    slot = 0,
    presentationSequence = 0,
    presentationBypass = 0,
    registration = nil,
    capabilities = {},
}

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback end
    return value
end

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _readString(key, fallback)
    if GetString == nil then return fallback end
    return _safeString(GetString(key), fallback)
end

local function _readInt(key, fallback)
    if GetInt == nil then return fallback end
    return math.floor(_safeNumber(GetInt(key), fallback))
end

local function _readBool(key, fallback)
    if GetBool == nil then return fallback end
    return GetBool(key)
end

local function _writeString(key, value)
    if SetString ~= nil then SetString(key, tostring(value or ""), true) end
end

local function _writeInt(key, value)
    if SetInt ~= nil then SetInt(key, math.floor(_safeNumber(value, 0)), true) end
end

local function _writeBool(key, value)
    if SetBool ~= nil then SetBool(key, value and true or false, true) end
end

local function _safeKey(value)
    return tostring(value or ""):gsub("[^%w_%-:]", "_")
end

local function _hashSlot(value)
    local total = 0
    local text = tostring(value or "")
    for index = 1, #text do total = total + (string.byte(text, index) or 0) * index end
    return (total % 12) + 1
end

local function _eventSlot(value)
    local total = 0
    local text = tostring(value or "")
    for index = 1, #text do total = total + (string.byte(text, index) or 0) * (index + 3) end
    return (total % 32) + 1
end

local function _capabilityMap(capabilities)
    local result = {}
    if type(capabilities) ~= "table" then return result end
    for key, value in pairs(capabilities) do
        if type(key) == "number" then result[tostring(value)] = true else result[tostring(key)] = value and true or false end
    end
    return result
end

local function _publishAnnouncement()
    local state = adapter.state
    local key = adapter.rootKey .. "/announcement/slot/" .. tostring(state.slot)
    _writeString(key .. "/protocolVersion", "cm2.world/1")
    _writeString(key .. "/id", state.identity)
    _writeString(key .. "/owner", state.ownerId)
    _writeString(key .. "/mode", state.mode)
    _writeInt(key .. "/generation", state.generation)
    _writeInt(key .. "/heartbeat", state.heartbeat)
    _writeBool(key .. "/active", state.initialized and not state.disposed)
end

function adapter.serverInit(identity, capabilities, ownerId)
    local state = adapter.state
    state.initialized = false
    state.disposed = false
    state.fallbackReason = ""
    state.identity = _safeString(identity, "ship-instance")
    state.ownerId = _safeString(ownerId, state.identity)
    state.capabilities = _capabilityMap(capabilities)
    local requestedSlot = ""
    if GetStringParam ~= nil then requestedSlot = GetStringParam("worldslot", "") end
    local numericSlot = math.floor(_safeNumber(requestedSlot, 0))
    state.slot = (numericSlot >= 1 and numericSlot <= 12) and numericSlot or _hashSlot(state.identity)
    state.elapsed = 0.0
    state.heartbeat = 0
    state.presentationSequence = 0
    state.presentationBypass = 0
    state.registration = nil
    local hostReady = _readBool(adapter.rootKey .. "/ready", false)
    local hostMode = _readString(adapter.rootKey .. "/mode", "local")
    local hostGeneration = _readInt(adapter.rootKey .. "/generation", 0)
    if hostReady and hostMode == "content-host" and hostGeneration > 0 then
        state.mode = "content-host"
        state.generation = hostGeneration
        _publishAnnouncement()
    else
        state.mode = "local"
        state.generation = math.max(1, hostGeneration)
        state.fallbackReason = "content-host-unavailable"
        if cm2WorldHostV1 ~= nil then
            cm2WorldHostV1.serverInit("local", "local-host:" .. state.identity)
            state.registration = cm2WorldHostV1.registerInstance(state.identity, state.ownerId, state.capabilities)
            if state.registration == nil then state.fallbackReason = "local-registration-rejected" end
        end
    end
    state.initialized = true
    _publishAnnouncement()
    return adapter.getReport()
end

function adapter.publishPresentationEvent(kind, anchorId, critical, coalesceKey, effectId, emittedAt)
    local state = adapter.state
    if not state.initialized or state.disposed then return false, "adapter is not active" end
    state.presentationSequence = state.presentationSequence + 1
    if state.mode ~= "content-host" then
        state.presentationBypass = state.presentationBypass + 1
        return false, "legacy-local-owner"
    end
    local slot = _eventSlot(state.identity .. ":" .. tostring(state.presentationSequence))
    local prefix = adapter.rootKey:gsub("world%-host", "world-presentation") .. "/slot/" .. tostring(slot)
    _writeString(prefix .. "/source", state.identity)
    _writeString(prefix .. "/kind", _safeString(kind, "ambient"))
    _writeString(prefix .. "/coalesceKey", _safeString(coalesceKey, state.identity .. ":" .. tostring(kind or "ambient")))
    _writeString(prefix .. "/anchorId", _safeString(anchorId, ""))
    _writeString(prefix .. "/effectId", _safeString(effectId, ""))
    _writeString(prefix .. "/emittedAt", tostring(_safeNumber(emittedAt, 0.0)))
    _writeInt(prefix .. "/sequence", state.presentationSequence)
    _writeInt(prefix .. "/generation", state.generation)
    _writeBool(prefix .. "/critical", critical == true)
    _writeBool(prefix .. "/active", true)
    return true
end

function adapter.publishAnchorSnapshot(anchorId, cameraId, sequence)
    local state = adapter.state
    if not state.initialized or state.disposed then return false, "adapter is not active" end
    if state.mode ~= "content-host" then return false, "legacy-local-owner" end
    local key = adapter.rootKey:gsub("world%-host", "world-presentation") .. "/anchor/" .. _safeKey(state.identity)
    _writeString(key .. "/anchorId", _safeString(anchorId, ""))
    _writeString(key .. "/cameraId", _safeString(cameraId, ""))
    _writeInt(key .. "/generation", state.generation)
    _writeInt(key .. "/sequence", math.floor(_safeNumber(sequence, state.presentationSequence)))
    _writeBool(key .. "/active", true)
    return true
end

function adapter.serverTick(dt, destroyed)
    local state = adapter.state
    if not state.initialized or state.disposed then return false end
    if destroyed then adapter.dispose("ship-destroyed"); return false end
    local delta = math.max(0.0, _safeNumber(dt, 0.0))
    state.elapsed = state.elapsed + delta
    if state.elapsed < adapter.heartbeatInterval then return true end
    state.elapsed = state.elapsed - adapter.heartbeatInterval
    state.heartbeat = state.heartbeat + 1
    local currentGeneration = _readInt(adapter.rootKey .. "/generation", state.generation)
    local hostReady = _readBool(adapter.rootKey .. "/ready", false)
    if state.mode == "content-host" and (not hostReady or currentGeneration ~= state.generation) then
        state.mode = "local-fallback"
        state.fallbackReason = (not hostReady) and "host-missing" or "host-generation-changed"
        if cm2WorldHostV1 ~= nil then
            cm2WorldHostV1.serverInit("local", "local-host:" .. state.identity)
            state.generation = cm2WorldHostV1.generation()
            state.registration = cm2WorldHostV1.registerInstance(state.identity, state.ownerId, state.capabilities)
        end
    elseif state.mode == "content-host" then
        _publishAnnouncement()
    elseif cm2WorldHostV1 ~= nil and state.registration ~= nil then
        cm2WorldHostV1.heartbeatInstance(state.identity, state.ownerId, state.generation)
    end
    _publishAnnouncement()
    return true
end

function adapter.clientInit(identity)
    local state = adapter.state
    state.identity = _safeString(identity, state.identity ~= "" and state.identity or "ship-instance")
    state.mode = (_readBool(adapter.rootKey .. "/ready", false) and _readString(adapter.rootKey .. "/mode", "local") == "content-host") and "content-host" or "local"
    state.generation = _readInt(adapter.rootKey .. "/generation", 0)
    return adapter.getReport()
end

function adapter.clientTick(_dt)
    if not adapter.state.initialized then return false end
    local generation = _readInt(adapter.rootKey .. "/generation", adapter.state.generation)
    if generation ~= adapter.state.generation then adapter.state.generation = generation end
    return true
end

function adapter.dispose(reason)
    local state = adapter.state
    if state.disposed then return false end
    if state.registration ~= nil and cm2WorldHostV1 ~= nil and state.mode ~= "content-host" then
        cm2WorldHostV1.unregisterInstance(state.identity, state.ownerId, state.generation, reason)
    end
    state.disposed = true
    _publishAnnouncement()
    return true
end

function adapter.getReport()
    local state = adapter.state
    return {
        protocolVersion = "cm2.world/1",
        identity = state.identity,
        ownerId = state.ownerId,
        mode = state.mode,
        generation = state.generation,
        initialized = state.initialized,
        disposed = state.disposed,
        heartbeat = state.heartbeat,
        presentationSequence = state.presentationSequence,
        presentationBypass = state.presentationBypass,
        fallbackReason = state.fallbackReason,
        localAuthority = state.mode ~= "content-host",
        capabilities = state.capabilities,
    }
end
