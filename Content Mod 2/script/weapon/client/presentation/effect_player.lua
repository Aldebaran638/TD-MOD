---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

-- Fixed-capacity EffectPlayer foundation. Renderers remain specialised; this
-- module only owns instance identity, lifecycle, ownership and bounded storage.
client = client or {}
client.effectPlayer = client.effectPlayer or {}

local player = client.effectPlayer

local function _newState(capacity)
    local free = {}
    for index = capacity, 1, -1 do free[#free + 1] = index end
    return {
        initialized = true,
        capacity = capacity,
        slots = {},
        generations = {},
        free = free,
        activeIndices = {},
        activeCount = 0,
        resources = {},
        metrics = { played = 0, updated = 0, stopped = 0, destroyed = 0, ownerLost = 0, anchorLost = 0, stale = 0 },
    }
end

local function _state()
    if player.state == nil then player.state = _newState(128) end
    return player.state
end

local function _validHandle(handle)
    return type(handle) == "table"
        and math.floor(tonumber(handle.index) or 0) > 0
        and math.floor(tonumber(handle.generation) or 0) > 0
end

local function _resolve(handle)
    local state = _state()
    if not _validHandle(handle) then state.metrics.stale = state.metrics.stale + 1; return nil end
    local index = math.floor(handle.index)
    local instance = state.slots[index]
    if instance == nil or instance.handle.generation ~= math.floor(handle.generation) then
        state.metrics.stale = state.metrics.stale + 1
        return nil
    end
    return instance
end

local function _ownerAlive(owner)
    if owner == nil then return true end
    if type(owner) ~= "table" then return true end
    if owner.valid == false or owner.alive == false or owner.disposed == true then return false end
    return true
end

local function _anchorAlive(anchor)
    if anchor == nil then return true end
    if type(anchor) ~= "table" then return true end
    return anchor.valid ~= false and anchor.disposed ~= true
end

function player.init(capacity)
    local existing = player.state
    if existing ~= nil and existing.initialized then return existing end
    local requested = math.max(1, math.floor(tonumber(capacity) or 128))
    player.state = _newState(requested)
    return player.state
end

function player.play(effectId, owner, anchor, options)
    local state = _state()
    if #state.free <= 0 then return nil, "effect capacity exhausted" end
    local index = state.free[#state.free]
    state.free[#state.free] = nil
    local generation = math.floor(state.generations[index] or 0) + 1
    if generation > 2000000000 then generation = 1 end
    state.generations[index] = generation
    local config = options or {}
    local instance = {
        handle = { index = index, generation = generation },
        effect = tostring(effectId or ""),
        owner = owner,
        anchor = anchor,
        clock = 0.0,
        seed = math.max(0, math.floor(tonumber(config.seed) or 0)),
        lod = tonumber(config.lod) or 0,
        priority = tostring(config.priority or "normal"),
        phase = "playing",
        fadeRemain = 0.0,
        renderer = config.rendererState or {},
        densePosition = state.activeCount + 1,
    }
    state.slots[index] = instance
    state.activeCount = state.activeCount + 1
    state.activeIndices[state.activeCount] = index
    state.metrics.played = state.metrics.played + 1
    return instance.handle
end

function player.update(handle, dt)
    local instance = _resolve(handle)
    if instance == nil then return false, "stale handle" end
    local state = _state()
    if not _ownerAlive(instance.owner) then
        state.metrics.ownerLost = state.metrics.ownerLost + 1
        player.destroy(handle, "owner-lost")
        return false, "owner-lost"
    end
    if not _anchorAlive(instance.anchor) then
        state.metrics.anchorLost = state.metrics.anchorLost + 1
        player.stop(handle, "anchor-lost", 0.0)
        return false, "anchor-lost"
    end
    instance.clock = instance.clock + math.max(0.0, tonumber(dt) or 0.0)
    if instance.phase == "fading" then
        instance.fadeRemain = math.max(0.0, instance.fadeRemain - math.max(0.0, tonumber(dt) or 0.0))
        if instance.fadeRemain <= 0.0 then player.destroy(handle, "fade-complete") end
    end
    state.metrics.updated = state.metrics.updated + 1
    return true
end

function player.stop(handle, reason, fadeSeconds)
    local instance = _resolve(handle)
    if instance == nil then return false, "stale handle" end
    if instance.phase == "stopped" or instance.phase == "fading" then return true end
    instance.phase = (tonumber(fadeSeconds) or 0.0) > 0.0 and "fading" or "stopped"
    instance.fadeRemain = math.max(0.0, tonumber(fadeSeconds) or 0.0)
    instance.stopReason = tostring(reason or "stop")
    _state().metrics.stopped = _state().metrics.stopped + 1
    if instance.phase == "stopped" then player.destroy(handle, instance.stopReason) end
    return true
end

function player.destroy(handle, reason)
    local instance = _resolve(handle)
    if instance == nil then return false, "stale handle" end
    local state = _state()
    local index = instance.handle.index
    local densePosition = instance.densePosition
    local lastIndex = state.activeIndices[state.activeCount]
    state.activeIndices[densePosition] = lastIndex
    if lastIndex ~= nil and lastIndex ~= index and state.slots[lastIndex] ~= nil then
        state.slots[lastIndex].densePosition = densePosition
    end
    state.activeIndices[state.activeCount] = nil
    state.activeCount = state.activeCount - 1
    state.slots[index] = nil
    state.free[#state.free + 1] = index
    state.metrics.destroyed = state.metrics.destroyed + 1
    return true
end

function player.updateAll(dt)
    local state = _state()
    local cursor = 1
    while cursor <= state.activeCount do
        local index = state.activeIndices[cursor]
        local instance = state.slots[index]
        if instance ~= nil then
            player.update(instance.handle, dt)
            if state.activeIndices[cursor] == index then cursor = cursor + 1 end
        else
            cursor = cursor + 1
        end
    end
end

function player.acquireResource(key, value)
    local state = _state()
    local id = tostring(key or "")
    if state.resources[id] == nil then state.resources[id] = value end
    return state.resources[id]
end

function player.sceneReload()
    local state = _state()
    local capacity = state.capacity
    player.state = _newState(capacity)
    return player.state
end

function player.getDiagnostics()
    local state = _state()
    return {
        capacity = state.capacity,
        active = state.activeCount,
        free = #state.free,
        invariant = state.activeCount + #state.free == state.capacity,
        metrics = state.metrics,
    }
end

function client.effectPlayerPlay(effectId, owner, anchor, options) return player.play(effectId, owner, anchor, options) end
function client.effectPlayerUpdate(handle, dt) return player.update(handle, dt) end
function client.effectPlayerStop(handle, reason, fadeSeconds) return player.stop(handle, reason, fadeSeconds) end
function client.effectPlayerDestroy(handle, reason) return player.destroy(handle, reason) end
