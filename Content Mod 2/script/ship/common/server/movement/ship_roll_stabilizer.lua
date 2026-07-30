---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local function _safeNumber(v, fallback)
    local n = tonumber(v)
    if n == nil then return fallback or 0.0 end
    if n ~= n then return fallback or 0.0 end
    if n == math.huge or n == -math.huge then return fallback or 0.0 end
    return n
end

local function _clampSigned(v, limit)
    if v > limit then return limit end
    if v < -limit then return -limit end
    return v
end

local function _safeNormalize(v, fallback)
    local len = VecLength(v)
    if len <= 0.000001 then
        return fallback or Vec(1, 0, 0)
    end
    return VecScale(v, 1.0 / len)
end

function server.shipRollStabilizerUpdate(dt)
    local body = server.shipContextGetBody()
    if body == nil or body == 0 then
        return
    end
    if server.registryShipExists ~= nil and (not server.registryShipExists(body)) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        return
    end

    local cfg = ((server.shipContextGetDefinition().flightProfile or {}).roll or {})
    local frameDt = _safeNumber(dt, 0.0)
    if frameDt <= 0 then
        return
    end

    local rollError = 0.0
    if server.shipRuntimeGetRollError ~= nil then
        rollError = _safeNumber(server.shipRuntimeGetRollError(body), 0.0)
    end

    local t = GetBodyTransform(body)
    local forwardWorld = _safeNormalize(TransformToParentVec(t, Vec(0, 0, -1)), Vec(0, 0, -1))
    local rightWorld = _safeNormalize(TransformToParentVec(t, Vec(1, 0, 0)), Vec(1, 0, 0))

    local angularVel = GetBodyAngularVelocity(body)
    local rollRate = VecDot(angularVel, forwardWorld)
    local rateDeadzone = _safeNumber(cfg.rateDeadzone, 0.0)
    if rollRate < rateDeadzone and rollRate > -rateDeadzone then
        rollRate = 0.0
    end

    local rollDeadzone = _safeNumber(cfg.deadzone, 0.0)
    local controlError = 0.0
    if rollError >= rollDeadzone or rollError <= -rollDeadzone then
        controlError = rollError
    end

    local controlTerm = _safeNumber(cfg.sign, 1.0)
        * _safeNumber(cfg.forceGain, 0.0) * controlError
    local dampingTerm = _safeNumber(cfg.damping, 0.0) * rollRate
    local signedForce = _clampSigned(
        controlTerm - dampingTerm,
        _safeNumber(cfg.forceMax, 0.0)
    )

    local signedImpulse = signedForce * frameDt
    local lever = _safeNumber(cfg.leverArm, 8.0)
    if lever < 0 then
        lever = -lever
    end

    local topPos = TransformToParentPoint(t, Vec(0, lever, 0))
    local bottomPos = TransformToParentPoint(t, Vec(0, -lever, 0))
    local topImpulse = VecScale(rightWorld, signedImpulse)
    local bottomImpulse = VecScale(rightWorld, -signedImpulse)

    if signedImpulse >= 0.000001 or signedImpulse <= -0.000001 then
        ApplyBodyImpulse(body, topPos, topImpulse)
        ApplyBodyImpulse(body, bottomPos, bottomImpulse)
    end

end
