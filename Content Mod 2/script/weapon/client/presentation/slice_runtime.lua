---@diagnostic disable: undefined-global

-- Candidate vertical-slice bridge: Event Ring -> EffectPlayer. Existing legacy
-- callbacks remain the default; this module is active only for event-v1 slices.
client = client or {}
client.presentationSliceRuntime = client.presentationSliceRuntime or {}
local runtime = client.presentationSliceRuntime

local _sliceByWeapon = {
    ["cm2:weapon/flakArtillery"] = "ray-beam",
    ["cm2:weapon/gigaCannon"] = "logical-projectile",
    ["cm2:weapon/swarmerMissile"] = "guided-missile",
    ["cm2:weapon/tachyonLance"] = "tachyon-charge-beam",
    ["cm2:weapon/perditionBeam"] = "tachyon-charge-beam",
}

local function _state()
    if runtime.state == nil then
        runtime.state = {
            initialized = false,
            mode = "legacy",
            sliceMode = {},
            handles = {},
            trace = {},
            accepted = 0,
            rejected = 0,
            consumed = 0,
            disposed = 0,
            dispatchRejected = 0,
        }
    end
    return runtime.state
end

local function _slice(event)
    local weapon = tostring(((event or {}).weapon or {}).id or "")
    return _sliceByWeapon[weapon] or ""
end

local function _key(event, slice)
    local source = tostring(((event or {}).source or {}).id or "world")
    local weapon = tostring(((event or {}).weapon or {}).id or "")
    local payload = (event or {}).payload or {}
    local presentation = payload.presentation or {}
    local entity = tostring(
        payload.projectileId or payload.missileId or payload.craftBodyId
            or presentation.entityId or ""
    )
    return slice .. "|" .. source .. "|" .. weapon .. "|" .. entity
end

local function _unpack(values)
    if type(values) ~= "table" then return end
    local unpackFunction = table.unpack or unpack
    return unpackFunction(values)
end

local function _dispatchRoute(event)
    local payload = event.payload or {}
    local presentation = payload.presentation or {}
    local route = tostring(presentation.route or "")
    local args = presentation.args or {}
    local callbackByRoute = {
        ["ray.shieldImpact"] = "playProjectileShieldImpactFx",
        ["ray.effect"] = "spawnGenericRaycastWeaponFx",
        ["weapon.sound"] = "playWeaponSound",
        ["tSlot.render"] = "receiveTSlotRenderEvent",
        ["xSlot.render"] = "receiveXSlotRenderEvent",
        ["projectile.fireSound"] = "playKineticArtilleryFireSound",
        ["projectile.hitSound"] = "playKineticArtilleryHitSound",
        ["projectile.shieldImpact"] = "playProjectileShieldImpactFx",
        ["projectile.spawn"] = "spawnProjectileVisual",
        ["projectile.finish"] = "finishProjectileVisual",
        ["missile.finish"] = "finishMissileVisual",
        ["missile.spawn"] = "spawnMissileVisual",
        ["missile.fireSound"] = "playMissileFireSound",
        ["missile.impactSound"] = "playMissileImpactSound",
        ["missile.impactFx"] = "playMissileImpactFx",
        ["missile.muzzle"] = "spawnWeaponMuzzleFx",
        ["craft.launch"] = "spawnHSlotLaunchFx",
        ["craft.register"] = "registerHSlotCraftFx",
        ["craft.recover"] = "spawnHSlotRecoverFx",
    }
    local callbackName = callbackByRoute[route]
    if callbackName ~= nil and client[callbackName] ~= nil then
        client[callbackName](_unpack(args))
        return true, route
    end
    if route == "point-defense.fx" and client.spawnPointDefenseFx ~= nil then
        local destination = payload.destination or { 0.0, 0.0, 0.0 }
        local origin = event.transform ~= nil and event.transform.position or { 0.0, 0.0, 0.0 }
        client.spawnPointDefenseFx(
            payload.role or "flak",
            origin[1] or 0.0, origin[2] or 0.0, origin[3] or 0.0,
            destination[1] or destination.x or 0.0,
            destination[2] or destination.y or 0.0,
            destination[3] or destination.z or 0.0,
            payload.duration or 0.08
        )
        return true, route
    end
    return false, route
end

local function _record(state, event, slice, operation, handle)
    state.trace[#state.trace + 1] = {
        sequence = event.sequence,
        kind = event.kind,
        event_type = tostring(((event.payload or {}).eventType) or ""),
        route = tostring((((event.payload or {}).presentation or {}).route) or ""),
        slice = slice,
        operation = operation,
        handle = handle,
    }
    while #state.trace > 256 do table.remove(state.trace, 1) end
    if client.cm2TelemetryRecord ~= nil then
        client.cm2TelemetryRecord("presentation_slice_trace", {
            sequence = event.sequence,
            kind = event.kind,
            slice = slice,
            route = tostring((((event.payload or {}).presentation or {}).route) or ""),
            operation = operation,
            handle_index = handle ~= nil and math.floor(tonumber(handle.index) or 0) or 0,
            handle_generation = handle ~= nil and math.floor(tonumber(handle.generation) or 0) or 0,
        })
    end
end

function runtime.init()
    local state = _state()
    if state.initialized then return state end
    local requestedMode = (GetStringParam ~= nil and GetStringParam("presentationRuntime", "")) or ""
    if tostring(requestedMode or "") == "" and GetString ~= nil then
        requestedMode = GetString("StellarisShips/testing/scenario/presentationRuntime")
    end
    state.mode = tostring(requestedMode or "legacy")
    if state.mode == "" then state.mode = "legacy" end
    if state.mode ~= "event-v1" then state.mode = "legacy" end
    for _, slice in ipairs({ "ray-beam", "logical-projectile", "guided-missile", "tachyon-charge-beam" }) do
        local parameterName = "presentationRuntime_" .. slice:gsub("-", "_")
        local selected = (GetStringParam ~= nil and GetStringParam(parameterName, state.mode)) or state.mode
        state.sliceMode[slice] = selected == "event-v1" and "event-v1" or "legacy"
    end
    client.effectPlayer.init(128)
    state.initialized = true
    return state
end

local function _consumeEvent(state, event)
    local slice = _slice(event)
    local enabled = (slice == "" and state.mode == "event-v1")
        or (slice ~= "" and state.sliceMode[slice] == "event-v1")
    if not enabled then return end
    local key = _key(event, slice)
    local payload = event.payload or {}
    local owner = event.source or { id = "world", generation = 0 }
    local anchor = event.anchor or { valid = true }
    local effectId = tostring(((event.effect or {}).id) or ((event.weapon or {}).id) or ("cm2:effect/" .. tostring(event.kind)))
    local operation = "play"
    local handle = state.handles[key]
    local presentation = payload.presentation or {}
    local route = tostring(presentation.route or "")
    local isFinish = route == "projectile.finish"
        or route == "missile.finish"
        or event.kind == "craft_recover"
        or (event.kind == "impact" and tostring(payload.mode or "") == "finish")
    if isFinish then
        if handle ~= nil then
            client.effectPlayer.stop(handle, event.kind, 0.0)
            state.handles[key] = nil
            operation = "stop"
        else
            operation = "stop-missing"
        end
    elseif event.kind == "projectile" then
        if handle == nil then
            handle = client.effectPlayer.play(effectId, owner, anchor, {
                seed = event.seed,
                lod = payload.lod or 0,
                priority = event.priority,
                rendererState = { slice = slice, kind = event.kind },
            })
            if handle ~= nil then state.handles[key] = handle else state.rejected = state.rejected + 1 end
        else
            client.effectPlayer.update(handle, 0.0)
            operation = "update"
        end
    else
        handle = client.effectPlayer.play(effectId, owner, anchor, {
            seed = event.seed,
            lod = payload.lod or 0,
            priority = event.priority,
            rendererState = { slice = slice, kind = event.kind },
        })
        if handle ~= nil then
            client.effectPlayer.stop(handle, event.kind, 0.0)
        else
            state.rejected = state.rejected + 1
        end
    end
    local dispatched = _dispatchRoute(event)
    if not dispatched then state.dispatchRejected = state.dispatchRejected + 1 end
    state.accepted = state.accepted + 1
    _record(state, event, slice, operation, handle)
end

function runtime.tick(dt)
    local state = runtime.init()
    local hasEventSlice = false
    for _, mode in pairs(state.sliceMode) do
        if mode == "event-v1" then hasEventSlice = true; break end
    end
    if state.mode == "event-v1" or hasEventSlice then
        local events = client.presentationEventDrain()
        for _, event in ipairs(events) do
            state.consumed = state.consumed + 1
            _consumeEvent(state, event)
        end
    end
    client.effectPlayer.updateAll(dt)
end

function runtime.disposeOwner(sourceId)
    local state = _state()
    local prefix = "|" .. tostring(sourceId) .. "|"
    local disposed = 0
    for key, handle in pairs(state.handles) do
        if string.find(key, prefix, 1, true) ~= nil then
            client.effectPlayer.destroy(handle, "owner-dispose")
            state.handles[key] = nil
            state.disposed = state.disposed + 1
            disposed = disposed + 1
        end
    end
    client.presentationEventDisposeOwner(sourceId)
    if client.cm2TelemetryRecord ~= nil then
        client.cm2TelemetryRecord("presentation_slice_dispose", {
            source_id = tostring(sourceId),
            disposed = disposed,
        })
    end
end

function runtime.disposeAll()
    local state = _state()
    for key, handle in pairs(state.handles) do
        client.effectPlayer.destroy(handle, "client-dispose")
        state.handles[key] = nil
        state.disposed = state.disposed + 1
    end
    return client.presentationEventDisposeAll()
end

function runtime.getDiagnostics()
    local state = _state()
    return {
        mode = state.mode,
        accepted = state.accepted,
        rejected = state.rejected,
        consumed = state.consumed,
        disposed = state.disposed,
        dispatchRejected = state.dispatchRejected,
        activeHandles = (client.effectPlayer.getDiagnostics() or {}).active or 0,
        trace = state.trace,
    }
end

function client.presentationSliceRuntimeInit() return runtime.init() end
function client.presentationSliceRuntimeTick(dt) return runtime.tick(dt) end
function client.presentationSliceRuntimeDisposeOwner(sourceId) return runtime.disposeOwner(sourceId) end
function client.presentationSliceRuntimeDisposeAll() return runtime.disposeAll() end
