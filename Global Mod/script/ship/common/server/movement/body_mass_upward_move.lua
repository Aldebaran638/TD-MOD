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

-- 移动类模块：始终给指定 body 施加竖直向上的力，力大小 = body 质量
-- 在 Teardown 中使用冲量实现：impulse = force * dt
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

            -- 悬浮抵消重力：F = m * g（Teardown 近似 g=10）
            local flight = server.shipContextGetDefinition().flightProfile or {}
            local upwardForce = Vec(
                0,
                mass * (tonumber(flight.gravityCompensation) or 10.0),
                0
            )
            local impulse = VecScale(upwardForce, dt)
            ApplyBodyImpulse(body, comWorld, impulse)
        end
    end
end
