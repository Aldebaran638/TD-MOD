---@diagnostic disable: undefined-global

client = client or {}
client.genericRaycastFxState = client.genericRaycastFxState or { beams = {}, sprite = 0 }

local _profiles = {
    gammaBeam = { color = { 1.0, 0.38, 0.05 }, coreColor = { 1.0, 0.78, 0.32 }, width = 0.2, life = 0.115 },
    redBeam = { color = { 1.0, 0.08, 0.03 }, coreColor = { 1.8, 0.55, 0.28 }, width = 0.20, life = 0.115 },
    blueBeam = { color = { 0.06, 0.32, 1.0 }, coreColor = { 0.55, 0.85, 1.8 }, width = 0.20, life = 0.115 },
    uvBeam = { color = { 0.62, 0.10, 1.0 }, coreColor = { 1.20, 0.65, 1.8 }, width = 0.20, life = 0.115 },
    xrayBeam = { color = { 0.15, 1.0, 0.95 }, coreColor = { 0.70, 1.8, 1.7 }, width = 0.20, life = 0.115 },
    energyBeam = { color = { 0.25, 0.65, 1.0 }, width = 1.2, life = 0.16 },
    focusedArcBeam = { color = { 0.72, 0.22, 1.0 }, width = 1.8, life = 0.22 },
    arcBeam = { color = { 0.18, 1.0, 0.32 }, width = 1.8, life = 0.22 },
    psionicArcBeam = { color = { 0.72, 0.18, 1.0 }, width = 1.8, life = 0.22 },
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

local function _spawnImpactParticles(profile, position, normal, tint)
    local color = tint or profile.color or { 1.0, 0.38, 0.05 }
    local impactNormal = _normalize(normal, Vec(0, 1, 0))
    ParticleReset()
    ParticleColor(
        color[1], color[2], color[3],
        color[1] * 0.35, color[2] * 0.22, color[3] * 0.12
    )
    ParticleRadius(0.16, 0.025, "easeout")
    ParticleAlpha(1.0, 0.0)
    ParticleGravity(-1.5)
    ParticleDrag(0.12)
    ParticleEmissive(18.0, 0.0)
    ParticleCollide(0.0)
    local count = profile == _profiles.arcBeam and 12 or 18
    if not client.weaponFxTakeParticles(count, "normal") then return end
    for _ = 1, count do
        local scatter = _normalize(
            Vec(
                math.random() * 2.0 - 1.0,
                math.random() * 2.0 - 1.0,
                math.random() * 2.0 - 1.0
            ),
            impactNormal
        )
        local velocity = VecAdd(
            VecScale(impactNormal, 1.8 + math.random() * 3.2),
            VecScale(scatter, 1.0 + math.random() * 2.6)
        )
        SpawnParticle(position, velocity, 0.18 + math.random() * 0.22)
    end
end

function client.genericRaycastFxInit()
    client.genericRaycastFxState = {
        beams = {},
        sprite = LoadSprite("MOD/gfx/weapons/tachyon_lance/beam_soft.png"),
    }
end

function client.spawnGenericRaycastWeaponFx(
    weaponType, fxProfile,
    sx, sy, sz, ex, ey, ez,
    nx, ny, nz, didHit, impactLayer
)
    local profileId = tostring(fxProfile or "energyBeam")
    local profile = _profiles[profileId] or _profiles.energyBeam
    local definition = (weaponData or {})[tostring(weaponType or "")] or {}
    local fxColor = definition.fxColor
    local life = profileId == "gammaBeam" and client.gammaLaserFxProfile(weaponType).life or profile.life
    local endPos = Vec(ex or 0, ey or 0, ez or 0)
    local hitNormal = Vec(nx or 0, ny or 1, nz or 0)
    table.insert(client.genericRaycastFxState.beams, {
        weaponType = tostring(weaponType or ""),
        profile = profileId,
        startPos = Vec(sx or 0, sy or 0, sz or 0),
        endPos = endPos,
        hitNormal = hitNormal,
        didHit = math.floor(didHit or 0) ~= 0,
        impactLayer = tostring(impactLayer or "none"),
        fxColor = fxColor,
        life = life,
        maxLife = life,
    })
    if profileId == "gammaBeam" then
        client.spawnGammaLaserMuzzleFx(weaponType, Vec(sx or 0, sy or 0, sz or 0), VecSub(endPos, Vec(sx or 0, sy or 0, sz or 0)))
        if math.floor(didHit or 0) ~= 0 then client.spawnGammaLaserImpactFx(weaponType, endPos, hitNormal, impactLayer) end
    elseif math.floor(didHit or 0) ~= 0 then
        if not client.spawnWeaponImpactFx(weaponType, endPos, hitNormal, impactLayer) then
            _spawnImpactParticles(profile, endPos, hitNormal, fxColor)
        end
    end
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
            local alpha = math.max(0.0, math.min(1.0, (beam.life or 0.0) / math.max(0.001, beam.maxLife or 0.1)))
            local color = beam.fxColor or profile.color
            local coreColor = profile.coreColor or {
                math.max(1.6, color[1] * 1.8),
                math.max(1.6, color[2] * 1.8),
                math.max(1.6, color[3] * 1.8),
            }
            if beam.profile == "gammaBeam" then
                client.gammaLaserDrawBeam(beam.startPos, beam.endPos, client.gammaLaserFxProfile(beam.weaponType), (beam.maxLife - beam.life), beam.maxLife)
            elseif beam.profile == "arcBeam" or beam.profile == "focusedArcBeam"
                or beam.profile == "psionicArcBeam" then
                local axisA = _cameraAxis(direction, center)
                local axisB = _normalize(VecCross(direction, axisA), Vec(0, 1, 0))
                local previous = beam.startPos
                local segmentCount = math.max(8, math.min(18, math.floor(length / 24.0)))
                local agePhase = (beam.maxLife - beam.life) * 95.0
                for segmentIndex = 1, segmentCount do
                    local t = segmentIndex / segmentCount
                    local point = VecLerp(beam.startPos, beam.endPos, t)
                    if segmentIndex < segmentCount then
                        local envelope = math.sin(math.pi * t)
                        local jitterA = math.sin(agePhase + segmentIndex * 2.17) * 0.95 * envelope
                        local jitterB = math.cos(agePhase * 1.31 + segmentIndex * 1.63) * 0.65 * envelope
                        point = VecAdd(point, VecAdd(VecScale(axisA, jitterA), VecScale(axisB, jitterB)))
                    end
                    local segment = VecSub(point, previous)
                    local segmentLength = VecLength(segment)
                    if segmentLength > 0.001 then
                        local segmentDirection = VecScale(segment, 1.0 / segmentLength)
                        local segmentCenter = VecLerp(previous, point, 0.5)
                        local transform = Transform(
                            segmentCenter,
                            QuatAlignXZ(segmentDirection, _cameraAxis(segmentDirection, segmentCenter))
                        )
                        if client.weaponFxTakeSprite(1) then
                            DrawSprite(state.sprite, transform, segmentLength, profile.width * 4.5,
                                color[1] * 2.2, color[2] * 2.2, color[3] * 2.2, alpha * 0.42,
                                true, true, false)
                        end
                        if client.weaponFxTakeSprite(1) then
                            DrawSprite(state.sprite, transform, segmentLength, profile.width * 0.72,
                                2.5, 2.5, 2.5, alpha, true, true, false)
                        end
                    end
                    previous = point
                end
            else
                local transform = Transform(center, QuatAlignXZ(direction, _cameraAxis(direction, center)))
                if client.weaponFxTakeSprite(1) then
                    DrawSprite(state.sprite, transform, length, profile.width * 5.0,
                        color[1] * 2.0, color[2] * 2.0, color[3] * 2.0, alpha * 0.35,
                        true, true, false)
                end
                if client.weaponFxTakeSprite(1) then
                    DrawSprite(state.sprite, transform, length, profile.width,
                        coreColor[1], coreColor[2], coreColor[3], alpha, true, true, false)
                end
            end
            if beam.profile ~= "gammaBeam" then
                client.weaponFxPointLight(beam.startPos, color[1], color[2], color[3], 8.0 * alpha)
                if beam.didHit then client.weaponFxPointLight(beam.endPos, color[1], color[2], color[3], 6.0 * alpha) end
            end
        end
    end
end

