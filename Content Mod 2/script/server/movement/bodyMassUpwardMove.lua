---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local gravityCompensation = 10.0
local bodyMassUpwardMoveDisableThreshold = 0.6

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

    local body = server.shipBody
    if body == nil or body == 0 then
        return
    end

    local byBody = server.bodyMassUpwardMoveState.byBody
    local state = byBody[body]
    if state == nil then
        state = {
            initialVoxelCount = _getBodyVoxelCount(body),
            disabled = false,
        }
        byBody[body] = state
    end

    local currentVoxelCount = _getBodyVoxelCount(body)
    if state.initialVoxelCount ~= nil and state.initialVoxelCount > 0 and currentVoxelCount ~= nil then
        if currentVoxelCount <= state.initialVoxelCount * bodyMassUpwardMoveDisableThreshold then
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
            local upwardForce = Vec(0, mass * gravityCompensation, 0)
            local impulse = VecScale(upwardForce, dt)
            ApplyBodyImpulse(body, comWorld, impulse)
        end
    end
end
