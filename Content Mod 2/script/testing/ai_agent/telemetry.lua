---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- CM2_TEST_V1 structured telemetry.
--
-- The game has no socket/file API that is suitable for a portable mod.  The
-- registry is therefore the authority boundary.  Teardown's public
-- UiTextInput is used as a short-lived transport adapter because the direct
-- clipboard functions are engine-internal and reject calls from mods.  The
-- adapter is dormant until F8 is pressed and only responds to a request that
-- carries a nonce.

server = server or {}
client = client or {}

cm2AiAgentTelemetry = cm2AiAgentTelemetry or {}
local telemetry = cm2AiAgentTelemetry

telemetry.protocol = "CM2_TEST_V1"
telemetry.root = "StellarisShips/telemetry/v1"
telemetry.ringSize = 512
telemetry.maxResponseBytes = 49152
telemetry.maxEvents = 64
telemetry.maxShips = 64
telemetry.initialized = telemetry.initialized or false
telemetry.serverInitialized = telemetry.serverInitialized or false
telemetry.clientInitialized = telemetry.clientInitialized or false
telemetry.session = telemetry.session or ""
telemetry.lastRequest = telemetry.lastRequest or ""
telemetry.pendingRequest = telemetry.pendingRequest or nil
telemetry.lastW = telemetry.lastW or false
telemetry.lastLmb = telemetry.lastLmb or false
telemetry.inputEdge = telemetry.inputEdge or { w = false, lmb = false }
telemetry.clientEventSeq = telemetry.clientEventSeq or 0
telemetry.bridgeActive = telemetry.bridgeActive or false
telemetry.bridgeFocus = telemetry.bridgeFocus or false
telemetry.bridgeText = telemetry.bridgeText or ""
telemetry.bridgeOpenedAt = telemetry.bridgeOpenedAt or 0.0
telemetry.bridgeTimeout = 8.0
telemetry.bridgeResponseAt = telemetry.bridgeResponseAt or 0.0
telemetry.bridgeResponseCloseDelay = 0.45

local function _number(value, fallback)
    local result = tonumber(value)
    if result == nil or result ~= result
        or result == math.huge or result == -math.huge then
        return fallback or 0.0
    end
    return result
end

local function _integer(value, fallback)
    return math.floor(_number(value, fallback or 0))
end

local function _boolean(value)
    return value and true or false
end

local function _string(value, fallback)
    if value == nil then return fallback or "" end
    return tostring(value)
end

local function _vec(value)
    if type(value) ~= "table" then return { 0.0, 0.0, 0.0 } end
    return {
        _number(value[1], 0.0),
        _number(value[2], 0.0),
        _number(value[3], 0.0),
    }
end

local function _quat(value)
    if type(value) ~= "table" then return { 0.0, 0.0, 0.0, 1.0 } end
    return {
        _number(value[1], 0.0),
        _number(value[2], 0.0),
        _number(value[3], 0.0),
        _number(value[4], 1.0),
    }
end

local function _jsonEscape(value)
    local result = { '"' }
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte == 34 then
            result[#result + 1] = '\\"'
        elseif byte == 92 then
            result[#result + 1] = '\\\\'
        elseif byte == 8 then
            result[#result + 1] = '\\b'
        elseif byte == 12 then
            result[#result + 1] = '\\f'
        elseif byte == 10 then
            result[#result + 1] = '\\n'
        elseif byte == 13 then
            result[#result + 1] = '\\r'
        elseif byte == 9 then
            result[#result + 1] = '\\t'
        elseif byte < 32 then
            result[#result + 1] = string.format('\\u%04x', byte)
        else
            result[#result + 1] = string.char(byte)
        end
    end
    result[#result + 1] = '"'
    return table.concat(result)
end

local function _jsonIsArray(value)
    local count, maximum = 0, 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false, 0
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    return count == maximum, maximum
end

-- Small deterministic JSON encoder.  It intentionally accepts only native
-- Lua values so it is safe to use at the registry boundary.
function cm2TelemetryJsonEncode(value)
    local valueType = type(value)
    if value == nil then return "null" end
    if valueType == "boolean" then return value and "true" or "false" end
    if valueType == "number" then
        local number = _number(value, 0.0)
        if number == math.floor(number) then return string.format("%.0f", number) end
        return string.format("%.6f", number):gsub("0+$", ""):gsub("%.$", "")
    end
    if valueType == "string" then return _jsonEscape(value) end
    if valueType ~= "table" then return "null" end

    local isArray, maximum = _jsonIsArray(value)
    local parts = {}
    if isArray then
        for index = 1, maximum do
            parts[#parts + 1] = cm2TelemetryJsonEncode(value[index])
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local keys = {}
    for key, _ in pairs(value) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = _jsonEscape(key) .. ":" ..
            cm2TelemetryJsonEncode(value[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- JSON decoder used only for event records copied through the registry.  The
-- parser is deliberately strict and has no side effects.
local function _jsonDecode(text)
    local position = 1
    local length = #text
    local jsonNull = {}

    local function skipWhitespace()
        while position <= length do
            local byte = string.byte(text, position)
            if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then break end
            position = position + 1
        end
    end

    local parseValue
    local function parseString()
        if string.sub(text, position, position) ~= '"' then return nil end
        position = position + 1
        local result = {}
        while position <= length do
            local byte = string.byte(text, position)
            if byte == 34 then
                position = position + 1
                return table.concat(result)
            end
            if byte == 92 then
                position = position + 1
                local escaped = string.sub(text, position, position)
                local replacements = {
                    ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
                    b = '\b', f = '\f', n = '\n', r = '\r', t = '\t',
                }
                if replacements[escaped] ~= nil then
                    result[#result + 1] = replacements[escaped]
                    position = position + 1
                elseif escaped == "u" then
                    local hex = string.sub(text, position + 1, position + 4)
                    local code = tonumber(hex, 16)
                    if code == nil then return nil end
                    result[#result + 1] = string.char(code < 128 and code or 63)
                    position = position + 5
                else
                    return nil
                end
            else
                result[#result + 1] = string.char(byte)
                position = position + 1
            end
        end
        return nil
    end

    local function parseNumber()
        local start = position
        while position <= length do
            local value = string.sub(text, position, position)
            if string.find("0123456789+-.eE", value, 1, true) == nil then break end
            position = position + 1
        end
        return tonumber(string.sub(text, start, position - 1))
    end

    local function parseArray()
        position = position + 1
        local result = {}
        skipWhitespace()
        if string.sub(text, position, position) == "]" then position = position + 1; return result end
        while position <= length do
            local value = parseValue()
            if value == nil then return nil end
            result[#result + 1] = value
            skipWhitespace()
            local delimiter = string.sub(text, position, position)
            if delimiter == "]" then position = position + 1; return result end
            if delimiter ~= "," then return nil end
            position = position + 1
            skipWhitespace()
        end
        return nil
    end

    local function parseObject()
        position = position + 1
        local result = {}
        skipWhitespace()
        if string.sub(text, position, position) == "}" then position = position + 1; return result end
        while position <= length do
            local key = parseString()
            if key == nil then return nil end
            skipWhitespace()
            if string.sub(text, position, position) ~= ":" then return nil end
            position = position + 1
            skipWhitespace()
            local value = parseValue()
            if value == nil then return nil end
            result[key] = value
            skipWhitespace()
            local delimiter = string.sub(text, position, position)
            if delimiter == "}" then position = position + 1; return result end
            if delimiter ~= "," then return nil end
            position = position + 1
            skipWhitespace()
        end
        return nil
    end

    parseValue = function()
        skipWhitespace()
        local head = string.sub(text, position, position)
        if head == '"' then return parseString() end
        if head == "{" then return parseObject() end
        if head == "[" then return parseArray() end
        if string.sub(text, position, position + 3) == "true" then position = position + 4; return true end
        if string.sub(text, position, position + 4) == "false" then position = position + 5; return false end
        if string.sub(text, position, position + 3) == "null" then position = position + 4; return jsonNull end
        return parseNumber()
    end

    local result = parseValue()
    skipWhitespace()
    if result == nil or position <= length then return nil end
    return result
end

local function _root()
    return telemetry.root
end

local function _shipRoot(body)
    return "StellarisShips/server/ships/byId/" .. tostring(body)
end

local function _newSession()
    local now = _integer((GetTime ~= nil) and GetTime() * 1000 or 0, 0)
    local randomPart = math.random(0, 2147483647)
    return string.format("%x-%x", now, randomPart)
end

local function _ensureRegistryHeader(forceNew)
    local root = _root()
    local existing = (GetString ~= nil) and GetString(root .. "/session") or ""
    if forceNew or existing == nil or existing == "" then
        if ClearKey ~= nil then ClearKey(root) end
        telemetry.session = _newSession()
        if SetString ~= nil then SetString(root .. "/protocol", telemetry.protocol, true) end
        if SetInt ~= nil then
            SetInt(root .. "/ring_size", telemetry.ringSize, true)
            SetInt(root .. "/next_seq", 0, true)
            SetInt(root .. "/latest_seq", 0, true)
        end
        if SetString ~= nil then SetString(root .. "/session", telemetry.session, true) end
    else
        telemetry.session = tostring(existing)
    end
end

function server.cm2TelemetryInit(forceNew)
    local registrySession = (GetString ~= nil) and GetString(_root() .. "/session") or ""
    if forceNew or not telemetry.serverInitialized then
        _ensureRegistryHeader(forceNew and true or false)
    elseif registrySession ~= nil and registrySession ~= ""
        and tostring(registrySession) ~= tostring(telemetry.session) then
        telemetry.session = tostring(registrySession)
    end
    telemetry.serverInitialized = true
    return telemetry.session
end

function client.cm2TelemetryInit()
    if telemetry.clientInitialized then return telemetry.session end
    local existing = (GetString ~= nil) and GetString(_root() .. "/session") or ""
    telemetry.session = tostring(existing or "")
    telemetry.lastRequest = ""
    telemetry.pendingRequest = nil
    telemetry.lastW = InputDown ~= nil and _boolean(InputDown("w")) or false
    telemetry.lastLmb = InputDown ~= nil and _boolean(InputDown("lmb")) or false
    telemetry.inputEdge = { w = false, lmb = false }
    telemetry.clientEventSeq = (GetInt ~= nil)
        and _integer(GetInt(_root() .. "/client_events/latest_seq"), 0) or 0
    telemetry.bridgeActive = false
    telemetry.bridgeFocus = false
    telemetry.bridgeText = ""
    telemetry.bridgeOpenedAt = 0.0
    telemetry.bridgeResponseAt = 0.0
    telemetry.clientInitialized = true
    return telemetry.session
end

local function _recordRegistryEvent(eventName, data)
    if GetInt == nil or SetInt == nil or SetString == nil then return 0 end
    if not telemetry.serverInitialized then server.cm2TelemetryInit(false) end
    local root = _root()
    local sequence = _integer(GetInt(root .. "/next_seq"), 0) + 1
    local event = {
        protocol = telemetry.protocol,
        session = telemetry.session,
        seq = sequence,
        at = _number((GetTime ~= nil) and GetTime() or 0.0, 0.0),
        type = tostring(eventName or "event"),
        data = type(data) == "table" and data or {},
    }
    local slot = ((sequence - 1) % telemetry.ringSize) + 1
    SetInt(root .. "/events/" .. tostring(slot) .. "/seq", sequence, true)
    SetString(root .. "/events/" .. tostring(slot) .. "/json", cm2TelemetryJsonEncode(event), true)
    SetInt(root .. "/next_seq", sequence, true)
    SetInt(root .. "/latest_seq", sequence, true)
    return sequence
end

function server.cm2TelemetryRecord(eventName, data)
    server.cm2TelemetryInit(false)
    return _recordRegistryEvent(eventName, data)
end

function client.cm2TelemetryRecord(eventName, data)
    if SetString == nil or SetInt == nil then return end
    local root = _root() .. "/client_events/"
    local registrySession = (GetString ~= nil) and GetString(_root() .. "/session") or ""
    if registrySession ~= nil and registrySession ~= "" then
        telemetry.session = tostring(registrySession)
    end
    telemetry.clientEventSeq = _integer(GetInt(root .. "latest_seq"), 0) + 1
    local event = {
        protocol = telemetry.protocol,
        session = telemetry.session,
        seq = telemetry.clientEventSeq,
        source = "client",
        at = _number((GetTime ~= nil) and GetTime() or 0.0, 0.0),
        type = tostring(eventName or "client_event"),
        data = type(data) == "table" and data or {},
    }
    local slot = ((telemetry.clientEventSeq - 1) % telemetry.ringSize) + 1
    SetString(root .. tostring(slot) .. "/json", cm2TelemetryJsonEncode(event), false)
    SetInt(root .. "latest_seq", telemetry.clientEventSeq, false)
    return telemetry.clientEventSeq
end

local function _recordClientInputEdge(wDown, lmbDown)
    return client.cm2TelemetryRecord("input_edge", {
        changed = {
            w = telemetry.inputEdge.w and true or false,
            lmb = telemetry.inputEdge.lmb and true or false,
        },
        down = {
            w = wDown and true or false,
            lmb = lmbDown and true or false,
        },
    })
end

local function _sampleInput()
    if InputDown == nil then return end
    local wDown = _boolean(InputDown("w"))
    local lmbDown = _boolean(InputDown("lmb"))
    if wDown ~= telemetry.lastW then telemetry.inputEdge.w = true end
    if lmbDown ~= telemetry.lastLmb then telemetry.inputEdge.lmb = true end
    if wDown ~= telemetry.lastW or lmbDown ~= telemetry.lastLmb then
        _recordClientInputEdge(wDown, lmbDown)
    end
    telemetry.lastW = wDown
    telemetry.lastLmb = lmbDown
end

local function _registryExists(body)
    return body ~= 0 and GetBool ~= nil and GetBool(_shipRoot(body) .. "/exists")
end

local function _writeDamageResult(nonce, result)
    local root = _root() .. "/damage/result/"
    SetBool(root .. "ok", result.ok and true or false, true)
    SetString(root .. "error", tostring(result.error or ""), true)
    SetInt(root .. "target_body_id", _integer(result.target_body_id, 0), true)
    SetFloat(root .. "requested_amount", _number(result.requested_amount, 0.0), true)
    SetFloat(root .. "applied_damage", _number(result.applied_damage, 0.0), true)
    SetFloat(root .. "before_shield", _number(result.before_shield, 0.0), true)
    SetFloat(root .. "before_armor", _number(result.before_armor, 0.0), true)
    SetFloat(root .. "before_body", _number(result.before_body, 0.0), true)
    SetFloat(root .. "after_shield", _number(result.after_shield, 0.0), true)
    SetFloat(root .. "after_armor", _number(result.after_armor, 0.0), true)
    SetFloat(root .. "after_body", _number(result.after_body, 0.0), true)
    SetString(root .. "impact_layer", tostring(result.impact_layer or "none"), true)
    SetString(root .. "nonce", tostring(nonce or ""), true)
end

local function _damageRequestError(nonce, target, amount, errorMessage)
    local result = {
        ok = false,
        error = errorMessage,
        target_body_id = target,
        requested_amount = amount,
    }
    _writeDamageResult(nonce, result)
    server.cm2TelemetryRecord("damage_probe_rejected", {
        nonce = nonce, target_body_id = target, amount = amount, error = errorMessage,
    })
    return false
end

-- This is the only public test RPC.  It queues a request in the registry; the
-- ship script that owns the target consumes it and calls shipDamageApplyRaw.
function server.cm2TelemetryDamageProbe(playerId, targetBodyId, amount, nonce)
    server.cm2TelemetryInit(false)
    local target = _integer(targetBodyId, 0)
    local damage = _number(amount, 0.0)
    local requestNonce = tostring(nonce or "")
    if requestNonce == "" then return _damageRequestError(requestNonce, target, damage, "nonce is required") end
    local requester = _integer(playerId, -1)
    if IsPlayerHost == nil or not IsPlayerHost(requester) then
        return _damageRequestError(requestNonce, target, damage, "only the host player may use the test RPC")
    end
    if target == 0 or not _registryExists(target) then return _damageRequestError(requestNonce, target, damage, "target body is not a registered ship") end
    if damage <= 0.0 or damage ~= damage or damage == math.huge or damage == -math.huge then
        return _damageRequestError(requestNonce, target, damage, "damage amount must be positive")
    end
    if damage > 10000000.0 then return _damageRequestError(requestNonce, target, damage, "damage amount exceeds test limit") end
    local targetRoot = _shipRoot(target)
    if GetBool(targetRoot .. "/destroyed") or GetFloat(targetRoot .. "/bodyHP") <= 0.0 then
        return _damageRequestError(requestNonce, target, damage, "target ship is already destroyed")
    end

    local root = _root() .. "/damage/request/"
    SetInt(root .. "target_body_id", target, true)
    SetFloat(root .. "amount", damage, true)
    SetFloat(root .. "requested_at", _number((GetTime ~= nil) and GetTime() or 0.0, 0.0), true)
    SetString(root .. "nonce", requestNonce, true)
    server.cm2TelemetryRecord("damage_probe_requested", {
        nonce = requestNonce, target_body_id = target, amount = damage,
    })
    return true
end

-- Called by every ship script once per server tick.  Only the script whose
-- current body matches the queued target may cross into the damage authority.
function server.cm2TelemetryServerTick(_dt)
    if GetString == nil then return end
    server.cm2TelemetryInit(false)
    local requestRoot = _root() .. "/damage/request/"
    local requestNonce = tostring(GetString(requestRoot .. "nonce") or "")
    if requestNonce == "" then return end
    local target = _integer(GetInt(requestRoot .. "target_body_id"), 0)
    local amount = _number(GetFloat(requestRoot .. "amount"), 0.0)
    local ownBody = 0
    if server.shipContextGetBody ~= nil then ownBody = _integer(server.shipContextGetBody(), 0) end
    if ownBody ~= target then
        -- The level host script also calls this function.  It is the timeout
        -- owner for a stale target that has no live ship authority.
        if ownBody == 0 then
            local requestedAt = _number(GetFloat(requestRoot .. "requested_at"), 0.0)
            local now = _number((GetTime ~= nil) and GetTime() or requestedAt, requestedAt)
            if now - requestedAt > 1.5 then
                SetString(requestRoot .. "nonce", "", true)
                _writeDamageResult(requestNonce, {
                    ok = false, error = "target ship authority did not respond",
                    target_body_id = target, requested_amount = amount,
                })
            end
        end
        return
    end

    SetString(requestRoot .. "nonce", "", true)
    local targetRoot = _shipRoot(target)
    if not _registryExists(target) then
        return _damageRequestError(requestNonce, target, amount, "target body was unregistered")
    end
    if GetBool(targetRoot .. "/destroyed") or GetFloat(targetRoot .. "/bodyHP") <= 0.0 then
        return _damageRequestError(requestNonce, target, amount, "target ship is already destroyed")
    end
    if server.shipDamageApplyRaw == nil then
        return _damageRequestError(requestNonce, target, amount, "ship damage authority is unavailable")
    end

    local beforeShield = GetFloat(targetRoot .. "/shieldHP")
    local beforeArmor = GetFloat(targetRoot .. "/armorHP")
    local beforeBody = GetFloat(targetRoot .. "/bodyHP")
    local damageResult = server.shipDamageApplyRaw(target, amount) or {}
    local afterShield = GetFloat(targetRoot .. "/shieldHP")
    local afterArmor = GetFloat(targetRoot .. "/armorHP")
    local afterBody = GetFloat(targetRoot .. "/bodyHP")
    local result = {
        ok = true,
        target_body_id = target,
        requested_amount = amount,
        applied_damage = _number(damageResult.appliedDamage, 0.0),
        before_shield = beforeShield,
        before_armor = beforeArmor,
        before_body = beforeBody,
        after_shield = afterShield,
        after_armor = afterArmor,
        after_body = afterBody,
        impact_layer = tostring(damageResult.impactLayer or "none"),
    }
    _writeDamageResult(requestNonce, result)
    server.cm2TelemetryRecord("damage_probe_result", result)
end

local function _transformSnapshot(body)
    local transform = nil
    if body ~= 0 and IsHandleValid ~= nil and IsHandleValid(body) and GetBodyTransform ~= nil then
        transform = GetBodyTransform(body)
    end
    transform = transform or Transform()
    return {
        position = _vec(transform.pos),
        rotation = _quat(transform.rot),
    }
end

local function _shipSnapshot(body)
    local prefix = _shipRoot(body)
    local transform = _transformSnapshot(body)
    local velocity, angularVelocity = Vec(0, 0, 0), Vec(0, 0, 0)
    if body ~= 0 and IsHandleValid ~= nil and IsHandleValid(body) then
        if GetBodyVelocity ~= nil then velocity = GetBodyVelocity(body) end
        if GetBodyAngularVelocity ~= nil then angularVelocity = GetBodyAngularVelocity(body) end
    end
    return {
        body_id = body,
        ship_type = GetString(prefix .. "/shipType"),
        interceptor_class = GetString(prefix .. "/interceptorClass"),
        owner_body_id = GetInt(prefix .. "/ownerBody"),
        position = transform.position,
        rotation = transform.rotation,
        linear_velocity = _vec(velocity),
        angular_velocity = _vec(angularVelocity),
        shield_hp = _number(GetFloat(prefix .. "/shieldHP"), 0.0),
        armor_hp = _number(GetFloat(prefix .. "/armorHP"), 0.0),
        body_hp = _number(GetFloat(prefix .. "/bodyHP"), 0.0),
        max_shield_hp = _number(GetFloat(prefix .. "/maxShieldHP"), 0.0),
        max_armor_hp = _number(GetFloat(prefix .. "/maxArmorHP"), 0.0),
        max_body_hp = _number(GetFloat(prefix .. "/maxBodyHP"), 0.0),
        destroyed = _boolean(GetBool(prefix .. "/destroyed")) or
            _number(GetFloat(prefix .. "/bodyHP"), 0.0) <= 0.0,
        registered = _boolean(GetBool(prefix .. "/exists")),
    }
end

local function _snapshot(maxShips)
    local playerId = _integer((GetLocalPlayer ~= nil) and GetLocalPlayer() or 0, 0)
    local vehicleId = _integer((GetPlayerVehicle ~= nil) and GetPlayerVehicle(playerId) or 0, 0)
    local playerBodyId = 0
    if vehicleId ~= 0 and GetVehicleBody ~= nil then playerBodyId = _integer(GetVehicleBody(vehicleId), 0) end
    local playerTransform = (GetPlayerTransform ~= nil) and GetPlayerTransform(playerId) or Transform()
    local playerVelocity = (GetPlayerVelocity ~= nil) and GetPlayerVelocity(playerId) or Vec(0, 0, 0)
    local camera = (GetCameraTransform ~= nil) and GetCameraTransform() or Transform()
    local ships = {}
    local shipIndexRoot = "StellarisShips/server/ships/index"
    local count = math.max(0, _integer(GetInt(shipIndexRoot .. "/count"), 0))
    local limit = math.min(maxShips or telemetry.maxShips, count)
    for index = 1, limit do
        local body = _integer(GetInt(shipIndexRoot .. "/" .. tostring(index) .. "/bodyId"), 0)
        if body ~= 0 and GetBool(_shipRoot(body) .. "/exists") then
            ships[#ships + 1] = _shipSnapshot(body)
        end
    end
    return {
        scenario = {
            id = GetString("StellarisShips/testing/scenario/id"),
            xml_revision = GetString("StellarisShips/testing/scenario/xmlRevision"),
            lua_revision = GetString("StellarisShips/testing/scenario/luaRevision"),
            ready = _boolean(GetBool("StellarisShips/testing/scenario/ready")),
        },
        player = {
            id = playerId,
            health = _number((GetPlayerHealth ~= nil) and GetPlayerHealth(playerId) or 0.0, 0.0),
            vehicle_id = vehicleId,
            body_id = playerBodyId,
            transform = { position = _vec(playerTransform.pos), rotation = _quat(playerTransform.rot) },
            velocity = _vec(playerVelocity),
        },
        camera = { position = _vec(camera.pos), rotation = _quat(camera.rot) },
        input = {
            down = { w = telemetry.lastW, lmb = telemetry.lastLmb },
            edge = { w = telemetry.inputEdge.w, lmb = telemetry.inputEdge.lmb },
            client_event_seq = telemetry.clientEventSeq,
        },
        ships = ships,
    }
end

local function _readServerEvents(afterSequence)
    local root = _root()
    local latest = math.max(0, _integer(GetInt(root .. "/latest_seq"), 0))
    local oldest = math.max(1, latest - telemetry.ringSize + 1)
    local after = math.max(0, _integer(afterSequence, 0))
    local truncated = after < oldest - 1
    local events = {}
    local start = math.max(after + 1, oldest)
    for sequence = start, latest do
        local slot = ((sequence - 1) % telemetry.ringSize) + 1
        local slotRoot = root .. "/events/" .. tostring(slot)
        if _integer(GetInt(slotRoot .. "/seq"), 0) == sequence then
            local decoded = _jsonDecode(GetString(slotRoot .. "/json"))
            if decoded ~= nil then events[#events + 1] = decoded end
        end
    end
    return events, latest, oldest, truncated
end

local function _readClientEvents(afterSequence)
    local root = _root() .. "/client_events/"
    local latest = math.max(0, _integer(GetInt(root .. "latest_seq"), 0))
    local oldest = math.max(1, latest - telemetry.ringSize + 1)
    local events = {}
    local after = math.max(0, _integer(afterSequence, 0))
    for sequence = math.max(oldest, after + 1), latest do
        local slot = ((sequence - 1) % telemetry.ringSize) + 1
        local decoded = _jsonDecode(GetString(root .. tostring(slot) .. "/json"))
        if decoded ~= nil then events[#events + 1] = decoded end
    end
    return events, latest
end

local function _parseRequest(text)
    local prefix = telemetry.protocol .. "|request|"
    if type(text) ~= "string" or string.sub(text, 1, #prefix) ~= prefix then return nil end
    local request = {}
    for field in string.gmatch(string.sub(text, #prefix + 1), "[^|]+") do
        local key, value = string.match(field, "^([^=]+)=(.*)$")
        if key ~= nil then request[key] = value end
    end
    if tostring(request.nonce or "") == "" or tostring(request.command or "") == "" then return nil end
    request.after_seq = _integer(request.after_seq, 0)
    request.client_after_seq = _integer(request.client_after_seq, 0)
    request.target_body_id = _integer(request.target_body_id, 0)
    request.amount = _number(request.amount, 0.0)
    return request
end

local function _damageResultForNonce(nonce)
    local root = _root() .. "/damage/result/"
    if tostring(GetString(root .. "nonce") or "") ~= tostring(nonce or "") then return nil end
    return {
        ok = _boolean(GetBool(root .. "ok")),
        error = tostring(GetString(root .. "error") or ""),
        target_body_id = _integer(GetInt(root .. "target_body_id"), 0),
        requested_amount = _number(GetFloat(root .. "requested_amount"), 0.0),
        applied_damage = _number(GetFloat(root .. "applied_damage"), 0.0),
        before_shield = _number(GetFloat(root .. "before_shield"), 0.0),
        before_armor = _number(GetFloat(root .. "before_armor"), 0.0),
        before_body = _number(GetFloat(root .. "before_body"), 0.0),
        after_shield = _number(GetFloat(root .. "after_shield"), 0.0),
        after_armor = _number(GetFloat(root .. "after_armor"), 0.0),
        after_body = _number(GetFloat(root .. "after_body"), 0.0),
        impact_layer = tostring(GetString(root .. "impact_layer") or "none"),
    }
end

local function _response(request, damageResult)
    local serverEvents, latest, oldest, truncated = _readServerEvents(request.after_seq)
    local clientEvents, clientLatest = _readClientEvents(request.client_after_seq)
    local shipsLimit = telemetry.maxShips
    local eventLimit = telemetry.maxEvents
    local events = {}
    local clientBudget = math.min(#clientEvents, eventLimit)
    local serverBudget = math.max(0, eventLimit - clientBudget)
    for index = 1, clientBudget do events[#events + 1] = clientEvents[index] end
    for index = 1, math.min(#serverEvents, serverBudget) do
        events[#events + 1] = serverEvents[index]
    end
    if #clientEvents > clientBudget or #serverEvents > serverBudget then truncated = true end
    local function continuationFor(eventList, source, fallback)
        for index = #eventList, 1, -1 do
            local event = eventList[index]
            if type(event) == "table"
                and tostring(event.source or "server") == source then
                return _integer(event.seq, fallback)
            end
        end
        return fallback
    end
    local continuation = continuationFor(events, "server", request.after_seq)
    local clientContinuation = continuationFor(events, "client", request.client_after_seq)
    local payload = {
        protocol = telemetry.protocol,
        type = "response",
        nonce = request.nonce,
        command = request.command,
        session = telemetry.session,
        ok = true,
        latest_seq = latest,
        oldest_seq = oldest,
        next_after_seq = continuation,
        client_latest_seq = clientLatest,
        client_next_after_seq = clientContinuation,
        truncated = truncated,
        snapshot = _snapshot(shipsLimit),
        events = events,
    }
    if damageResult ~= nil then payload.damage = damageResult; payload.ok = damageResult.ok end
    local encoded = telemetry.protocol .. "|response=" .. cm2TelemetryJsonEncode(payload)
    while #encoded > telemetry.maxResponseBytes and #payload.events > 0 do
        table.remove(payload.events)
        payload.truncated = true
        payload.next_after_seq = continuationFor(payload.events, "server", request.after_seq)
        payload.client_next_after_seq = continuationFor(
            payload.events, "client", request.client_after_seq
        )
        encoded = telemetry.protocol .. "|response=" .. cm2TelemetryJsonEncode(payload)
    end
    payload.next_after_seq = continuationFor(payload.events, "server", request.after_seq)
    payload.client_next_after_seq = continuationFor(
        payload.events, "client", request.client_after_seq
    )
    while #encoded > telemetry.maxResponseBytes and #payload.snapshot.ships > 0 do
        table.remove(payload.snapshot.ships)
        payload.truncated = true
        encoded = telemetry.protocol .. "|response=" .. cm2TelemetryJsonEncode(payload)
    end
    if #encoded > telemetry.maxResponseBytes then
        payload.snapshot.ships = {}
        payload.events = {}
        payload.truncated = true
        payload.error = "response exceeds 48KB limit"
        encoded = telemetry.protocol .. "|response=" .. cm2TelemetryJsonEncode(payload)
    end
    telemetry.inputEdge = { w = false, lmb = false }
    return encoded
end

local function _handleRequest(request, raw)
    if request.command == "damage" then
        if ServerCall == nil then
            return _response(request, { ok = false, error = "ServerCall is unavailable" })
        end
        -- ServerCall can only invoke a server function that belongs to the
        -- issuing script instance. The level bridge therefore publishes a
        -- local dispatch record; the target ship's client tick issues the RPC
        -- to the matching ship-script server authority.
        telemetry.pendingRequest = { request = request, raw = raw }
        local dispatchRoot = _root() .. "/damage/client_dispatch/"
        SetInt(dispatchRoot .. "target_body_id", request.target_body_id, false)
        SetFloat(dispatchRoot .. "amount", request.amount, false)
        SetInt(
            dispatchRoot .. "player_id",
            _integer((GetLocalPlayer ~= nil) and GetLocalPlayer() or 0, 0),
            false
        )
        SetString(dispatchRoot .. "nonce", request.nonce, false)
        return nil
    end
    if request.command == "probe" and DebugPrint ~= nil then
        DebugPrint(
            telemetry.protocol .. "|log_probe|nonce=" .. tostring(request.nonce) ..
            "|session=" .. tostring(telemetry.session)
        )
    end
    if request.command ~= "read" and request.command ~= "probe" then
        return _response(request, { ok = false, error = "unknown telemetry command" })
    end
    return _response(request, nil)
end

local function _closeBridge()
    telemetry.bridgeActive = false
    telemetry.bridgeFocus = false
    telemetry.bridgeText = ""
    telemetry.bridgeOpenedAt = 0.0
    telemetry.bridgeResponseAt = 0.0
    telemetry.pendingRequest = nil
end

local function _updatePendingDamageResponse()
    if telemetry.pendingRequest == nil then return end
    local pending = telemetry.pendingRequest
    local result = _damageResultForNonce(pending.request.nonce)
    if result == nil then return end
    telemetry.bridgeText = _response(pending.request, result)
    telemetry.bridgeResponseAt = _number((GetTime ~= nil) and GetTime() or 0.0, 0.0)
    telemetry.lastRequest = pending.raw
    telemetry.pendingRequest = nil
end

function client.cm2TelemetryTick(_dt)
    if not telemetry.clientInitialized then client.cm2TelemetryInit() end
    local registrySession = (GetString ~= nil) and GetString(_root() .. "/session") or ""
    if registrySession ~= nil and registrySession ~= ""
        and tostring(registrySession) ~= tostring(telemetry.session) then
        telemetry.session = tostring(registrySession)
        telemetry.lastRequest = ""
        telemetry.inputEdge = { w = false, lmb = false }
        telemetry.clientEventSeq = 0
    end
    _sampleInput()

    local dispatchRoot = _root() .. "/damage/client_dispatch/"
    local dispatchNonce = tostring(GetString(dispatchRoot .. "nonce") or "")
    local dispatchTarget = _integer(GetInt(dispatchRoot .. "target_body_id"), 0)
    local ownBody = (client.shipContextGetBody ~= nil)
        and _integer(client.shipContextGetBody(), 0) or 0
    if dispatchNonce ~= "" and ownBody ~= 0 and ownBody == dispatchTarget
        and GetString(dispatchRoot .. "dispatched_nonce") ~= dispatchNonce then
        SetString(dispatchRoot .. "dispatched_nonce", dispatchNonce, false)
        client.cm2TelemetryRecord("damage_dispatch_attempted", {
            target_body_id = dispatchTarget,
            amount = _number(GetFloat(dispatchRoot .. "amount"), 0.0),
            player_id = _integer(GetInt(dispatchRoot .. "player_id"), 0),
        })
        local ok = pcall(
            ServerCall,
            "server.cm2TelemetryDamageProbe",
            _integer(GetInt(dispatchRoot .. "player_id"), 0),
            dispatchTarget,
            _number(GetFloat(dispatchRoot .. "amount"), 0.0),
            dispatchNonce
        )
        if not ok and telemetry.pendingRequest ~= nil then
            local pending = telemetry.pendingRequest
            telemetry.bridgeText = _response(
                pending.request,
                { ok = false, error = "damage RPC dispatch failed" }
            )
            telemetry.lastRequest = pending.raw
            telemetry.pendingRequest = nil
        end
    end

    if InputPressed ~= nil and InputPressed("f8") then
        if telemetry.bridgeActive then
            _closeBridge()
        else
            telemetry.bridgeActive = true
            telemetry.bridgeFocus = true
            telemetry.bridgeText = ""
            telemetry.bridgeOpenedAt = _number((GetTime ~= nil) and GetTime() or 0.0, 0.0)
        end
    end

    if not telemetry.bridgeActive then return end
    local now = _number((GetTime ~= nil) and GetTime() or telemetry.bridgeOpenedAt, telemetry.bridgeOpenedAt)
    if telemetry.bridgeResponseAt > 0.0
        and now - telemetry.bridgeResponseAt >= telemetry.bridgeResponseCloseDelay then
        _closeBridge()
        return
    end
    if now - telemetry.bridgeOpenedAt > telemetry.bridgeTimeout then
        _closeBridge()
        return
    end
    _updatePendingDamageResponse()
end

function client.cm2TelemetryDraw()
    if not telemetry.bridgeActive or UiTextInput == nil or UiMakeInteractive == nil then return end
    UiPush()
        UiMakeInteractive()
        local width = math.max(64, UiWidth() - 80)
        UiTranslate(40, 20)
        UiColor(0.0, 0.0, 0.0, 0.92)
        UiRect(width, 52)
        UiTranslate(8, 6)
        UiColor(1.0, 1.0, 1.0, 1.0)
        UiFont("regular.ttf", 18)
        telemetry.bridgeText = UiTextInput(
            telemetry.bridgeText,
            width - 16,
            40,
            telemetry.bridgeFocus,
            true
        )
        telemetry.bridgeFocus = false
    UiPop()

    if telemetry.pendingRequest ~= nil then return end
    local raw = tostring(telemetry.bridgeText or "")
    local request = _parseRequest(raw)
    if request == nil or raw == telemetry.lastRequest then return end
    local response = _handleRequest(request, raw)
    if response ~= nil then
        telemetry.bridgeText = response
        telemetry.bridgeResponseAt = _number((GetTime ~= nil) and GetTime() or 0.0, 0.0)
        telemetry.lastRequest = raw
    end
end

function client.cm2TelemetryRead(afterSequence)
    local request = {
        protocol = telemetry.protocol,
        type = "response",
        nonce = "local",
        command = "read",
        session = telemetry.session,
        ok = true,
        latest_seq = _integer(GetInt(_root() .. "/latest_seq"), 0),
        after_seq = _integer(afterSequence, 0),
        snapshot = _snapshot(telemetry.maxShips),
    }
    local events = _readServerEvents(request.after_seq)
    request.events = events
    return request
end

-- Compatibility names retained for older local smoke scripts.  They now map
-- to the versioned protocol and do not emit periodic AI_TEST heartbeats.
function client.aiAgentTelemetryInit()
    return client.cm2TelemetryInit()
end

function client.aiAgentTelemetryTick(dt)
    return client.cm2TelemetryTick(dt)
end

function client.aiAgentTelemetryDraw()
    return client.cm2TelemetryDraw()
end
