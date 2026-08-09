---@diagnostic disable: undefined-global

client = client or {}
client.perditionBeamFxState = client.perditionBeamFxState or { lastSeq = {}, beams = {}, sprite = 0 }

local beamDuration = 2.00
local beamWidthMultiplier = 2.50
local beamLayers = {
    -- Two times the tachyon layer opacity, clamped to the valid opaque range.
    -- The surrounding glow is intentionally another 2x brighter than the
    -- previous inferno outer layer so its full width remains visible.
    { width = 96.0, color = { 0.68, 0.024, 0.004 }, alpha = 1.00 },
    { width = 56.0, color = { 1.00, 0.065, 0.006 }, alpha = 1.00 },
    { width = 28.0, color = { 1.60, 0.24, 0.012 }, alpha = 1.00 },
    { width = 11.0, color = { 3.00, 1.35, 0.42 }, alpha = 1.00 },
}

local function _envelope(age)
    local t = math.max(0.0, math.min(1.0, age / beamDuration))
    local smooth = t * t * (3.0 - 2.0 * t)
    -- The beam is fully bright and fully wide on the first frame; only its
    -- emissive intensity decays over the pulse lifetime.
    return 16.0 * (1.0 - smooth), 1.0
end

function client.perditionBeamFxInit()
    client.perditionBeamFxState = { lastSeq = {}, beams = {}, sprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png") }
end

function client.perditionBeamFxTick(dt)
    local state, delta = client.perditionBeamFxState, math.max(0.0, tonumber(dt) or 0.0)
    for _, shipBodyId in ipairs(client.registryShipGetRegisteredBodyIds() or {}) do
        local event = client.tSlotRenderGetEvent(shipBodyId)
        if event ~= nil and state.lastSeq[shipBodyId] ~= event.seq then
            state.lastSeq[shipBodyId] = event.seq
            local definition = (weaponData or {})[tostring(event.weaponType or "")] or {}
            if tostring(definition.fxProfile or "") == "perditionBeam"
                and event.eventType == "launch_start" then
                state.beams[#state.beams + 1] = {
                    age = 0.0, startPoint = client.chargedRayTableToVec(event.firePoint),
                    endPoint = client.chargedRayTableToVec(event.hitPoint),
                }
                while #state.beams > 6 do table.remove(state.beams, 1) end
            end
        end
    end
    for index = #state.beams, 1, -1 do
        local beam = state.beams[index]
        beam.age = beam.age + delta
        if beam.age >= beamDuration then table.remove(state.beams, index) end
    end
end

function client.perditionBeamFxRender()
    local state = client.perditionBeamFxState
    for _, beam in ipairs(state.beams) do
        local intensity, core = _envelope(beam.age)
        local layers = beamLayers
        client.chargedRayDrawBeamLayers(
            state.sprite, beam.startPoint, beam.endPoint, layers, intensity,
            beamWidthMultiplier
        )
    end
end
