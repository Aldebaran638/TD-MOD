---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

function server.hSlotV2Rotate(baseDirection, axis, angleDegrees, fallback)
    local normalizedAxis = server.hSlotV2Normalize(axis, fallback or Vec(0, 1, 0))
    local radians = math.rad(angleDegrees or 0.0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    return server.hSlotV2Normalize(
        VecAdd(
            VecScale(baseDirection, cosine),
            VecAdd(
                VecScale(VecCross(normalizedAxis, baseDirection), sine),
                VecScale(
                    normalizedAxis,
                    VecDot(normalizedAxis, baseDirection) * (1.0 - cosine)
                )
            )
        ),
        fallback or baseDirection
    )
end

function server.hSlotV2Probe(shipBody, craftBody, origin, direction, distance, radius)
    QueryRequire("physical")
    QueryRejectBody(shipBody)
    QueryRejectBody(craftBody)
    local hit, hitDistance, hitNormal = QueryRaycast(
        origin,
        server.hSlotV2Normalize(direction, Vec(0, 0, -1)),
        math.max(0.1, tonumber(distance) or 0.1),
        math.max(0.0, tonumber(radius) or 0.0)
    )
    return not hit, tonumber(hitDistance) or distance, hitNormal
end

function server.hSlotV2ResolveAvoidance(shipBody, craft, desiredDirection, config)
    local forward = server.hSlotV2Normalize(desiredDirection, craft.forward)
    local worldUp = Vec(0, 1, 0)
    local right = server.hSlotV2Normalize(VecCross(forward, worldUp), Vec(1, 0, 0))
    local nearDistance = math.max(4.0, tonumber(config.avoidProbeDistance) or 18.0)
    local farDistance = math.max(
        nearDistance,
        tonumber(config.avoidProbeDistanceFar) or nearDistance * 1.6
    )
    local radius = math.max(0.2, tonumber(config.avoidProbeRadius) or 0.8)

    local directClear, directDistance, directNormal = server.hSlotV2Probe(
        shipBody, craft.bodyId, craft.pos, forward, farDistance, radius
    )
    if directClear then
        return forward, false, directDistance, directNormal, 1
    end

    local candidates = {
        server.hSlotV2Rotate(forward, worldUp, 42.0, forward),
        server.hSlotV2Rotate(forward, worldUp, -42.0, forward),
        server.hSlotV2Rotate(forward, right, -38.0, forward),
        server.hSlotV2Rotate(forward, right, 38.0, forward),
        server.hSlotV2Rotate(forward, worldUp, 72.0, forward),
        server.hSlotV2Rotate(forward, worldUp, -72.0, forward),
    }

    local currentForward = server.hSlotV2Normalize(craft.forward, forward)
    local bestDirection = nil
    local bestDistance = 0.0
    local bestScore = -1000000.0
    for i = 1, #candidates do
        local candidate = candidates[i]
        local clear, clearance = server.hSlotV2Probe(
            shipBody, craft.bodyId, craft.pos, candidate, farDistance, radius
        )
        local score = math.min(1.0, clearance / farDistance) * 4.0
            + VecDot(candidate, forward) * 1.4
            + VecDot(candidate, currentForward) * 0.8
            + (clear and 2.0 or 0.0)
        if score > bestScore then
            bestScore = score
            bestDirection = candidate
            bestDistance = clearance
        end
    end

    if bestDirection ~= nil
        and bestDistance >= math.max(3.0, nearDistance * 0.30) then
        return bestDirection, true, bestDistance, directNormal, 1 + #candidates
    end

    local obstacleNormal = directNormal
    if obstacleNormal == nil or VecLength(obstacleNormal) < 0.0001 then
        obstacleNormal = VecScale(forward, -1.0)
    end
    local escape = server.hSlotV2Normalize(
        VecAdd(VecScale(obstacleNormal, 1.2), Vec(0, 0.55, 0)),
        obstacleNormal
    )
    return escape, true, directDistance, obstacleNormal, 1 + #candidates
end

function server.hSlotV2GetIntegrity(craft, config)
    local shieldHP, armorHP, bodyHP = server.registryShipGetHP(craft.bodyId)
    if shieldHP == nil or armorHP == nil or bodyHP == nil then return 1.0 end
    local definition = (shipTypeRegistryData or {})[
        tostring(config.craftShipType or "gammaStrikeCraft")
    ] or {}
    local maximum = math.max(
        1.0,
        (tonumber(definition.maxShieldHP) or 0.0)
            + (tonumber(definition.maxArmorHP) or 0.0)
            + (tonumber(definition.maxBodyHP) or 0.0)
    )
    return server.hSlotV2Clamp(
        (shieldHP + armorHP + bodyHP) / maximum, 0.0, 1.0
    )
end

function server.hSlotV2UpdateDamageState(shipBody, state, slotIndex, craft, config, dt)
    craft.healthCheckRemain = (craft.healthCheckRemain or 0.0) - (dt or 0.0)
    if craft.healthCheckRemain > 0.0 then return true end
    craft.healthCheckRemain = math.max(
        0.03, tonumber(config.healthCheckInterval) or 0.1
    )

    if server.registryShipIsBodyDead ~= nil
        and server.registryShipIsBodyDead(craft.bodyId) then
        server.hSlotV2SetDebugReason(slotIndex, "craft_registry_hp_zero", craft)
        server.hSlotV2CraftExplode(shipBody, craft, config)
        server.hSlotV2FinishCraft(state, slotIndex)
        return false
    end

    craft.integrity = server.hSlotV2GetIntegrity(craft, config)
    local disabledThreshold = server.hSlotV2Clamp(
        tonumber(config.disabledThreshold) or 0.24, 0.01, 0.95
    )
    local damagedThreshold = server.hSlotV2Clamp(
        tonumber(config.damagedThreshold) or 0.60,
        disabledThreshold,
        1.0
    )
    if craft.integrity <= disabledThreshold then
        if craft.state ~= "disabled" then
            craft.state = "disabled"
            craft.fireRemain = math.huge
            server.hSlotV2SetDebugReason(slotIndex, "craft_disabled_drift", craft)
        end
    elseif craft.integrity <= damagedThreshold then
        craft.damaged = true
        if craft.state ~= "returning" and craft.state ~= "docking" then
            craft.state = "returning"
            craft.returnRemain = math.max(
                tonumber(craft.returnRemain) or 0.0,
                math.max(0.5, tonumber(config.returnTimeout) or 6.0)
            )
            server.hSlotV2SetDebugReason(slotIndex, "craft_damaged_return", craft)
        end
    else
        craft.damaged = false
    end
    return true
end

function server.hSlotV2ResolveMission(shipBody, craft, targetCenter, config, dt)
    local desiredDirection = craft.forward or Vec(0, 0, -1)
    local targetDistance = targetCenter ~= nil
        and VecLength(VecSub(targetCenter, craft.pos))
        or math.huge

    if craft.state == "returning" or craft.state == "docking" then
        local approachPoint, dockingPoint = server.hSlotV2ResolveRecoveryPoints(
            shipBody, config
        )
        if craft.state == "returning" then
            local toApproach = VecSub(approachPoint, craft.pos)
            if VecLength(toApproach) <= math.max(
                2.0, tonumber(config.recoveryApproachRadius) or 7.0
            ) then
                craft.state = "docking"
                server.hSlotV2SetDebugReason(
                    craft.slotIndex or 0, "return_approach_complete", craft
                )
            else
                return server.hSlotV2Normalize(toApproach, desiredDirection), false
            end
        end

        local toDock = VecSub(dockingPoint, craft.pos)
        if VecLength(toDock) <= math.max(
            1.0, tonumber(config.recoverRadius) or 3.2
        ) then
            return nil, true
        end
        return server.hSlotV2Normalize(toDock, desiredDirection), false
    end

    if craft.state == "disengage" then
        craft.disengageRemain = (craft.disengageRemain or 0.0) - (dt or 0.0)
        local away = targetCenter ~= nil
            and server.hSlotV2Normalize(
                VecSub(craft.pos, targetCenter), craft.forward or desiredDirection
            )
            or (craft.forward or desiredDirection)
        desiredDirection = server.hSlotV2Normalize(
            VecAdd(
                VecScale(craft.forward or away, 0.7),
                VecAdd(
                    VecScale(away, 0.8),
                    Vec(0, tonumber(config.disengageClimb) or 0.25, 0)
                )
            ),
            away
        )
        if craft.disengageRemain <= 0.0
            or targetDistance >= math.max(
                25.0, tonumber(config.disengageDistance) or 55.0
            ) then
            craft.state = "approach"
            craft.attackRunRemain = 0.0
        end
        return desiredDirection, false
    end

    if targetCenter == nil then
        craft.state = "returning"
        return server.hSlotV2ResolveMission(
            shipBody, craft, targetCenter, config, dt
        )
    end

    if craft.state == "approach" then
        if targetDistance <= math.max(
            30.0, tonumber(config.attackRunStartDistance) or 80.0
        ) then
            craft.state = "attack_run"
            craft.attackRunRemain = math.max(
                0.3, tonumber(config.attackRunDuration) or 2.2
            )
        end
        return server.hSlotV2Normalize(
            VecSub(targetCenter, craft.pos), desiredDirection
        ), false
    end

    if craft.state == "attack_run" then
        craft.attackRunRemain = (craft.attackRunRemain or 0.0) - (dt or 0.0)
        local targetRadius = server.hSlotV2ResolveTargetShieldRadius(
            craft.targetBodyId or 0,
            server.defaultShipType or "enigmaticCruiser"
        )
        local breakDistance = math.max(
            tonumber(config.attackRunBreakDistance) or 18.0,
            targetRadius + math.max(
                5.0, (tonumber(config.collisionProbeRadius) or 0.9) * 4.0
            )
        )
        if targetDistance <= breakDistance or craft.attackRunRemain <= 0.0 then
            craft.state = "disengage"
            craft.disengageRemain = math.max(
                0.25, tonumber(config.disengageDuration) or 1.1
            )
            return server.hSlotV2ResolveMission(
                shipBody, craft, targetCenter, config, dt
            )
        end
        return server.hSlotV2Normalize(
            VecSub(targetCenter, craft.pos), desiredDirection
        ), false
    end

    craft.state = "approach"
    return server.hSlotV2Normalize(
        VecSub(targetCenter, craft.pos), desiredDirection
    ), false
end

function server.hSlotV2ResolveSpeed(craft, desiredDirection, config)
    local speed = math.max(4.0, tonumber(config.craftSpeed) or 30.0)
    if craft.damaged then
        speed = speed * server.hSlotV2Clamp(
            tonumber(config.damagedSpeedFactor) or 0.68, 0.15, 1.0
        )
    end
    if craft.state == "docking" then
        speed = speed * server.hSlotV2Clamp(
            tonumber(config.dockingSpeedFactor) or 0.28, 0.08, 0.6
        )
    end
    if craft.avoidBlocked then
        speed = speed * server.hSlotV2Clamp(
            tonumber(config.blockedSpeedFactor) or 0.22, 0.05, 0.5
        )
    end
    local alignment = server.hSlotV2Clamp(
        VecDot(server.hSlotV2Normalize(craft.forward, desiredDirection), desiredDirection),
        -1.0,
        1.0
    )
    return math.max(3.0, speed * (0.35 + 0.65 * math.max(0.0, alignment)))
end

function server.hSlotV2Sweep(shipBody, craft, nextPosition, config)
    local step = VecSub(nextPosition, craft.pos)
    local stepLength = VecLength(step)
    if stepLength <= 0.0001 then return false end
    local sweepDirection = VecScale(step, 1.0 / stepLength)

    QueryRequire("physical")
    QueryRejectBody(shipBody)
    QueryRejectBody(craft.bodyId)
    local hit, hitDistance, hitNormal, hitShape = QueryRaycast(
        craft.pos,
        sweepDirection,
        stepLength,
        math.max(0.2, tonumber(config.collisionProbeRadius) or 0.9)
    )
    if not hit then return false end

    local hitBody = hitShape ~= nil and hitShape ~= 0
        and GetShapeBody(hitShape)
        or 0
    if hitBody ~= 0 and hitBody == math.floor(craft.targetBodyId or 0) then
        local targetCenter = server.hSlotV2GetBodyCenter(hitBody)
        local contactRadius = server.hSlotV2ResolveTargetShieldRadius(
            hitBody, server.defaultShipType or "enigmaticCruiser"
        ) + 1.0
        if targetCenter ~= nil
            and VecLength(VecSub(craft.pos, targetCenter)) > math.max(
                2.0, contactRadius
            ) then
            return false
        end
    end

    server.hSlotV2SetCollisionDebug(hitBody, hitDistance)
    local normal = hitNormal
    if normal == nil or VecLength(normal) < 0.0001 then
        normal = VecScale(sweepDirection, -1.0)
    end
    normal = server.hSlotV2Normalize(normal, Vec(0, 1, 0))
    local emergencyDirection = server.hSlotV2Normalize(
        VecAdd(
            VecScale(sweepDirection, 0.15),
            VecAdd(VecScale(normal, 1.4), Vec(0, 0.65, 0))
        ),
        normal
    )

    craft.avoidDir = emergencyDirection
    craft.avoidRemain = math.max(
        0.20, tonumber(config.avoidHoldDuration) or 0.42
    )
    craft.avoidBlocked = true
    craft.forward = emergencyDirection
    craft.pos = VecAdd(craft.pos, VecScale(normal, 1.15))
    local transform = GetBodyTransform(craft.bodyId)
    transform.pos = craft.pos
    SetBodyTransform(craft.bodyId, transform)
    SetBodyVelocity(
        craft.bodyId,
        VecScale(
            emergencyDirection,
            math.max(3.0, (tonumber(config.craftSpeed) or 30.0) * 0.25)
        )
    )
    return true
end
