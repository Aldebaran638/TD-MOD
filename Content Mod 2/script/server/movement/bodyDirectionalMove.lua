---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local bodyDirectionalMoveAcceleration = 10.0

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
    local moveState = server.registryShipGetMoveState(body)
    if moveState ~= 0 then
        local mass = GetBodyMass(body)
        if mass ~= nil and mass > 0 then
            local t = GetBodyTransform(body)
            local comLocal = GetBodyCenterOfMass(body)
            local comWorld = TransformToParentPoint(t, comLocal)

            local totalForce = Vec(0, 0, 0)
            if moveState == 1 then
                -- W：向前（0,0,1）
                local forward = TransformToParentVec(t, Vec(0, 0, -1))
                totalForce = VecAdd(totalForce, VecScale(forward, mass * bodyDirectionalMoveAcceleration))
            elseif moveState == 2 then
                -- S：向后（0,0,-1）
                local backward = TransformToParentVec(t, Vec(0, 0, 1))
                totalForce = VecAdd(totalForce, VecScale(backward, mass * bodyDirectionalMoveAcceleration))
            end

            local impulse = VecScale(totalForce, dt)
            ApplyBodyImpulse(body, comWorld, impulse)
        end
    end
end
