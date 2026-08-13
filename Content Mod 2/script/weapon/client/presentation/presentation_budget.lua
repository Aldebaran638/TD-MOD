---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Single presentation budget facade. Only this module and the legacy budget
-- implementation may call the corresponding Teardown drawing/audio primitives.
client = client or {}
client.presentationBudget = client.presentationBudget or {}
local budget = client.presentationBudget

budget.state = budget.state or {
    frame = 0,
    beginCount = 0,
    requests = 0,
    accepted = 0,
    degraded = 0,
    rejected = 0,
    voices = 0,
    maxVoices = 64,
    byKind = {},
}

local function _record(kind, result, metadata)
    local state = budget.state
    local key = tostring(kind or "unknown")
    local item = state.byKind[key] or { requested = 0, accepted = 0, degraded = 0, rejected = 0 }
    item.requested = item.requested + 1
    state.requests = state.requests + 1
    if result == "accepted" then
        item.accepted = item.accepted + 1
        state.accepted = state.accepted + 1
    elseif result == "degraded" then
        item.degraded = item.degraded + 1
        state.degraded = state.degraded + 1
    else
        item.rejected = item.rejected + 1
        state.rejected = state.rejected + 1
    end
    state.byKind[key] = item
    return result == "accepted"
end

function budget.beginFrame(dt)
    budget.state.frame = budget.state.frame + 1
    budget.state.beginCount = budget.state.beginCount + 1
    client.weaponFxBudgetBeginFrame(dt)
end

function budget.spawnParticle(position, velocity, life, metadata)
    local meta = metadata or {}
    local priority = tostring(meta.priority or "normal")
    local count = tonumber(meta.count) or 1
    if meta.alreadyBudgeted ~= true and not client.weaponFxTakeParticles(count, priority) then
        _record("particle", "rejected", meta)
        return false
    end
    _record("particle", "accepted", meta)
    SpawnParticle(position, velocity, life)
    return true
end

function budget.pointLight(position, r, g, b, intensity, maxDistance, metadata)
    local meta = metadata or {}
    local priority = tostring(meta.priority or "normal")
    if not client.weaponFxPointLight(position, r, g, b, intensity, maxDistance, priority) then
        _record("pointLight", "rejected", meta)
        return false
    end
    _record("pointLight", "accepted", meta)
    return true
end

function budget.sprite(sprite, transform, width, height, r, g, b, a, additive, billboard, depthTest, metadata)
    local meta = metadata or {}
    if not client.weaponFxTakeSprite(1, tostring(meta.priority or "normal")) then
        _record("sprite", "rejected", meta)
        return false
    end
    _record("sprite", "accepted", meta)
    DrawSprite(sprite, transform, width, height, r, g, b, a, additive, billboard, depthTest)
    return true
end

function budget.line(startPoint, endPoint, r, g, b, a, metadata)
    local meta = metadata or {}
    if not client.weaponFxTakeLine(1) then
        _record("line", "rejected", meta)
        return false
    end
    _record("line", "accepted", meta)
    DrawLine(startPoint, endPoint, r, g, b, a)
    return true
end

function budget.playSound(handle, position, volume, metadata)
    local state = budget.state
    local meta = metadata or {}
    if state.voices >= state.maxVoices then
        _record("audio", "degraded", meta)
        return false
    end
    state.voices = state.voices + 1
    _record("audio", "accepted", meta)
    if handle ~= nil and handle ~= 0 then PlaySound(handle, position, volume or 1.0) end
    return true
end

function budget.requestShake(metadata)
    local meta = metadata or {}
    return _record("shake", "accepted", meta)
end

function budget.getDiagnostics()
    local state = budget.state
    return {
        frame = state.frame,
        beginCount = state.beginCount,
        requests = state.requests,
        accepted = state.accepted,
        degraded = state.degraded,
        rejected = state.rejected,
        voices = state.voices,
        byKind = state.byKind,
    }
end
