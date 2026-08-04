---@diagnostic disable: undefined-global

-- Camera-facing sprite beam helpers shared by charged ray weapons.
client = client or {}

function client.chargedRayTableToVec(value)
    local source = value or {}
    return Vec(tonumber(source.x or source[1]) or 0.0, tonumber(source.y or source[2]) or 0.0, tonumber(source.z or source[3]) or 0.0)
end

function client.chargedRaySafeNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0.0, 0.0, -1.0) end
    return VecScale(value, 1.0 / length)
end

function client.chargedRayCameraFacingAxis(beamAxis, beamCenter)
    local toCamera = VecSub(GetCameraTransform().pos, beamCenter)
    local projected = VecSub(toCamera, VecScale(beamAxis, VecDot(toCamera, beamAxis)))
    if VecLength(projected) < 0.0001 then
        projected = VecSub(Vec(0, 1, 0), VecScale(beamAxis, beamAxis[2]))
    end
    if VecLength(projected) < 0.0001 then
        projected = VecSub(Vec(1, 0, 0), VecScale(beamAxis, beamAxis[1]))
    end
    return client.chargedRaySafeNormalize(projected, Vec(0.0, 0.0, 1.0))
end

function client.chargedRayDrawBeamLayers(sprite, startPoint, endPoint, layers, intensity, widthScale)
    local beamVector = VecSub(endPoint, startPoint)
    local beamLength = VecLength(beamVector)
    if sprite == 0 or beamLength < 0.001 then return end
    local beamAxis = VecScale(beamVector, 1.0 / beamLength)
    local center = VecLerp(startPoint, endPoint, 0.5)
    local transform = Transform(center, QuatAlignXZ(beamAxis, client.chargedRayCameraFacingAxis(beamAxis, center)))
    local light = math.max(0.0, tonumber(intensity) or 0.0)
    local scale = math.max(0.0, tonumber(widthScale) or 1.0)
    for _, layer in ipairs(layers or {}) do
        if client.weaponFxTakeSprite(1) then
            local color = layer.color or { 1, 1, 1 }
            DrawSprite(sprite, transform, beamLength, math.max(0.01, (tonumber(layer.width) or 1.0) * scale),
                (tonumber(color[1]) or 1.0) * light, (tonumber(color[2]) or 1.0) * light,
                (tonumber(color[3]) or 1.0) * light, tonumber(layer.alpha) or 1.0, true, true, false)
        end
    end
end
