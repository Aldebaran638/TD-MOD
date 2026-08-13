---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

-- Preview Suite v1 candidate.
--
-- Effect Lab, Weapon Range and Ship Dock are deliberately thin clients of the
-- same compiler/catalog/world/entity contracts used by Runtime.  This module
-- owns preview lifecycle and diagnostics only; it never mutates the runtime
-- catalog and never calls a Teardown engine API.  The host supplies the
-- production EffectPlayer/PresentationBudget and the World/Entity adapters.

cm2PreviewSuiteV1 = cm2PreviewSuiteV1 or {}
local suite = cm2PreviewSuiteV1

suite.protocolVersion = "cm2.preview-suite/1"
suite.previewModes = { "effect-lab", "weapon-range", "ship-dock" }
suite.replayStages = { "S0", "S2", "S5" }
-- The injected production object exposes effectPlayer.init/play/update/stop;
-- _invoke keeps this candidate independent of the live client global.
-- Every preview replay records a fixed seed and an explicit LOD choice.

local function _safeString(value, fallback)
    if type(value) ~= "string" or value == "" then return fallback end
    return value
end

local function _safeNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function _clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] ~= nil then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[_clone(key, seen)] = _clone(item, seen) end
    return copy
end

local function _record(state, mode, operation, payload)
    state.trace[#state.trace + 1] = {
        index = #state.trace + 1,
        mode = mode,
        operation = operation,
        generation = state.generation,
        payload = payload or {},
    }
    while #state.trace > 512 do table.remove(state.trace, 1) end
end

local function _invoke(object, name, ...)
    if type(object) ~= "table" or type(object[name]) ~= "function" then return nil, "missing adapter API: " .. name end
    local ok, first, second = pcall(object[name], ...)
    if not ok then return nil, tostring(first) end
    return first, second
end

local function _newState()
    return {
        initialized = false,
        disposed = false,
        generation = 0,
        seed = 424242,
        compiler = nil,
        catalog = nil,
        worldAdapter = nil,
        entityAdapter = nil,
        effectPlayer = nil,
        presentationBudget = nil,
        runtimeCatalogHash = "",
        runtimeCatalogSnapshot = nil,
        previewCatalog = {},
        active = {},
        trace = {},
        diagnostics = { compiles = 0, catalogLookups = 0, staleRejected = 0, previewCatalogWrites = 0 },
    }
end

suite.state = suite.state or _newState()

function suite.init(dependencies, options)
    local deps = dependencies or {}
    local config = options or {}
    if type(deps.compiler) ~= "table" or type(deps.catalog) ~= "table" then return false, "compiler and catalog are required" end
    if type(deps.worldEntityAdapter) ~= "table" then return false, "World/Entity adapter is required" end
    local state = _newState()
    state.initialized = true
    state.disposed = false
    state.generation = math.max(1, math.floor(_safeNumber(config.generation, 1)))
    state.seed = math.max(0, math.floor(_safeNumber(config.seed, 424242)))
    state.compiler = deps.compiler
    state.catalog = deps.catalog
    state.worldAdapter = deps.worldEntityAdapter.world or deps.worldEntityAdapter
    state.entityAdapter = deps.worldEntityAdapter.entity or deps.worldEntityAdapter
    state.effectPlayer = deps.effectPlayer
    state.presentationBudget = deps.presentationBudget
    state.runtimeCatalogHash = _safeString(deps.catalog.hash, "runtime-catalog-unknown")
    state.runtimeCatalogSnapshot = _clone(deps.catalog.snapshot)
    suite.state = state
    _record(state, "suite", "init", {
        compiler = _safeString(deps.compiler.version, "shared-compiler"),
        catalog = state.runtimeCatalogHash,
        worldEntityAdapter = _safeString(deps.worldEntityAdapter.version, "cm2.world/1"),
        runtimeCatalogMutation = "forbidden",
    })
    return true, suite.snapshot()
end

local function _ready()
    return suite.state.initialized and not suite.state.disposed
end

local function _lookup(definitionId)
    local state = suite.state
    local id = _safeString(definitionId, "")
    if id == "" then return nil, "definition id is required" end
    local definition, errorText = _invoke(state.catalog, "lookup", id)
    state.diagnostics.catalogLookups = state.diagnostics.catalogLookups + 1
    if definition == nil then return nil, errorText or "definition is not in the frozen catalog" end
    return definition
end

local function _compile(definition)
    local state = suite.state
    local normalized, errorText = _invoke(state.compiler, "compile", definition)
    if normalized == nil then return nil, errorText or "compiler rejected definition" end
    state.diagnostics.compiles = state.diagnostics.compiles + 1
    return _clone(normalized)
end

function suite.runEffectLab(definitionId, options)
    if not _ready() then return nil, "preview suite is not initialized" end
    local state = suite.state
    local config = options or {}
    local definition, lookupError = _lookup(definitionId)
    if definition == nil then return nil, lookupError end
    local normalized, compileError = _compile(definition)
    if normalized == nil then return nil, compileError end
    if type(state.effectPlayer) ~= "table" then return nil, "production EffectPlayer is required" end
    local distance = _safeString(config.distance, "near") == "far" and "far" or "near"
    local lod = distance == "far" and 1 or 0
    local owner = { id = "preview:effect-lab", generation = state.generation, valid = true }
    local anchor = config.targetAnchor or { id = "preview:effect-target", valid = true }
    _invoke(state.effectPlayer, "init", 128)
    local handle = _invoke(state.effectPlayer, "play", normalized.id or definitionId, owner, anchor, {
        seed = state.seed, lod = lod, rendererState = _clone(config.context or {}),
    })
    if handle == nil then return nil, "EffectPlayer rejected generated definition" end
    _record(state, "effect-lab", "play", { definition = definitionId, seed = state.seed, lod = lod, handle = handle })
    _invoke(state.effectPlayer, "update", handle, _safeNumber(config.duration, 0.25))
    _invoke(state.effectPlayer, "stop", handle, "preview-complete", 0.0)
    state.active["effect-lab"] = nil
    _record(state, "effect-lab", "stop", { handle = handle })
    return {
        mode = "effect-lab", definition = definitionId, runtimeDTO = normalized,
        seed = state.seed, distance = distance, lod = lod,
        playerOwner = "production-effect-player", replayable = true,
    }
end

local function _nextRandom(state)
    -- Integer arithmetic is intentionally bounded so the same trace is used by
    -- the headless preview and the in-game adapter.
    state.random = (state.random * 1664525 + 1013904223) % 4294967296
    return state.random / 4294967296
end

function suite.runWeaponRange(definitionId, targets, options)
    if not _ready() then return nil, "preview suite is not initialized" end
    local state = suite.state
    local config = options or {}
    local definition, lookupError = _lookup(definitionId)
    if definition == nil then return nil, lookupError end
    local normalized, compileError = _compile(definition)
    if normalized == nil then return nil, compileError end
    state.random = math.max(0, math.floor(_safeNumber(config.seed, state.seed)))
    local result = {
        mode = "weapon-range", definition = definitionId, runtimeDTO = normalized,
        seed = state.random, muzzle = _clone(config.muzzle or { 0.0, 0.0, 0.0 }),
        targetTypes = {}, shots = 0, hits = 0, damage = 0, ballisticTrace = {}, budget = { accepted = 0, degraded = 0, rejected = 0 },
    }
    local list = type(targets) == "table" and targets or {}
    for index, target in ipairs(list) do
        local targetType = _safeString(target.type, "environment")
        result.targetTypes[targetType] = (result.targetTypes[targetType] or 0) + 1
        result.shots = result.shots + 1
        local roll = _nextRandom(state)
        local hit = roll >= _safeNumber(target.missThreshold, 0.2)
        if hit then
            result.hits = result.hits + 1
            local minimum = math.floor(_safeNumber(normalized.damageMin, 1))
            local maximum = math.max(minimum, math.floor(_safeNumber(normalized.damageMax, minimum)))
            result.damage = result.damage + minimum + math.floor(roll * (maximum - minimum + 1))
        end
        result.ballisticTrace[#result.ballisticTrace + 1] = { index = index, targetType = targetType, moving = target.moving == true, roll = roll, hit = hit }
        local budgetClass = _safeString(target.budget, "normal")
        if budgetClass == "rejected" then result.budget.rejected = result.budget.rejected + 1
        elseif budgetClass == "degraded" then result.budget.degraded = result.budget.degraded + 1
        else result.budget.accepted = result.budget.accepted + 1 end
    end
    _record(state, "weapon-range", "replay", { seed = result.seed, shots = result.shots, hits = result.hits, damage = result.damage })
    return result
end

function suite.spawnShipDock(definitionId, options)
    if not _ready() then return nil, "preview suite is not initialized" end
    local state = suite.state
    local config = options or {}
    local definition, lookupError = _lookup(definitionId)
    if definition == nil then return nil, lookupError end
    local normalized, compileError = _compile(definition)
    if normalized == nil then return nil, compileError end
    if type(definition.vox) ~= "table" or type(definition.entityGraph) ~= "table" then return nil, "Ship Dock requires vox and entityGraph" end
    local instanceId = _safeString(config.instanceId, "preview:ship-dock")
    local spawnResult = _invoke(state.entityAdapter, "spawn", instanceId, state.generation, normalized)
    if spawnResult == nil then return nil, "World/Entity adapter rejected Ship Dock spawn" end
    local result = {
        mode = "ship-dock", definition = definitionId, runtimeDTO = normalized,
        instanceId = instanceId, generation = state.generation, vox = _clone(definition.vox),
        entityGraph = _clone(definition.entityGraph), anchors = _clone(definition.anchors or {}),
        mounts = _clone(definition.mounts or {}), turrets = _clone(definition.turrets or {}),
        camera = _clone(config.camera or { mode = "orbit", distance = 12.0 }),
        engineMarkers = _clone(config.engineMarkers or {}), spawned = true, disposed = false,
    }
    state.active["ship-dock"] = result
    _record(state, "ship-dock", "spawn", { instanceId = instanceId, graph = definition.entityGraph.id, vox = definition.vox.path })
    return result
end

function suite.disposeShipDock(instanceId)
    if not _ready() then return false, "preview suite is not initialized" end
    local state = suite.state
    local active = state.active["ship-dock"]
    if active == nil or active.instanceId ~= instanceId then state.diagnostics.staleRejected = state.diagnostics.staleRejected + 1; return false, "stale Ship Dock instance" end
    local ok, errorText = _invoke(state.entityAdapter, "dispose", instanceId, state.generation)
    if ok == nil and errorText ~= nil then return false, errorText end
    active.spawned = false
    active.disposed = true
    state.active["ship-dock"] = nil
    _record(state, "ship-dock", "dispose", { instanceId = instanceId })
    return true
end

function suite.exportDiagnostics(options)
    local state = suite.state
    local config = options or {}
    local catalogUnchanged = state.runtimeCatalogHash == _safeString(state.catalog and state.catalog.hash, state.runtimeCatalogHash)
    return {
        protocolVersion = suite.protocolVersion,
        runtimeCatalogHash = state.runtimeCatalogHash,
        runtimeCatalogUnchanged = catalogUnchanged,
        compilerVersion = _safeString(state.compiler and state.compiler.version, "shared-compiler"),
        worldEntityAdapter = _safeString(state.worldAdapter and state.worldAdapter.version, "cm2.world/1"),
        diagnostics = _clone(state.diagnostics),
        trace = _clone(state.trace),
        screenshot = { requested = config.screenshot == true, provider = "preview-capture-v1", runtimeRequired = true },
        recording = { requested = config.recording == true, provider = "preview-replay-v1", runtimeRequired = true },
    }
end

function suite.snapshot()
    local state = suite.state
    return {
        protocolVersion = suite.protocolVersion,
        initialized = state.initialized, disposed = state.disposed,
        generation = state.generation, seed = state.seed,
        activeModes = { effectLab = state.active["effect-lab"] ~= nil, weaponRange = state.active["weapon-range"] ~= nil, shipDock = state.active["ship-dock"] ~= nil },
        runtimeCatalogMutation = "forbidden",
    }
end

function suite.dispose()
    local state = suite.state
    if not state.initialized or state.disposed then return false end
    if state.active["ship-dock"] ~= nil then suite.disposeShipDock(state.active["ship-dock"].instanceId) end
    state.disposed = true
    state.generation = state.generation + 1
    _record(state, "suite", "dispose", { generation = state.generation })
    return true
end
