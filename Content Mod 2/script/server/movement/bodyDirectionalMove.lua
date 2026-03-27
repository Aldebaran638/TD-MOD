---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

server.bodyDirectionalMoveConfig = server.bodyDirectionalMoveConfig or {
    forwardAcceleration = 50.0,   -- W 前进加速度
    backwardAcceleration = 50.0,  -- S 后退加速度
}

function server.bodyDirectionalMoveTick(dt)
    dt = dt or 0
    if dt <= 0 then
        return
    end

    local body = server.shipBody
    if body == nil or body == 0 then
        return
    end

    server.registryShipEnsure(body, server.defaultShipType, server.defaultShipType)
    local moveState = server.shipRuntimeGetMoveState(body)
    if moveState ~= 0 then
        local cfg = server.bodyDirectionalMoveConfig
        local forwardAcceleration = tonumber(cfg.forwardAcceleration) or 10.0
        local backwardAcceleration = tonumber(cfg.backwardAcceleration) or 10.0
        local mass = GetBodyMass(body)
        if mass ~= nil and mass > 0 then
            local t = GetBodyTransform(body)
            local comLocal = GetBodyCenterOfMass(body)
            local comWorld = TransformToParentPoint(t, comLocal)

            local totalForce = Vec(0, 0, 0)
            if moveState == 1 then
                -- W：向前（0,0,1）
                local forward = TransformToParentVec(t, Vec(0, 0, -1))
                totalForce = VecAdd(totalForce, VecScale(forward, mass * forwardAcceleration))
            elseif moveState == 2 then
                -- S：向后（0,0,-1）
                local backward = TransformToParentVec(t, Vec(0, 0, 1))
                totalForce = VecAdd(totalForce, VecScale(backward, mass * backwardAcceleration))
            end

            local impulse = VecScale(totalForce, dt)
            ApplyBodyImpulse(body, comWorld, impulse)
        end
    end
end
