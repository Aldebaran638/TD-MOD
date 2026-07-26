---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.netSyncState = server.netSyncState or {
    channels = {},
}

function server.netSyncQuantize(value, step)
    local number = tonumber(value) or 0.0
    local quantum = math.max(0.000001, tonumber(step) or 1.0)
    return math.floor(number / quantum + 0.5) * quantum
end

function server.netSyncShouldSend(channelKey, interval, signature, force)
    local key = tostring(channelKey or "")
    if key == "" then return false end

    local now = (GetTime ~= nil) and GetTime() or 0.0
    local channel = server.netSyncState.channels[key]
    if channel == nil then
        channel = {
            lastSentAt = -1000.0,
            lastSignature = "",
            sendCount = 0,
        }
        server.netSyncState.channels[key] = channel
    end

    if force then return true end
    local minimumInterval = math.max(0.0, tonumber(interval) or 0.0)
    if now - (channel.lastSentAt or -1000.0) < minimumInterval then
        return false
    end
    return tostring(signature or "") ~= tostring(channel.lastSignature or "")
end

function server.netSyncMarkSent(channelKey, signature)
    local key = tostring(channelKey or "")
    if key == "" then return end

    local channel = server.netSyncState.channels[key] or {}
    channel.lastSentAt = (GetTime ~= nil) and GetTime() or 0.0
    channel.lastSignature = tostring(signature or "")
    channel.sendCount = math.floor(channel.sendCount or 0) + 1
    server.netSyncState.channels[key] = channel
end

function server.netSyncGetChannel(channelKey)
    return server.netSyncState.channels[tostring(channelKey or "")]
end

function server.netSyncClearPrefix(prefix)
    local requestedPrefix = tostring(prefix or "")
    for key, _ in pairs(server.netSyncState.channels) do
        if requestedPrefix == "" or string.sub(key, 1, #requestedPrefix) == requestedPrefix then
            server.netSyncState.channels[key] = nil
        end
    end
end

