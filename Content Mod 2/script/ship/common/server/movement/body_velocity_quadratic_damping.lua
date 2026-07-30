---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.bodyVelocityQuadraticDampingTick(dt)
    dt = dt or 0
    if dt <= 0 then
        return
    end

    local body = server.shipContextGetBody()
    if body == nil or body == 0 then
        return
    end

    local velocity = GetBodyVelocity(body)
    if velocity == nil then
        return
    end

    local cfg = server.shipContextGetDefinition().flightProfile or {}
    local dampingRho = tonumber(cfg.quadraticDamping) or 0.1
    local minSpeed = tonumber(cfg.dampingMinSpeed) or 0.01

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
