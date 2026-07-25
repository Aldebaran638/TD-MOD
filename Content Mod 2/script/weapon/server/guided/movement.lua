---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.guidedProjectileMovementUpdate(dt)
    local active = (server.guidedProjectileRuntimeState or {}).activeProjectiles or {}
    for i = 1, #active do
        local projectile = active[i]
        local bodyId = projectile and projectile.bodyId or 0
        if bodyId ~= 0 and IsHandleValid(bodyId) and projectile.desiredRot ~= nil then
            projectile.lifeRemain = (projectile.lifeRemain or 0.0) - (dt or 0.0)
            local bodyT = GetBodyTransform(bodyId)
            local currentRot = bodyT.rot
            local currentPos = bodyT.pos
            local currentVel = GetBodyVelocity(bodyId)
            local currentSpeed = VecLength(currentVel)
            local fallbackDir = server.guidedProjectileNormalize(TransformToParentVec(bodyT, Vec(0, 0, -1)), Vec(0, 0, -1))
            local currentDir = server.guidedProjectileNormalize(currentVel, fallbackDir)
            local desiredDir = currentDir

            local targetBodyId = projectile.targetBodyId or 0
            local targetVehicleId = projectile.targetVehicleId or 0
            local targetPos = nil
            local targetVel = nil

            if targetBodyId ~= 0 and IsHandleValid(targetBodyId) and server.registryShipExists(targetBodyId) and (not server.registryShipIsBodyDead(targetBodyId)) then
                targetPos = server.guidedProjectileGetBodyCenterWorld(targetBodyId)
                if targetPos ~= nil then
                    targetVel = GetBodyVelocity(targetBodyId)
                end
            elseif targetVehicleId ~= 0 then
                local targetBody = GetVehicleBody(targetVehicleId)
                if targetBody ~= nil and targetBody ~= 0 and IsHandleValid(targetBody) then
                    targetPos = server.guidedProjectileGetBodyCenterWorld(targetBody)
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
                local leadTime = math.min(1.0, dist / math.max(1.0, currentSpeed, projectile.cruiseSpeed or 1.0))
                local leadPos = VecAdd(targetPos, VecScale(targetVel, leadTime))
                desiredDir = server.guidedProjectileNormalize(VecSub(leadPos, currentPos), currentDir)
            end

            local steerAlpha = math.min(1.0, math.max(0.0, (projectile.turnBlendRate or 0.0) * (dt or 0.0)))
            local blendedDir = server.guidedProjectileNormalize(VecLerp(currentDir, desiredDir, steerAlpha), desiredDir)
            local targetSpeed = math.max(currentSpeed, projectile.cruiseSpeed or 0.0)
            targetSpeed = math.min(projectile.maxSpeed or targetSpeed, targetSpeed + (projectile.acceleration or 0.0) * (dt or 0.0))
            local desiredVel = VecScale(blendedDir, targetSpeed)
            local probes = server.guidedProjectileGetProbePoints(bodyT)

            projectile.prePhysicsCenterPos = Vec(probes.center[1], probes.center[2], probes.center[3])
            projectile.prePhysicsHeadPos = Vec(probes.head[1], probes.head[2], probes.head[3])
            projectile.prePhysicsMidPos = Vec(probes.mid[1], probes.mid[2], probes.mid[3])
            projectile.desiredRot = QuatLookAt(currentPos, VecAdd(currentPos, blendedDir))

            SetBodyActive(bodyId, true)
            SetBodyVelocity(bodyId, desiredVel)
            ConstrainOrientation(
                bodyId,
                0,
                currentRot,
                projectile.desiredRot,
                projectile.turnRate or 0.0,
                projectile.turnImpulse or 0.0
            )
        end
    end
end
