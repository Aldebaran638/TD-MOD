---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.sSlotMovementUpdate(dt)
    local active = (server.sSlotState or {}).activeMissiles or {}
    for i = 1, #active do
        local missile = active[i]
        local bodyId = missile and missile.bodyId or 0
        if bodyId ~= 0 and IsHandleValid(bodyId) and missile.desiredRot ~= nil then
            missile.lifeRemain = (missile.lifeRemain or 0.0) - (dt or 0.0)
            local currentRot = GetBodyTransform(bodyId).rot
            local bodyT = GetBodyTransform(bodyId)
            local currentPos = bodyT.pos
            local currentVel = GetBodyVelocity(bodyId)
            local currentSpeed = VecLength(currentVel)
            local fallbackDir = server.sSlotNormalize(TransformToParentVec(bodyT, Vec(0, 0, -1)), Vec(0, 0, -1))
            local currentDir = server.sSlotNormalize(currentVel, fallbackDir)
            local desiredDir = currentDir

            local targetBodyId = missile.targetBodyId or 0
            local targetVehicleId = missile.targetVehicleId or 0
            local targetPos = nil
            local targetVel = nil

            if targetBodyId ~= 0 and IsHandleValid(targetBodyId) and server.registryShipExists(targetBodyId) and (not server.registryShipIsBodyDead(targetBodyId)) then
                targetPos = server.sSlotGetBodyCenterWorld(targetBodyId)
                if targetPos ~= nil then
                    targetVel = GetBodyVelocity(targetBodyId)
                end
            elseif targetVehicleId ~= 0 then
                local targetBody = GetVehicleBody(targetVehicleId)
                if targetBody ~= nil and targetBody ~= 0 and IsHandleValid(targetBody) then
                    targetPos = server.sSlotGetBodyCenterWorld(targetBody)
                    if targetPos ~= nil then
                        targetVel = GetBodyVelocity(targetBody)
                    end
                else
                    local vehicleT = GetVehicleTransform(targetVehicleId)
                    if vehicleT ~= nil then
                        targetPos = vehicleT.pos
                        targetVel = GetVehicleVelocity(targetVehicleId)
                    end
                end
            end

            if targetPos ~= nil and targetVel ~= nil then
                local dist = VecLength(VecSub(targetPos, currentPos))
                local leadTime = math.min(1.0, dist / math.max(1.0, currentSpeed, missile.cruiseSpeed or 1.0))
                local leadPos = VecAdd(targetPos, VecScale(targetVel, leadTime))
                desiredDir = server.sSlotNormalize(VecSub(leadPos, currentPos), currentDir)
            end

            local steerAlpha = math.min(1.0, math.max(0.0, (missile.turnBlendRate or 0.0) * (dt or 0.0)))
            local blendedDir = server.sSlotNormalize(VecLerp(currentDir, desiredDir, steerAlpha), desiredDir)
            local targetSpeed = math.max(currentSpeed, missile.cruiseSpeed or 0.0)
            targetSpeed = math.min(missile.maxSpeed or targetSpeed, targetSpeed + (missile.acceleration or 0.0) * (dt or 0.0))
            local desiredVel = VecScale(blendedDir, targetSpeed)
            local probes = server.sSlotGetProbePoints(bodyT)

            missile.prePhysicsCenterPos = Vec(probes.center[1], probes.center[2], probes.center[3])
            missile.prePhysicsHeadPos = Vec(probes.head[1], probes.head[2], probes.head[3])
            missile.prePhysicsMidPos = Vec(probes.mid[1], probes.mid[2], probes.mid[3])
            missile.desiredRot = QuatLookAt(currentPos, VecAdd(currentPos, blendedDir))

            SetBodyActive(bodyId, true)
            SetBodyVelocity(bodyId, desiredVel)
            ConstrainOrientation(
                bodyId,
                0,
                currentRot,
                missile.desiredRot,
                missile.turnRate or 0.0,
                missile.turnImpulse or 0.0
            )
        end
    end
end
