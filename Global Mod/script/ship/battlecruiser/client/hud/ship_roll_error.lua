---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

client = client or {}

local function _clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function _safeNormalize(v, fallback)
    local len = VecLength(v)
    if len <= 0.000001 then
        return fallback or Vec(0, 1, 0)
    end
    return VecScale(v, 1.0 / len)
end

local function _projectOnPlane(v, planeNormal)
    local n = _safeNormalize(planeNormal, Vec(0, 0, -1))
    return VecSub(v, VecScale(n, VecDot(v, n)))
end

local function _signedAngleOnAxis(a, b, axis)
    local axisN = _safeNormalize(axis, Vec(0, 0, -1))
    local aN = _safeNormalize(a, Vec(0, 1, 0))
    local bN = _safeNormalize(b, Vec(0, 1, 0))

    local sinVal = VecDot(VecCross(aN, bN), axisN)
    local cosVal = _clamp(VecDot(aN, bN), -1.0, 1.0)
    return math.deg(math.atan2(sinVal, cosVal))
end

function client.shipRollErrorTick(dt)
    local _ = dt
    if client.shipRequestRollError == nil then
        return
    end

    local body = 0
    if client.shipCameraGetControlledBody ~= nil then
        body = client.shipCameraGetControlledBody() or 0
    else
        body = client.shipBody or 0
    end
    if body == 0 then
        return
    end

    if client.shipCamera ~= nil and (client.shipCamera.rearFreelookActive or client.shipCamera.frontFreelookActive) then
        client.shipRequestRollError(body, 0.0)
        return
    end

    local shipT = GetBodyTransform(body)
    local shipForward = TransformToParentVec(shipT, Vec(0, 0, -1))
    local shipUp = TransformToParentVec(shipT, Vec(0, 1, 0))

    local camT = GetCameraTransform()
    local camUp = TransformToParentVec(camT, Vec(0, 1, 0))

    local shipUpOnPlane = _projectOnPlane(shipUp, shipForward)
    local camUpOnPlane = _projectOnPlane(camUp, shipForward)

    local rollError = _signedAngleOnAxis(shipUpOnPlane, camUpOnPlane, shipForward)
    client.shipRequestRollError(body, rollError)
end
