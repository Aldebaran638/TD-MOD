---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.bodyVelocityQuadraticDampingConfig = server.bodyVelocityQuadraticDampingConfig or {
    quadraticRho = 5000,  -- 二次阻尼系数：阻尼力 = rho * speed^2
    minSpeed = 0.01,     -- 低于该速度时不施加阻尼
}

function server.bodyVelocityQuadraticDampingTick(dt)
    dt = dt or 0
    if dt <= 0 then
        return
    end

    local body = server.shipBody
    if body == nil or body == 0 then
        return
    end

    local velocity = GetBodyVelocity(body)
    if velocity == nil then
        return
    end

    local cfg = server.bodyVelocityQuadraticDampingConfig
    local dampingRho = tonumber(cfg.quadraticRho) or 0.1
    local minSpeed = tonumber(cfg.minSpeed) or 0.01

    local speed = VecLength(velocity)
    if speed <= minSpeed then
        return
    end

    local t = GetBodyTransform(body)
    local comLocal = GetBodyCenterOfMass(body)
    local comWorld = TransformToParentPoint(t, comLocal)

    local velocityDir = VecScale(velocity, 1.0 / speed)
    local dampingForceMagnitude = dampingRho * speed * speed
    local dampingForce = VecScale(velocityDir, -dampingForceMagnitude)
    local impulse = VecScale(dampingForce, dt)

    ApplyBodyImpulse(body, comWorld, impulse)
end
