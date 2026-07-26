---@diagnostic disable: undefined-global
---@diagnostic disable: duplicate-set-field

server = server or {}

local FlightCandidates = {
    { yaw = -28.0, pitch = 0.0 },
    { yaw = 28.0, pitch = 0.0 },
    { yaw = 0.0, pitch = 24.0 },
    { yaw = -42.0, pitch = 24.0 },
    { yaw = 42.0, pitch = 24.0 },
}

local function _flightClamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function _flightNormalize(value, fallback)
    local length = VecLength(value)
    if length < 0.0001 then return fallback or Vec(0, 0, -1) end
    return VecScale(value, 1.0 / length)
end

local function _flightCopy(value)
    return Vec(value[1] or 0.0, value[2] or 0.0, value[3] or 0.0)
end

local function _flightLimit(value, maximumLength)
    local length = VecLength(value)
    if length <= maximumLength or length < 0.0001 then return value end
    return VecScale(value, maximumLength / length)
end

local function _flightBasis(direction)
    local forward = _flightNormalize(direction, Vec(0, 0, -1))
    local right = _flightNormalize(VecCross(forward, Vec(0, 1, 0)), Vec(1, 0, 0))
    local up = _flightNormalize(VecCross(right, forward), Vec(0, 1, 0))
    return forward, right, up
end

local function _flightRotateAroundUp(direction, degrees)
    local radians = math.rad(degrees)
    local cosine, sine = math.cos(radians), math.sin(radians)
    return _flightNormalize(Vec(
        direction[1] * cosine - direction[3] * sine,
        direction[2],
        direction[1] * sine + direction[3] * cosine
    ), direction)
end

local function _flightCandidate(baseDirection, offset)
    local forward, right, up = _flightBasis(baseDirection)
    return _flightNormalize(VecAdd(
        forward,
        VecAdd(
            VecScale(right, math.tan(math.rad(offset.yaw or 0.0))),
            VecScale(up, math.tan(math.rad(offset.pitch or 0.0)))
        )
    ), forward)
end

local function _flightConfig(config, key, fallback)
    return tonumber((config or {})[key]) or fallback
end

local function _flightSetState(craft, nextState, resumeState)
    if craft.state == nextState then return end
    craft.state = nextState
    craft.stateTime = 0.0
    if resumeState ~= nil then craft.resumeState = resumeState end
end

local function _flightPredictTarget(craft, targetCenter, targetBody, config)
    if targetCenter == nil then return nil end
    local targetVelocity = Vec()
    if targetBody ~= nil and targetBody ~= 0 and IsHandleValid(targetBody) then
        targetVelocity = GetBodyVelocity(targetBody)
    end
    local distance = VecLength(VecSub(targetCenter, craft.pos))
    local speed = math.max(1.0, _flightConfig(config, "cruiseSpeed", 82.0))
    local leadTime = _flightClamp(distance / speed, 0.0, 1.5)
    return VecAdd(targetCenter, VecScale(targetVelocity, leadTime))
end

local function _flightChooseAttackDirection(craft, targetPosition, rotateExisting)
    if rotateExisting then
        craft.attackDirection = _flightRotateAroundUp(
            craft.attackDirection,
            craft.sideBias * 45.0
        )
    else
        craft.attackDirection = _flightNormalize(
            VecSub(targetPosition, craft.pos),
            craft.forward
        )
    end
    craft.entryReached = false
end

local function _flightQuery(craft, ownerBody, origin, direction, distance, radius, farQuery)
    QueryRequire(farQuery and "physical large" or "physical")
    QueryRejectBody(craft.bodyId)
    if ownerBody ~= nil and ownerBody ~= 0 then QueryRejectBody(ownerBody) end
    if server.netDebugCountRaycast ~= nil then server.netDebugCountRaycast(1) end
    return QueryRaycast(origin, direction, distance, radius)
end

local function _flightEnterEmergency(craft, normal)
    craft.emergencyNormal = _flightNormalize(normal, Vec(0, 1, 0))
    craft.avoidDirection = nil
    craft.avoidRemain = 0.0
    _flightSetState(craft, "EMERGENCY", craft.state)
end

local function _flightMissionUpdate(craft, predictedTarget, recoveryPoint, returnGate, config)
    if craft.state ~= "RETURN" and craft.state ~= "DOCK"
        and craft.missionTime >= _flightConfig(config, "attackDuration", 10.0) then
        _flightSetState(craft, "RETURN")
    end

    if predictedTarget == nil
        and craft.state ~= "LAUNCH"
        and craft.state ~= "RETURN"
        and craft.state ~= "DOCK"
        and craft.state ~= "EMERGENCY" then
        _flightSetState(craft, "RETURN")
    end

    if craft.state == "LAUNCH" then
        local launchDistance = VecLength(VecSub(craft.pos, craft.startPosition))
        if (craft.stateTime >= 0.50 and launchDistance >= 10.0)
            or craft.stateTime >= 1.50 then
            if predictedTarget ~= nil then
                _flightChooseAttackDirection(craft, predictedTarget, false)
                _flightSetState(craft, "INTERCEPT")
            else
                _flightSetState(craft, "RETURN")
            end
        end
    elseif craft.state == "INTERCEPT" and predictedTarget ~= nil then
        if not craft.entryReached
            and VecLength(VecSub(craft.missionPoint, craft.pos)) <= 12.0 then
            craft.entryReached = true
        end
        if craft.entryReached
            and VecDot(craft.forward, craft.attackDirection) >= 0.85
            and (craft.obstacleClearance == nil or craft.obstacleClearance > 8.0) then
            craft.attackPoint = VecAdd(
                predictedTarget,
                VecScale(craft.attackDirection, 36.0)
            )
            _flightSetState(craft, "ATTACK_RUN")
        end
    elseif craft.state == "ATTACK_RUN" and predictedTarget ~= nil then
        local targetDistance = VecLength(VecSub(predictedTarget, craft.pos))
        local passedPlane =
            VecDot(VecSub(predictedTarget, craft.pos), craft.attackDirection) < -2.0
        if targetDistance <= 20.0
            or passedPlane
            or craft.stateTime >= 2.20
            or (craft.obstacleClearance ~= nil and craft.obstacleClearance < 5.0) then
            local away = _flightNormalize(
                VecSub(craft.pos, predictedTarget),
                craft.forward
            )
            local _, right = _flightBasis(craft.forward)
            craft.breakDirection = _flightNormalize(VecAdd(
                VecScale(craft.forward, 0.6),
                VecAdd(
                    VecScale(away, 0.8),
                    VecAdd(Vec(0, 0.65, 0), VecScale(right, 0.35 * craft.sideBias))
                )
            ), craft.forward)
            _flightSetState(craft, "BREAK_AWAY")
        end
    elseif craft.state == "BREAK_AWAY" and predictedTarget ~= nil then
        if craft.stateTime >= 1.0
            or VecLength(VecSub(craft.pos, predictedTarget)) >= 58.0 then
            _flightSetState(craft, "REPOSITION")
        end
    elseif craft.state == "REPOSITION" and predictedTarget ~= nil then
        if craft.stateTime >= 0.75 then
            _flightChooseAttackDirection(craft, predictedTarget, true)
            _flightSetState(craft, "INTERCEPT")
        end
    elseif craft.state == "RETURN" and returnGate ~= nil then
        if VecLength(VecSub(returnGate, craft.pos)) <= 5.0 then
            _flightSetState(craft, "DOCK")
        end
    elseif craft.state == "DOCK" and recoveryPoint ~= nil then
        if VecLength(VecSub(recoveryPoint, craft.pos))
            <= math.max(1.0, _flightConfig(config, "recoverRadius", 10.0)) then
            return "recovered"
        end
    elseif craft.state == "EMERGENCY"
        and craft.stateTime >= _flightConfig(config, "emergencyDuration", 0.70) then
        local resume = craft.resumeState or "INTERCEPT"
        if resume == "ATTACK_RUN" then resume = "REPOSITION" end
        _flightSetState(craft, resume)
    end
    return "active"
end

local function _flightGuidanceUpdate(
    craft,
    predictedTarget,
    recoveryPoint,
    returnGate,
    carrierUp,
    config
)
    if craft.state == "LAUNCH" then
        craft.missionPoint = VecAdd(
            craft.startPosition,
            VecScale(carrierUp or Vec(0, 1, 0), 24.0)
        )
    elseif craft.state == "INTERCEPT" and predictedTarget ~= nil then
        if craft.entryReached then
            craft.missionPoint = VecAdd(
                predictedTarget,
                VecScale(craft.attackDirection, 36.0)
            )
        else
            local _, right = _flightBasis(craft.attackDirection)
            craft.missionPoint = VecAdd(
                VecSub(predictedTarget, VecScale(craft.attackDirection, 64.0)),
                VecScale(right, craft.sideBias * 4.0)
            )
        end
    elseif craft.state == "ATTACK_RUN" then
        craft.missionPoint = craft.attackPoint
    elseif craft.state == "BREAK_AWAY" then
        craft.missionPoint = VecAdd(craft.pos, VecScale(craft.breakDirection, 50.0))
    elseif craft.state == "REPOSITION" and predictedTarget ~= nil then
        local direction = _flightRotateAroundUp(
            craft.attackDirection,
            craft.sideBias * 45.0
        )
        craft.missionPoint = VecSub(predictedTarget, VecScale(direction, 64.0))
    elseif craft.state == "RETURN" and returnGate ~= nil then
        craft.missionPoint = returnGate
    elseif craft.state == "DOCK" and recoveryPoint ~= nil then
        craft.missionPoint = recoveryPoint
    elseif craft.state == "EMERGENCY" then
        local escape = _flightNormalize(VecAdd(
            VecScale(craft.emergencyNormal, 1.4),
            Vec(0, 0.65, 0)
        ), Vec(0, 1, 0))
        craft.missionPoint = VecAdd(craft.pos, VecScale(escape, 24.0))
    else
        craft.missionPoint = VecAdd(craft.pos, VecScale(craft.forward, 20.0))
    end

    local missionDirection = _flightNormalize(
        VecSub(craft.missionPoint, craft.pos),
        craft.forward
    )
    if craft.avoidDirection ~= nil and craft.avoidRemain > 0.0 then
        local farDistance = _flightConfig(config, "farProbeDistance", 70.0)
        local factor = 1.0 - _flightClamp(
            (craft.obstacleClearance or farDistance) / farDistance,
            0.0,
            1.0
        )
        craft.desiredDirection = _flightNormalize(VecAdd(
            VecScale(missionDirection, 0.72),
            VecScale(craft.avoidDirection, 0.90 + factor * 1.35)
        ), craft.avoidDirection)
    else
        craft.desiredDirection = missionDirection
    end
end

local function _flightNearSweep(craft, ownerBody, config)
    local speed = VecLength(craft.velocity)
    if speed < 0.5 then return end
    local radius = _flightConfig(config, "craftRadius", 1.60)
    local deceleration = _flightConfig(config, "maxDeceleration", 390.0)
    local brakingDistance = speed * speed / (2.0 * deceleration)
    local distance = math.max(
        speed * _flightConfig(config, "nearSweepLookahead", 0.18),
        brakingDistance * 1.15
    ) + radius
    local hit, hitDistance, normal = _flightQuery(
        craft,
        ownerBody,
        craft.pos,
        _flightNormalize(craft.velocity, craft.forward),
        distance,
        radius,
        false
    )
    if hit then
        craft.obstacleClearance = hitDistance
        _flightEnterEmergency(craft, normal)
    end
end

local function _flightFarAvoidance(craft, ownerBody, config)
    if craft.state == "EMERGENCY" or craft.avoidRemain > 0.0 then return end
    local farDistance = _flightConfig(config, "farProbeDistance", 70.0)
    local radius = _flightConfig(config, "craftRadius", 1.60)
    local desired = craft.desiredDirection
    local hit, distance, normal = _flightQuery(
        craft,
        ownerBody,
        craft.pos,
        desired,
        farDistance,
        radius * 0.82,
        true
    )
    craft.obstacleClearance = hit and distance or farDistance
    if not hit then
        craft.avoidDirection = nil
        return
    end
    if craft.plannerRemain > 0.0 then
        craft.avoidDirection = _flightNormalize(
            VecAdd(VecScale(normal, 0.8), Vec(0, 0.35, 0)),
            normal
        )
        craft.avoidRemain = 0.12
        return
    end

    craft.plannerRemain = 0.20
    local bestDirection, bestScore, bestClearance = nil, -math.huge, 0.0
    for index = 1, #FlightCandidates do
        local candidate = _flightCandidate(desired, FlightCandidates[index])
        local candidateHit, candidateDistance = _flightQuery(
            craft,
            ownerBody,
            craft.pos,
            candidate,
            farDistance,
            radius * 0.75,
            true
        )
        local clearance = candidateHit and candidateDistance or farDistance
        local score = (clearance / farDistance) * 4.0
            + VecDot(candidate, desired) * 1.8
            + VecDot(candidate, craft.forward) * 1.2
        if clearance > radius * 2.0 and score > bestScore then
            bestDirection, bestScore, bestClearance =
                candidate, score, clearance
        end
    end
    if bestDirection == nil then
        _flightEnterEmergency(craft, normal)
    else
        craft.avoidDirection = bestDirection
        craft.avoidRemain = 0.34
        craft.obstacleClearance = bestClearance
    end
end

local function _flightBaseSpeed(craft, config)
    if craft.state == "LAUNCH" then
        return _flightConfig(config, "cruiseSpeed", 82.0)
            * _flightConfig(config, "launchSpeedFactor", 0.86)
    end
    if craft.state == "ATTACK_RUN" then
        return _flightConfig(config, "attackSpeed", 102.0)
    end
    if craft.state == "BREAK_AWAY" then
        return _flightConfig(config, "breakSpeed", 88.0)
    end
    if craft.state == "RETURN" then
        return _flightConfig(config, "returnSpeed", 74.0)
    end
    if craft.state == "DOCK" then
        return _flightConfig(config, "dockSpeed", 18.0)
    end
    if craft.state == "EMERGENCY" then
        return _flightConfig(config, "emergencySpeed", 30.0)
    end
    return _flightConfig(config, "cruiseSpeed", 82.0)
end

function server.hSlotFlightCreate(craft, slotIndex, startPosition, forward)
    local phase = ((slotIndex or 1) % 6) / 6.0
    craft.state = "LAUNCH"
    craft.stateTime = 0.0
    craft.missionTime = 0.0
    craft.startPosition = _flightCopy(startPosition)
    craft.missionPoint = _flightCopy(startPosition)
    craft.attackPoint = _flightCopy(startPosition)
    craft.attackDirection = _flightCopy(forward)
    craft.breakDirection = _flightCopy(forward)
    craft.desiredDirection = _flightCopy(forward)
    craft.velocity = VecScale(forward, 20.0)
    craft.sideBias = (slotIndex or 1) % 2 == 0 and -1 or 1
    craft.entryReached = false
    craft.avoidDirection = nil
    craft.avoidRemain = 0.0
    craft.obstacleClearance = nil
    craft.emergencyNormal = Vec(0, 1, 0)
    craft.missionRemain = 0.20 * phase
    craft.guidanceRemain = (1.0 / 15.0) * phase
    craft.nearSweepRemain = (1.0 / 30.0) * phase
    craft.farProbeRemain = (1.0 / 8.0) * phase
    craft.plannerRemain = 0.20 * phase
    return craft
end

function server.hSlotFlightUpdate(
    ownerBody,
    craft,
    config,
    targetCenter,
    recoveryPoint,
    carrierUp,
    dt
)
    if craft.state == "DISABLED" then return "disabled", false end
    local frameDt = _flightClamp(tonumber(dt) or 0.0, 0.0, 0.05)
    local bodyTransform = GetBodyTransform(craft.bodyId)
    craft.pos = bodyTransform.pos
    craft.velocity = GetBodyVelocity(craft.bodyId)
    craft.forward = _flightNormalize(
        craft.velocity,
        TransformToParentVec(bodyTransform, Vec(0, 0, -1))
    )
    craft.stateTime = (craft.stateTime or 0.0) + frameDt
    if craft.state ~= "RETURN" and craft.state ~= "DOCK" then
        craft.missionTime = (craft.missionTime or 0.0) + frameDt
    else
        craft.returnRemain = (craft.returnRemain or 0.0) - frameDt
        if craft.returnRemain <= 0.0 then return "timeout", false end
    end
    craft.attackRemain = math.max(
        0.0,
        _flightConfig(config, "attackDuration", 10.0) - craft.missionTime
    )
    craft.avoidRemain = math.max(0.0, (craft.avoidRemain or 0.0) - frameDt)
    craft.plannerRemain = math.max(0.0, (craft.plannerRemain or 0.0) - frameDt)

    local returnGate = recoveryPoint ~= nil and VecAdd(
        recoveryPoint,
        VecScale(carrierUp or Vec(0, 1, 0), 25.0)
    ) or nil
    local predictedTarget = _flightPredictTarget(
        craft,
        targetCenter,
        craft.targetBodyId,
        config
    )

    craft.missionRemain = (craft.missionRemain or 0.0) - frameDt
    local status = "active"
    if craft.missionRemain <= 0.0 then
        craft.missionRemain = 0.20
        status = _flightMissionUpdate(
            craft,
            predictedTarget,
            recoveryPoint,
            returnGate,
            config
        )
        if status ~= "active" then return status, false end
    end

    craft.guidanceRemain = (craft.guidanceRemain or 0.0) - frameDt
    if craft.guidanceRemain <= 0.0 then
        craft.guidanceRemain = 1.0 / 15.0
        _flightGuidanceUpdate(
            craft,
            predictedTarget,
            recoveryPoint,
            returnGate,
            carrierUp,
            config
        )
    end

    craft.farProbeRemain = (craft.farProbeRemain or 0.0) - frameDt
    if craft.farProbeRemain <= 0.0 then
        craft.farProbeRemain = 1.0 / 8.0
        _flightFarAvoidance(craft, ownerBody, config)
    end
    craft.nearSweepRemain = (craft.nearSweepRemain or 0.0) - frameDt
    if craft.nearSweepRemain <= 0.0 then
        craft.nearSweepRemain = 1.0 / 30.0
        _flightNearSweep(craft, ownerBody, config)
    end

    local baseSpeed = _flightBaseSpeed(craft, config)
    local alignment = _flightClamp(
        VecDot(craft.forward, craft.desiredDirection),
        -1.0,
        1.0
    )
    local minimumFactor = _flightConfig(config, "minimumControlFactor", 0.64)
    local desiredSpeed = baseSpeed * (
        minimumFactor + (1.0 - minimumFactor) * math.max(0.0, alignment)
    )
    local farDistance = _flightConfig(config, "farProbeDistance", 70.0)
    if craft.obstacleClearance ~= nil
        and craft.obstacleClearance < farDistance then
        local radius = _flightConfig(config, "craftRadius", 1.60)
        local deceleration = _flightConfig(config, "maxDeceleration", 390.0)
        local safeSpeed = math.sqrt(math.max(
            0.0,
            2.0 * deceleration
                * math.max(0.0, craft.obstacleClearance - radius)
        ))
        desiredSpeed = math.min(desiredSpeed, safeSpeed * 0.92)
    end
    if craft.state == "DOCK" and recoveryPoint ~= nil then
        desiredSpeed = math.min(
            desiredSpeed,
            math.max(2.0, VecLength(VecSub(recoveryPoint, craft.pos)) * 1.5)
        )
    end

    local desiredVelocity = VecScale(craft.desiredDirection, desiredSpeed)
    local velocityDelta = VecSub(desiredVelocity, craft.velocity)
    local acceleration = desiredSpeed < VecLength(craft.velocity)
        and _flightConfig(config, "maxDeceleration", 390.0)
        or _flightConfig(config, "maxAcceleration", 310.0)
    local nextVelocity = VecAdd(
        craft.velocity,
        _flightLimit(velocityDelta, acceleration * frameDt)
    )
    SetBodyActive(craft.bodyId, true)
    SetBodyVelocity(craft.bodyId, nextVelocity)
    local lookDirection = _flightNormalize(nextVelocity, craft.desiredDirection)
    ConstrainOrientation(
        craft.bodyId,
        0,
        bodyTransform.rot,
        QuatLookAt(craft.pos, VecAdd(craft.pos, lookDirection)),
        _flightConfig(config, "maxAngularVelocity", 20.0),
        _flightConfig(config, "maxAngularImpulse", 9000.0)
    )
    return "active", craft.state == "ATTACK_RUN"
end
