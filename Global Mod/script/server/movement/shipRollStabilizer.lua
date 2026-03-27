---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.shipRollStabilizerConfig = server.shipRollStabilizerConfig or {
    rollDeadzone = 0.3,       -- 死区角度（度）
    rollForceGain = 5000.0,     -- 每度误差对应的力增益
    rollForceMax = 50000.0,     -- 力上限
    rollDamping = 200000.0,       -- 按滚转角速度施加的阻尼系数
    rollRateDeadzone = 0.02,  -- 角速度死区（弧度/秒）
    rollLeverArm = 8.0,       -- 成对施力点在本地 Y 轴上的力臂长度
    rollSign = 1.0,           -- 方向翻转（反向时改为 -1）
}

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
    local body = server.shipBody
    if body == nil or body == 0 then
        return
    end
    if server.registryShipExists ~= nil and (not server.registryShipExists(body)) then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        return
    end

    local cfg = server.shipRollStabilizerConfig
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
    local rateDeadzone = _safeNumber(cfg.rollRateDeadzone, 0.0)
    if rollRate < rateDeadzone and rollRate > -rateDeadzone then
        rollRate = 0.0
    end

    local rollDeadzone = _safeNumber(cfg.rollDeadzone, 0.0)
    local controlError = 0.0
    if rollError >= rollDeadzone or rollError <= -rollDeadzone then
        controlError = rollError
    end

    local controlTerm = _safeNumber(cfg.rollSign, 1.0) * _safeNumber(cfg.rollForceGain, 0.0) * controlError
    local dampingTerm = _safeNumber(cfg.rollDamping, 0.0) * rollRate
    local signedForce = _clampSigned(
        controlTerm - dampingTerm,
        _safeNumber(cfg.rollForceMax, 0.0)
    )

    local signedImpulse = signedForce * frameDt
    local lever = _safeNumber(cfg.rollLeverArm, 8.0)
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
