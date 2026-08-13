---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

-- Synthetic Creator Preview. It deliberately uses the production EffectPlayer
-- and PresentationBudget; no ship registry, body handle or battle context is
-- consulted.
client = client or {}
client.effectLab = client.effectLab or {}
local lab = client.effectLab

local function _state()
    if lab.state == nil then
        lab.state = {
            initialized = false,
            paused = false,
            seed = 1,
            distance = "near",
            lod = 0,
            budgetProfile = "normal",
            definition = nil,
            context = nil,
            handle = nil,
            elapsed = 0.0,
            trace = {},
            replayCount = 0,
        }
    end
    return lab.state
end

local function _record(state, operation, payload)
    state.trace[#state.trace + 1] = {
        index = #state.trace + 1,
        operation = operation,
        seed = state.seed,
        distance = state.distance,
        lod = state.lod,
        payload = payload or {},
    }
    while #state.trace > 256 do table.remove(state.trace, 1) end
end

function lab.init(options)
    local state = _state()
    local config = options or {}
    state.initialized = true
    state.paused = false
    state.seed = math.max(0, math.floor(tonumber(config.seed) or 1))
    state.distance = tostring(config.distance or "near") == "far" and "far" or "near"
    state.lod = state.distance == "far" and 1 or 0
    state.budgetProfile = tostring(config.budgetProfile or "normal")
    state.context = {
        origin = config.origin or { 0.0, 0.0, 0.0 },
        direction = config.direction or { 0.0, 0.0, -1.0 },
        hitPoint = config.hitPoint or { 0.0, 0.0, -20.0 },
        hitNormal = config.hitNormal or { 0.0, 1.0, 0.0 },
        targetAnchor = config.targetAnchor or { id = "lab:target", valid = true },
        owner = { id = "lab:synthetic", generation = 1, valid = true, alive = true },
    }
    state.definition = nil
    state.handle = nil
    state.elapsed = 0.0
    state.trace = {}
    state.replayCount = 0
    client.effectPlayer.init(128)
    _record(state, "init", { context = "synthetic", noRegistry = true })
    return state
end

function lab.setDefinition(definition)
    local state = _state()
    if not state.initialized then lab.init({}) end
    if type(definition) ~= "table" or tostring(definition.id or "") == "" then
        return false, "definition with stable id is required"
    end
    state.definition = {
        id = tostring(definition.id),
        kind = tostring(definition.kind or "effect"),
        sourceArtifact = tostring(definition.sourceArtifact or "generated-catalog"),
        rendererId = tostring(definition.rendererId or "cm2.effect-player"),
        rendererVersion = tostring(definition.rendererVersion or "1"),
    }
    _record(state, "definition", state.definition)
    return true
end

function lab.setDistance(distance)
    local state = _state()
    state.distance = tostring(distance or "near") == "far" and "far" or "near"
    state.lod = state.distance == "far" and 1 or 0
    _record(state, "lod", { distance = state.distance, lod = state.lod })
end

function lab.play()
    local state = _state()
    if not state.initialized then lab.init({}) end
    if state.definition == nil then return false, "no generated definition selected" end
    if state.handle ~= nil then client.effectPlayer.destroy(state.handle, "lab-replay") end
    state.handle = client.effectPlayer.play(
        state.definition.id,
        state.context.owner,
        state.context.targetAnchor,
        {
            seed = state.seed,
            lod = state.lod,
            priority = state.budgetProfile == "critical" and 2 or 0,
            rendererState = {
                origin = state.context.origin,
                direction = state.context.direction,
                hitPoint = state.context.hitPoint,
                hitNormal = state.context.hitNormal,
                rendererId = state.definition.rendererId,
                rendererVersion = state.definition.rendererVersion,
            },
        }
    )
    state.elapsed = 0.0
    state.paused = false
    state.replayCount = state.replayCount + 1
    _record(state, "play", { effect = state.definition.id, handle = state.handle })
    return state.handle ~= nil
end

function lab.pause()
    _state().paused = true
    _record(_state(), "pause")
end

function lab.stop()
    local state = _state()
    if state.handle ~= nil then client.effectPlayer.stop(state.handle, "lab-stop", 0.0) end
    state.handle = nil
    state.paused = true
    _record(state, "stop")
end

function lab.replay()
    local state = _state()
    state.handle = nil
    _record(state, "replay")
    return lab.play()
end

function lab.tick(dt)
    local state = _state()
    if not state.initialized then return end
    client.presentationBudget.beginFrame(dt)
    if not state.paused and state.handle ~= nil then
        local delta = math.max(0.0, tonumber(dt) or 0.0)
        state.elapsed = state.elapsed + delta
        client.effectPlayer.update(state.handle, delta)
        _record(state, "update", { elapsed = state.elapsed })
    end
end

function lab.getReport()
    local state = _state()
    local playerReport = client.effectPlayer.getDiagnostics()
    local budgetReport = client.presentationBudget.getDiagnostics()
    return {
        definition = state.definition,
        seed = state.seed,
        distance = state.distance,
        lod = state.lod,
        budgetProfile = state.budgetProfile,
        elapsed = state.elapsed,
        replayCount = state.replayCount,
        instanceCount = playerReport.active,
        playerInvariant = playerReport.invariant,
        budget = budgetReport,
        trace = state.trace,
    }
end

function lab.reset()
    local state = _state()
    if state.handle ~= nil then client.effectPlayer.destroy(state.handle, "lab-reset") end
    client.effectPlayer.sceneReload()
    lab.state = nil
end

function client.effectLabInit(options) return lab.init(options) end
function client.effectLabSetDefinition(definition) return lab.setDefinition(definition) end
function client.effectLabPlay() return lab.play() end
function client.effectLabPause() return lab.pause() end
function client.effectLabStop() return lab.stop() end
function client.effectLabReplay() return lab.replay() end
function client.effectLabTick(dt) return lab.tick(dt) end
function client.effectLabGetReport() return lab.getReport() end
function client.effectLabReset() return lab.reset() end
