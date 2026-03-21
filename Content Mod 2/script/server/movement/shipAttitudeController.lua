---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local registryShipRoot = "StellarisShips/server/ships/byId/"

server.shipAttitudeControllerState = server.shipAttitudeControllerState or {
    byBody = {},
}

-- Control tuning
server.shipAttitudeControllerConfig = server.shipAttitudeControllerConfig or {
    yawDeadzone = 0.5,         -- deg
    pitchDeadzone = 0.5,       -- deg
    yawSoftZone = 3.0,         -- deg after deadzone, force ramps in smoothly
    pitchSoftZone = 3.0,       -- deg after deadzone, force ramps in smoothly

    yawForceGain = 20000,        -- force-like gain per deg
    pitchForceGain = 20000,      -- force-like gain per deg

    yawForceMax = 12000,         -- force-like cap
    pitchForceMax = 12000,       -- force-like cap

    yawDamping = 360000.0,         -- damping against yaw angular speed
    pitchDamping = 360000.0,       -- damping against pitch angular speed
    yawRateDeadzone = 0.05,    -- rad/s small-rate jitter cutoff
    pitchRateDeadzone = 0.05,  -- rad/s small-rate jitter cutoff

    yawLeverArm = 8.0,         -- local z offset used for yaw pair
    pitchLeverArm = 8.0,       -- local z offset used for pitch pair
}

local function _shipKeyPrefix(shipBodyId)
    return registryShipRoot .. tostring(shipBodyId)
end

local function _safeNumber(v, fallback)
    local n = tonumber(v)
    if n == nil then
        return fallback or 0.0
    end
    if n ~= n then
        return fallback or 0.0
    end
    if n == math.huge or n == -math.huge then
        return fallback or 0.0
    end
    return n
end

local function _clampSigned(v, limit)
    if v > limit then
        return limit
    end
    if v < -limit then
        return -limit
    end
    return v
end

function server.shipAttitudeControllerReadRotationError(shipBodyId)
    if shipBodyId == nil or shipBodyId == 0 then
        return 0.0, 0.0, false
    end

    local prefix = _shipKeyPrefix(shipBodyId)
    if not GetBool(prefix .. "/exists") then
        return 0.0, 0.0, false
    end

    local pitchError = _safeNumber(GetFloat(prefix .. "/pitchError"), 0.0)
    local yawError = _safeNumber(GetFloat(prefix .. "/yawError"), 0.0)
    return pitchError, yawError, true
end

local function _applyAxisControlImpulsePair(
    shipBodyId,
    errorDeg,
    deadzone,
    softZone,
    gain,
    maxForce,
    damping,
    rateDeadzone,
    lever,
    forceDirLocal,
    dampingAxisLocal,
    dt
)
    local frameDt = _safeNumber(dt, 0.0)
    if frameDt <= 0 then
        return 0.0, 0.0, false, Vec(0, 0, 0), Vec(0, 0, 0), Vec(0, 0, 0)
    end

    local leverSafe = _safeNumber(lever, 1.0)
    if leverSafe < 0 then
        leverSafe = -leverSafe
    end

    local gainSafe = _safeNumber(gain, 1.0)
    local maxForceSafe = _safeNumber(maxForce, 1.0)
    local dampingSafe = _safeNumber(damping, 0.0)
    local rateDeadzoneSafe = _safeNumber(rateDeadzone, 0.0)
    local softZoneSafe = _safeNumber(softZone, 0.0)
    if softZoneSafe < 0 then
        softZoneSafe = -softZoneSafe
    end

    local t = GetBodyTransform(shipBodyId)
    local forceDir = forceDirLocal or Vec(1, 0, 0)
    local forceDirWorld = VecNormalize(TransformToParentVec(t, forceDir))
    local dampingAxis = dampingAxisLocal or forceDir
    local dampingAxisWorld = VecNormalize(TransformToParentVec(t, dampingAxis))
    local axisAngularSpeed = 0.0
    if GetBodyAngularVelocity ~= nil then
        local angularVel = GetBodyAngularVelocity(shipBodyId)
        if angularVel ~= nil then
            axisAngularSpeed = VecDot(angularVel, dampingAxisWorld)
        end
    end

    if axisAngularSpeed < rateDeadzoneSafe and axisAngularSpeed > -rateDeadzoneSafe then
        axisAngularSpeed = 0.0
    end

    local errorMag = errorDeg
    if errorMag < 0 then
        errorMag = -errorMag
    end
    local errorSign = 1.0
    if errorDeg < 0 then
        errorSign = -1.0
    end

    local shapedError = 0.0
    if errorMag > deadzone then
        if softZoneSafe > 0 and errorMag < (deadzone + softZoneSafe) then
            local k = (errorMag - deadzone) / softZoneSafe
            k = k * k
            shapedError = errorSign * errorMag * k
        else
            shapedError = errorDeg
        end
    end

    local signedForce = _clampSigned(gainSafe * shapedError - dampingSafe * axisAngularSpeed, maxForceSafe)
    if signedForce < 0.0001 and signedForce > -0.0001 then
        return 0.0, 0.0, false, Vec(0, 0, 0), Vec(0, 0, 0), forceDirWorld
    end
    local signedImpulse = signedForce * frameDt

    local frontPos = TransformToParentPoint(t, Vec(0, 0, leverSafe))
    local rearPos = TransformToParentPoint(t, Vec(0, 0, -leverSafe))

    local frontImpulse = VecScale(forceDirWorld, signedImpulse)
    local rearImpulse = VecScale(forceDirWorld, -signedImpulse)

    ApplyBodyImpulse(shipBodyId, frontPos, frontImpulse)
    ApplyBodyImpulse(shipBodyId, rearPos, rearImpulse)

    return signedForce, signedImpulse, true, frontPos, rearPos, forceDirWorld
end

local function _applyYawControlImpulsePair(shipBodyId, yawError, dt)
    local cfg = server.shipAttitudeControllerConfig
    local yawControlError = -(yawError or 0.0)
    return _applyAxisControlImpulsePair(
        shipBodyId,
        yawControlError,
        _safeNumber(cfg.yawDeadzone, 1.0),
        _safeNumber(cfg.yawSoftZone, 3.0),
        _safeNumber(cfg.yawForceGain, 2.2),
        _safeNumber(cfg.yawForceMax, 1.5),
        _safeNumber(cfg.yawDamping, 0.0),
        _safeNumber(cfg.yawRateDeadzone, 0.05),
        _safeNumber(cfg.yawLeverArm, 8.0),
        Vec(1, 0, 0), -- impulse direction
        Vec(0, 1, 0), -- yaw angular velocity axis
        dt
    )
end

local function _applyPitchControlImpulsePair(shipBodyId, pitchError, dt)
    local cfg = server.shipAttitudeControllerConfig
    -- Positive pitchError => nose up.
    -- Front uses -Y impulse, rear uses +Y via pair rule.
    return _applyAxisControlImpulsePair(
        shipBodyId,
        pitchError,
        _safeNumber(cfg.pitchDeadzone, 1.0),
        _safeNumber(cfg.pitchSoftZone, 3.0),
        _safeNumber(cfg.pitchForceGain, 2.2),
        _safeNumber(cfg.pitchForceMax, 1.5),
        _safeNumber(cfg.pitchDamping, 0.0),
        _safeNumber(cfg.pitchRateDeadzone, 0.05),
        _safeNumber(cfg.pitchLeverArm, 8.0),
        Vec(0, -1, 0), -- impulse direction
        Vec(1, 0, 0),  -- pitch angular velocity axis
        dt
    )
end

function server.shipAttitudeControllerUpdate(dt)
    local shipBodyId = server.shipBody
    if shipBodyId == nil or shipBodyId == 0 then
        return
    end

    local pitchError, yawError, exists = server.shipAttitudeControllerReadRotationError(shipBodyId)

    local byBody = server.shipAttitudeControllerState.byBody
    local state = byBody[shipBodyId]
    if state == nil then
        state = {}
        byBody[shipBodyId] = state
    end

    state.exists = exists
    state.pitchError = pitchError
    state.yawError = yawError
    state.lastReadTime = (GetTime ~= nil) and GetTime() or 0
    state.lastDt = dt or 0

    if not exists then
        return
    end

    local yawForce, yawImpulse, yawApplied =
        _applyYawControlImpulsePair(shipBodyId, yawError, dt)
    local pitchForce, pitchImpulse, pitchApplied =
        _applyPitchControlImpulsePair(shipBodyId, pitchError, dt)

    state.yawForceApplied = yawForce
    state.yawImpulseApplied = yawImpulse
    state.yawForceDidApply = yawApplied

    state.pitchForceApplied = pitchForce
    state.pitchImpulseApplied = pitchImpulse
    state.pitchForceDidApply = pitchApplied

end
