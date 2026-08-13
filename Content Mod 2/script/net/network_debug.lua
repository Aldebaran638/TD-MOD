---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.networkDebugConfig = server.networkDebugConfig or {
    enabled = false,
    logInterval = 1.0,
    diagnosticsEnabled = false,
}

server.networkStats = server.networkStats or {
    secondStart = 0.0,
    serverCallsReceived = 0,
    clientCallsSent = 0,
    byChannel = {},
    activeMissiles = 0,
    activeProjectiles = 0,
    activeCrafts = 0,
    raycastsThisSecond = 0,
    explosionsThisSecond = 0,
    activeEffects = 0,
    activeVoices = 0,
    activeJoints = 0,
    counters = {},
    timings = {},
    recentTotals = {},
    recentAverage = 0.0,
    peakCallsPerSecond = 0,
}

local function _netDebugCounterValue(value)
    return math.max(0, math.floor(tonumber(value) or 0))
end

function server.netDebugCount(name, count)
    if not server.networkDebugConfig.diagnosticsEnabled then return end
    local key = tostring(name or "unknown")
    local counters = server.networkStats.counters
    counters[key] = _netDebugCounterValue(counters[key]) + _netDebugCounterValue(count or 1)
end

function server.netDebugMeasure(name, milliseconds)
    if not server.networkDebugConfig.diagnosticsEnabled then return end
    local key = tostring(name or "unknown")
    local timings = server.networkStats.timings
    local timing = timings[key] or { samples = 0, totalMs = 0.0, peakMs = 0.0 }
    local value = math.max(0.0, tonumber(milliseconds) or 0.0)
    timing.samples = _netDebugCounterValue(timing.samples) + 1
    timing.totalMs = (tonumber(timing.totalMs) or 0.0) + value
    timing.peakMs = math.max(tonumber(timing.peakMs) or 0.0, value)
    timings[key] = timing
end

local function _netDebugIncrementChannel(channel)
    local key = tostring(channel or "unknown")
    local byChannel = server.networkStats.byChannel
    byChannel[key] = math.floor(byChannel[key] or 0) + 1
end

function server.netDebugCountReceive(channel)
    server.networkStats.serverCallsReceived =
        math.floor(server.networkStats.serverCallsReceived or 0) + 1
    _netDebugIncrementChannel(channel)
end

function server.netDebugCountRaycast(count)
    server.networkStats.raycastsThisSecond =
        math.floor(server.networkStats.raycastsThisSecond or 0)
        + math.max(1, math.floor(count or 1))
end

function server.netDebugCountExplosion(count)
    server.networkStats.explosionsThisSecond =
        math.floor(server.networkStats.explosionsThisSecond or 0)
        + math.max(1, math.floor(count or 1))
end

function server.netDebugSetEntityCounts(missiles, projectiles, crafts)
    if missiles ~= nil then
        server.networkStats.activeMissiles = math.max(0, math.floor(missiles or 0))
    end
    if projectiles ~= nil then
        server.networkStats.activeProjectiles = math.max(0, math.floor(projectiles or 0))
    end
    if crafts ~= nil then
        server.networkStats.activeCrafts = math.max(0, math.floor(crafts or 0))
    end
end

function server.netDebugSetRuntimeCounts(effects, voices, joints)
    if effects ~= nil then
        server.networkStats.activeEffects = _netDebugCounterValue(effects)
    end
    if voices ~= nil then
        server.networkStats.activeVoices = _netDebugCounterValue(voices)
    end
    if joints ~= nil then
        server.networkStats.activeJoints = _netDebugCounterValue(joints)
    end
end

function server.netDebugSnapshot()
    return {
        counters = server.networkStats.counters,
        timings = server.networkStats.timings,
        activeMissiles = server.networkStats.activeMissiles,
        activeProjectiles = server.networkStats.activeProjectiles,
        activeCrafts = server.networkStats.activeCrafts,
        activeEffects = server.networkStats.activeEffects,
        activeVoices = server.networkStats.activeVoices,
        activeJoints = server.networkStats.activeJoints,
    }
end

function server.netClientCall(channel, playerId, callback, ...)
    server.networkStats.clientCallsSent =
        math.floor(server.networkStats.clientCallsSent or 0) + 1
    _netDebugIncrementChannel(channel)
    ClientCall(playerId, callback, ...)
end

function server.netResolveShipDriver(shipBody)
    local body = math.floor(shipBody or 0)
    if body == 0 or server.shipRuntimeGetDriverPlayerId == nil then return 0 end
    local playerId = math.floor(server.shipRuntimeGetDriverPlayerId(body) or 0)
    if playerId <= 0 then return 0 end
    if IsPlayerValid ~= nil and not IsPlayerValid(playerId) then return 0 end
    local vehicle = GetPlayerVehicle(playerId)
    if vehicle == nil or vehicle == 0 or GetVehicleBody(vehicle) ~= body then
        if server.shipRuntimeSetDriverPlayerId ~= nil then
            server.shipRuntimeSetDriverPlayerId(body, 0)
        end
        return 0
    end
    return playerId
end

local function _netDebugPushRecent(total)
    local recent = server.networkStats.recentTotals
    recent[#recent + 1] = total
    while #recent > 10 do
        table.remove(recent, 1)
    end

    local sum = 0
    for i = 1, #recent do
        sum = sum + recent[i]
    end
    server.networkStats.recentAverage = (#recent > 0) and (sum / #recent) or 0.0
    server.networkStats.peakCallsPerSecond = math.max(
        math.floor(server.networkStats.peakCallsPerSecond or 0),
        total
    )
end

function server.networkDebugTick(dt)
    local _ = dt
    local now = (GetTime ~= nil) and GetTime() or 0.0
    local interval = math.max(
        0.25,
        tonumber(server.networkDebugConfig.logInterval) or 1.0
    )
    if now - (server.networkStats.secondStart or 0.0) < interval then return end

    local total = math.floor(server.networkStats.serverCallsReceived or 0)
        + math.floor(server.networkStats.clientCallsSent or 0)
    _netDebugPushRecent(total)

    if server.networkDebugConfig.enabled and DebugPrint ~= nil then
        DebugPrint(string.format(
            "[CM2 NET] RPC/s=%d recv=%d sent=%d avg10=%.1f peak=%d missiles=%d projectiles=%d crafts=%d effects=%d voices=%d joints=%d raycasts=%d explosions=%d",
            total,
            server.networkStats.serverCallsReceived or 0,
            server.networkStats.clientCallsSent or 0,
            server.networkStats.recentAverage or 0.0,
            server.networkStats.peakCallsPerSecond or 0,
            server.networkStats.activeMissiles or 0,
            server.networkStats.activeProjectiles or 0,
            server.networkStats.activeCrafts or 0,
            server.networkStats.activeEffects or 0,
            server.networkStats.activeVoices or 0,
            server.networkStats.activeJoints or 0,
            server.networkStats.raycastsThisSecond or 0,
            server.networkStats.explosionsThisSecond or 0
        ))
    end

    server.networkStats.secondStart = now
    server.networkStats.serverCallsReceived = 0
    server.networkStats.clientCallsSent = 0
    server.networkStats.byChannel = {}
    server.networkStats.raycastsThisSecond = 0
    server.networkStats.explosionsThisSecond = 0
    if server.networkDebugConfig.diagnosticsEnabled then
        server.networkStats.counters = {}
        server.networkStats.timings = {}
    end
end

