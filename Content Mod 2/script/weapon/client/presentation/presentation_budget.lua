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
    beginOwner = "",
    duplicateBeginCount = 0,
    requests = 0,
    accepted = 0,
    degraded = 0,
    rejected = 0,
    voices = 0,
    maxVoices = 64,
    shakes = 0,
    maxShakes = 8,
    byKind = {},
    byMetadata = {},
}

local function _record(kind, result, metadata)
    local state = budget.state
    local meta = metadata or {}
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
    local metadataKey = table.concat({
        tostring(meta.effect or "unknown"),
        tostring(meta.package or "unknown"),
        tostring(meta.owner or "unknown"),
        tostring(meta.priority or "normal"),
        tostring(meta.distance or "unknown"),
    }, "|")
    local metadataItem = state.byMetadata[metadataKey]
    if metadataItem == nil then
        metadataItem = {
            effect = tostring(meta.effect or "unknown"),
            package = tostring(meta.package or "unknown"),
            owner = tostring(meta.owner or "unknown"),
            priority = tostring(meta.priority or "normal"),
            distance = tostring(meta.distance or "unknown"),
            requested = 0,
            accepted = 0,
            degraded = 0,
            rejected = 0,
        }
        state.byMetadata[metadataKey] = metadataItem
    end
    metadataItem.requested = metadataItem.requested + 1
    metadataItem[result] = metadataItem[result] + 1
    return result == "accepted"
end

function budget.beginFrame(dt, owner, frameToken)
    local state = budget.state
    if frameToken ~= nil and state.lastFrameToken == frameToken then
        state.duplicateBeginCount = state.duplicateBeginCount + 1
        return false
    end
    state.lastFrameToken = frameToken
    state.frame = state.frame + 1
    budget.state.beginCount = budget.state.beginCount + 1
    state.beginOwner = tostring(owner or "unknown")
    state.voices = 0
    state.shakes = 0
    client.weaponFxBudgetBeginFrame(dt)
    return true
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
    if not client.weaponFxTakeLine(1, tostring(meta.priority or "normal")) then
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
    if handle == nil or handle == 0 then
        _record("audio", "rejected", meta)
        return false
    end
    state.voices = state.voices + 1
    _record("audio", "accepted", meta)
    PlaySound(handle, position, volume or 1.0)
    return true
end

function budget.requestShake(metadata)
    local state = budget.state
    local meta = metadata or {}
    if state.shakes >= state.maxShakes then
        _record("shake", "degraded", meta)
        return false
    end
    state.shakes = state.shakes + 1
    return _record("shake", "accepted", meta)
end

function budget.sceneReload()
    local state = budget.state
    if state.telemetryRoot ~= nil and state.telemetrySource ~= nil and ClearKey ~= nil then
        ClearKey(state.telemetryRoot .. tostring(state.telemetrySource))
    end
    state.frame = 0
    state.beginCount = 0
    state.beginOwner = ""
    state.lastFrameToken = nil
    state.duplicateBeginCount = 0
    state.requests = 0
    state.accepted = 0
    state.degraded = 0
    state.rejected = 0
    state.voices = 0
    state.shakes = 0
    state.byKind = {}
    state.byMetadata = {}
end

function budget.publishTelemetry(root, sourceId)
    if SetBool == nil or SetInt == nil or SetString == nil then return false end
    local state = budget.state
    local prefix = tostring(root or "StellarisShips/testing/presentationBudget/")
        .. tostring(sourceId or "unknown") .. "/"
    state.telemetryRoot = tostring(root or "StellarisShips/testing/presentationBudget/")
    state.telemetrySource = tostring(sourceId or "unknown")
    SetBool(prefix .. "ready", true, true)
    SetInt(prefix .. "frame", state.frame, true)
    SetInt(prefix .. "beginCount", state.beginCount, true)
    SetString(prefix .. "beginOwner", state.beginOwner, true)
    SetInt(prefix .. "duplicateBeginCount", state.duplicateBeginCount, true)
    SetInt(prefix .. "requests", state.requests, true)
    SetInt(prefix .. "accepted", state.accepted, true)
    SetInt(prefix .. "degraded", state.degraded, true)
    SetInt(prefix .. "rejected", state.rejected, true)
    SetInt(prefix .. "voices", state.voices, true)
    SetInt(prefix .. "maxVoices", state.maxVoices, true)
    SetInt(prefix .. "shakes", state.shakes, true)
    SetInt(prefix .. "maxShakes", state.maxShakes, true)
    local primitiveState = client.weaponFxBudgetState or {}
    local primitiveConfig = client.weaponFxBudgetConfig or {}
    for key, value in pairs({
        particlesThisFrame = primitiveState.particlesThisFrame,
        pointLightsThisFrame = primitiveState.pointLightsThisFrame,
        spritesThisFrame = primitiveState.spritesThisFrame,
        linesThisFrame = primitiveState.linesThisFrame,
        maxParticles = primitiveConfig.maxParticlesSpawnedPerFrame,
        maxPointLights = primitiveConfig.maxPointLightsPerFrame,
        maxSprites = primitiveConfig.maxSpritesPerFrame,
        maxLines = primitiveConfig.maxLinesPerFrame,
    }) do
        SetInt(prefix .. key, math.floor(tonumber(value) or 0), true)
    end
    local kindIndex = 0
    for kind, item in pairs(state.byKind) do
        kindIndex = kindIndex + 1
        local kindRoot = prefix .. "kinds/" .. tostring(kindIndex) .. "/"
        SetString(kindRoot .. "kind", tostring(kind), true)
        for field, value in pairs(item) do
            SetInt(kindRoot .. tostring(field), math.floor(tonumber(value) or 0), true)
        end
    end
    SetInt(prefix .. "kindCount", kindIndex, true)
    local metadataIndex = 0
    for _, item in pairs(state.byMetadata) do
        metadataIndex = metadataIndex + 1
        local metadataRoot = prefix .. "metadata/" .. tostring(metadataIndex) .. "/"
        for field, value in pairs(item) do
            if type(value) == "number" then
                SetInt(metadataRoot .. tostring(field), math.floor(value), true)
            else
                SetString(metadataRoot .. tostring(field), tostring(value), true)
            end
        end
    end
    SetInt(prefix .. "metadataCount", metadataIndex, true)
    return true
end

function budget.getDiagnostics()
    local state = budget.state
    return {
        frame = state.frame,
        beginCount = state.beginCount,
        beginOwner = state.beginOwner,
        duplicateBeginCount = state.duplicateBeginCount,
        requests = state.requests,
        accepted = state.accepted,
        degraded = state.degraded,
        rejected = state.rejected,
        voices = state.voices,
        maxVoices = state.maxVoices,
        shakes = state.shakes,
        maxShakes = state.maxShakes,
        byKind = state.byKind,
        byMetadata = state.byMetadata,
        primitiveCalls = {
            particlesThisFrame = (client.weaponFxBudgetState or {}).particlesThisFrame or 0,
            pointLightsThisFrame = (client.weaponFxBudgetState or {}).pointLightsThisFrame or 0,
            spritesThisFrame = (client.weaponFxBudgetState or {}).spritesThisFrame or 0,
            linesThisFrame = (client.weaponFxBudgetState or {}).linesThisFrame or 0,
        },
    }
end
