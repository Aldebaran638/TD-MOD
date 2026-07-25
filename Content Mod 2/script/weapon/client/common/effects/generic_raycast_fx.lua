---@diagnostic disable: undefined-global

client = client or {}
client.genericRaycastFxState = client.genericRaycastFxState or { beams = {}, sprite = 0 }

local _profiles = {
    energyBeam = { color = { 0.25, 0.65, 1.0 }, width = 1.2, life = 0.16 },
    arcBeam = { color = { 0.65, 0.25, 1.0 }, width = 1.8, life = 0.22 },
}

local function _normalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, -1) end
    return VecScale(value, 1.0 / length)
end

local function _cameraAxis(direction, center)
    local toCamera = VecSub(GetCameraTransform().pos, center)
    local projected = VecSub(toCamera, VecScale(direction, VecDot(toCamera, direction)))
    if VecLength(projected) < 0.0001 then projected = Vec(0, 1, 0) end
    return _normalize(projected, Vec(1, 0, 0))
end

function client.genericRaycastFxInit()
    client.genericRaycastFxState = {
        beams = {},
        sprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png"),
    }
end

function client.spawnGenericRaycastWeaponFx(weaponType, fxProfile, sx, sy, sz, ex, ey, ez, nx, ny, nz)
    local _ = nx
    local __ = ny
    local ___ = nz
    local profileId = tostring(fxProfile or "energyBeam")
    local profile = _profiles[profileId] or _profiles.energyBeam
    table.insert(client.genericRaycastFxState.beams, {
        weaponType = tostring(weaponType or ""),
        profile = profileId,
        startPos = Vec(sx or 0, sy or 0, sz or 0),
        endPos = Vec(ex or 0, ey or 0, ez or 0),
        life = profile.life,
        maxLife = profile.life,
    })
end

function client.genericRaycastFxTick(dt)
    local beams = client.genericRaycastFxState.beams or {}
    for i = #beams, 1, -1 do
        beams[i].life = (beams[i].life or 0.0) - math.max(0.0, tonumber(dt) or 0.0)
        if beams[i].life <= 0.0 then table.remove(beams, i) end
    end
end

function client.genericRaycastFxRender()
    local state = client.genericRaycastFxState
    if math.floor(state.sprite or 0) == 0 then return end
    for i = 1, #(state.beams or {}) do
        local beam = state.beams[i]
        local profile = _profiles[beam.profile] or _profiles.energyBeam
        local vector = VecSub(beam.endPos, beam.startPos)
        local length = VecLength(vector)
        if length > 0.001 then
            local direction = VecScale(vector, 1.0 / length)
            local center = VecLerp(beam.startPos, beam.endPos, 0.5)
            local transform = Transform(center, QuatAlignXZ(direction, _cameraAxis(direction, center)))
            local alpha = math.max(0.0, math.min(1.0, (beam.life or 0.0) / math.max(0.001, beam.maxLife or 0.1)))
            local color = profile.color
            DrawSprite(state.sprite, transform, length, profile.width * 5.0,
                color[1] * 2.0, color[2] * 2.0, color[3] * 2.0, alpha * 0.35,
                true, true, false)
            DrawSprite(state.sprite, transform, length, profile.width,
                2.5, 2.5, 2.5, alpha, true, true, false)
            PointLight(beam.startPos, color[1], color[2], color[3], 8.0 * alpha)
        end
    end
end

