---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local voxelSampleInterval = 0.5

server.bodyMassUpwardMoveState = server.bodyMassUpwardMoveState or {
    byBody = {},
}

local function _getBodyVoxelCount(body)
    if body == nil or body == 0 then
        return nil
    end

    if GetBodyVoxelCount ~= nil then
        local ok, value = pcall(GetBodyVoxelCount, body)
        if ok and value ~= nil then
            return value
        end
    end

    if GetBodyShapes ~= nil and GetShapeVoxelCount ~= nil then
        local ok, shapes = pcall(GetBodyShapes, body)
        if ok and shapes ~= nil then
            local total = 0
            for i = 1, #shapes do
                local shape = shapes[i]
                if shape ~= nil and shape ~= 0 then
                    local shapeOk, shapeVoxelCount = pcall(GetShapeVoxelCount, shape)
                    if shapeOk and shapeVoxelCount ~= nil then
                        total = total + shapeVoxelCount
                    end
                end
            end
            return total
        end
    end

    return nil
end

-- Compensate the configured fraction of the scene gravity at the center of mass.
function server.bodyMassUpwardMoveTick(dt)
    dt = dt or 0
    if dt <= 0 then
        return
    end

    local body = server.shipContextGetBody()
    if body == nil or body == 0 then
        return
    end
    if server.registryShipIsBodyDead ~= nil and server.registryShipIsBodyDead(body) then
        return
    end

    local byBody = server.bodyMassUpwardMoveState.byBody
    local state = byBody[body]
    if state == nil then
        state = {
            initialVoxelCount = _getBodyVoxelCount(body),
            disabled = false,
            voxelSampleAge = 0.0,
        }
        byBody[body] = state
    end

    state.voxelSampleAge = (state.voxelSampleAge or 0.0) + dt
    if state.voxelSampleAge >= voxelSampleInterval then
        state.voxelSampleAge = 0.0
        local currentVoxelCount = _getBodyVoxelCount(body)
        local flight = server.shipContextGetDefinition().flightProfile or {}
        if state.initialVoxelCount ~= nil
            and state.initialVoxelCount > 0
            and currentVoxelCount ~= nil
            and currentVoxelCount
                <= state.initialVoxelCount
                    * (tonumber(flight.disableLiftVoxelRatio) or 0.6) then
            state.disabled = true
        end
    end

    if not state.disabled then
        local mass = GetBodyMass(body)
        if mass ~= nil and mass > 0 then
            local t = GetBodyTransform(body)
            local comLocal = GetBodyCenterOfMass(body)
            local comWorld = TransformToParentPoint(t, comLocal)

            local flight = server.shipContextGetDefinition().flightProfile or {}
            local configuredCompensation = tonumber(flight.gravityCompensation) or 10.0
            local compensationScale = configuredCompensation / 10.0
            local gravity = GetGravity() or Vec(0, -10, 0)
            if VecLength(gravity) > 0.0001 and compensationScale > 0.0 then
                local compensationForce = VecScale(gravity, -mass * compensationScale)
                ApplyBodyImpulse(body, comWorld, VecScale(compensationForce, dt))
            end
        end
    end
end
